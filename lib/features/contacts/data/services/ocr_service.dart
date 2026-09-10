import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';
import 'package:secbizcard/features/settings/data/ocr_settings_service.dart';
import 'package:secbizcard/features/contacts/data/services/cloud_vision_recognizer.dart';
import 'package:SecBizCard_OCR/secbizcard_ocr.dart';

/// Which engine produced a recognition result (for UI messaging).
enum OcrEngineUsed { ownKeyVision, sharedVision, mlKit }

/// Pre-scan status shown on the camera preview before recognition.
class OcrPreScanStatus {
  OcrPreScanStatus({
    required this.engine,
    this.used,
    this.cap,
    this.whitelisted = false,
  });
  final OcrEngineUsed engine;
  final int? used;
  final int? cap;
  /// True for owner/admin accounts: [used]/[cap] then refer to the shared
  /// KEY's global monthly usage rather than a per-user cap.
  final bool whitelisted;
}

/// Outcome of a business-card recognition, including which engine was used, an
/// optional note (e.g. quota hit → fell back to ML Kit), and monthly usage for
/// the engine that ran (shared: x/cap from server; own key: local count).
class OcrOutcome {
  OcrOutcome({
    required this.profile,
    required this.engine,
    this.note,
    this.usageUsed,
    this.usageCap,
    this.rawOcrLines = const [],
    this.recognitionId,
  });
  final UserProfile? profile;
  final OcrEngineUsed engine;
  final String? note;
  final int? usageUsed;
  final int? usageCap;

  /// Raw recognized lines with geometry ({text, box:{x,y,w,h}}), for the
  /// "report bad recognition" feature — this is what lets us re-run parsing on
  /// a reported sample. Empty when unavailable. Additive; other consumers
  /// ignore it.
  final List<Map<String, dynamic>> rawOcrLines;

  /// Server recognitionId for a shared-key call (enables the feedback refund).
  /// Null for own-key / ML Kit.
  final String? recognitionId;

  /// Engine identifier string for the feedback payload.
  String get engineName {
    switch (engine) {
      case OcrEngineUsed.ownKeyVision:
        return 'cloud_vision_ownkey';
      case OcrEngineUsed.sharedVision:
        return 'cloud_vision_shared';
      case OcrEngineUsed.mlKit:
        return 'mlkit';
    }
  }
}

/// Orchestrates business-card OCR across engines with a strict fallback chain:
///
///   1. User's OWN Cloud Vision key (if set) — highest quality, billed to them.
///   2. SHARED Cloud Vision key via Cloud Function — subject to quota.
///   3. On-device ML Kit — always-available offline safety net.
///
/// ANY failure at the Vision layers (no network, timeout, invalid key, quota
/// exceeded, Vision error, empty result) silently falls through to the next
/// option, ending at ML Kit. The recognized text lines are always parsed by the
/// same shared brain ([SecBizCardOcr.parseLines]).
class OCRService {
  OCRService([OcrSettingsService? settings])
      : _settings = settings ??
            OcrSettingsService(
              const FlutterSecureStorage(
                aOptions: AndroidOptions(),
                iOptions: IOSOptions(
                    accessibility: KeychainAccessibility.first_unlock),
              ),
            );

  final OcrSettingsService _settings;

  static const _uuid = Uuid();
  final _ocr = SecBizCardOcr(); // ML Kit engine + shared parser
  late final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(app: Firebase.app(), region: 'us-central1');
  late final CloudVisionRecognizer _vision = CloudVisionRecognizer(_functions);

  /// Pre-scan status for the camera preview: which engine will be used and,
  /// for the shared key, how much monthly quota remains. Never throws — returns
  /// a best-effort snapshot (offline → shared usage unknown).
  Future<OcrPreScanStatus> preScanStatus() async {
    final hasOwn = await _settings.hasApiKey();
    if (hasOwn) {
      // BYOK: no numbers — recognition goes straight to Google with the user's
      // key, so we don't track usage here (they manage it in Cloud Console).
      return OcrPreScanStatus(engine: OcrEngineUsed.ownKeyVision);
    }
    // Shared: query the (non-billing) usage endpoint.
    try {
      final callable = _functions.httpsCallable('getOcrUsage');
      final res = await callable
          .call()
          .timeout(const Duration(seconds: 8));
      final data = Map<String, dynamic>.from(res.data as Map);
      final whitelisted = data['whitelisted'] == true;
      if (whitelisted) {
        // Admin / owner: show the shared KEY's global monthly usage instead of
        // a personal cap that doesn't apply to them.
        return OcrPreScanStatus(
          engine: OcrEngineUsed.sharedVision,
          whitelisted: true,
          used: (data['globalMonth'] as num?)?.toInt(),
          cap: (data['globalCap'] as num?)?.toInt(),
        );
      }
      return OcrPreScanStatus(
        engine: OcrEngineUsed.sharedVision,
        used: (data['userMonth'] as num?)?.toInt(),
        cap: (data['userCap'] as num?)?.toInt(),
      );
    } catch (_) {
      // Offline or error → we'll still attempt Vision, usage unknown.
      return OcrPreScanStatus(engine: OcrEngineUsed.sharedVision);
    }
  }

  /// Whether the orchestrator will attempt Cloud Vision (own key or shared)
  /// before falling back to on-device ML Kit. Used to show an accurate
  /// "recognizing with…" status. Cloud Vision is always attempted first when
  /// possible; only network/quota failures fall back (reflected afterwards in
  /// the result badge).
  Future<bool> willAttemptCloudVision() async => true;

  /// Recognizes a business card, returning the parsed profile + engine used.
  Future<OcrOutcome> recognize(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final base64Image = base64Encode(bytes);

    // 1. Own key path.
    final ownKey = await _settings.getApiKey();
    if (ownKey != null) {
      try {
        final res = await _vision.recognizeWithOwnKey(base64Image, ownKey);
        return OcrOutcome(
          profile: _parse(res, imagePath),
          engine: OcrEngineUsed.ownKeyVision,
          rawOcrLines: _linesToMaps(res.lines),
          // Own-key path has no shared recognitionId (nothing to refund).
        );
      } on VisionFallbackException catch (e) {
        if (kDebugMode) debugPrint('[OCR] own-key Vision failed (${e.reason}) → next');
        // fall through to shared / ML Kit
      } catch (e) {
        if (kDebugMode) debugPrint('[OCR] own-key Vision unexpected error → next');
      }
    }

    // 2. Shared key path (Cloud Function with quota).
    try {
      final res = await _vision.recognizeWithSharedKey(base64Image);
      return OcrOutcome(
        profile: _parse(res, imagePath),
        engine: OcrEngineUsed.sharedVision,
        note: (res.globalUsage != null && res.globalCap != null &&
                res.globalUsage! >= (res.globalCap! * 0.8))
            ? 'shared_near_limit'
            : null,
        // Show the per-user monthly quota (e.g. 3/5) on the result badge.
        usageUsed: res.userUsage,
        usageCap: res.userCap,
        rawOcrLines: _linesToMaps(res.lines),
        recognitionId: res.recognitionId,
      );
    } on VisionFallbackException catch (e) {
      if (kDebugMode) debugPrint('[OCR] shared Vision → fallback ML Kit (${e.reason})');
    } catch (e) {
      if (kDebugMode) debugPrint('[OCR] shared Vision unexpected error → fallback ML Kit');
    }

    // 3. ML Kit (offline safety net).
    try {
      final result = await _ocr.recognizeBusinessCard(imagePath);
      return OcrOutcome(
        profile: _mapToUserProfile(result, imagePath),
        engine: OcrEngineUsed.mlKit,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[OCR] ML Kit failed: $e');
      return OcrOutcome(profile: null, engine: OcrEngineUsed.mlKit);
    }
  }

  /// Backward-compatible helper returning just the profile (ML-Kit-parsed or
  /// Vision-parsed). Prefer [recognize].
  Future<UserProfile?> recognizeBusinessCard(String imagePath) async {
    final outcome = await recognize(imagePath);
    return outcome.profile;
  }

  UserProfile? _parse(VisionRecognitionResult res, String imagePath) {
    final result = _ocr.parseLines(res.lines);
    return _mapToUserProfile(result, imagePath);
  }

  /// Serializes recognized lines to plain maps ({text, box:{x,y,w,h}}) for the
  /// feedback payload — the raw material to re-run parsing on a reported card.
  static List<Map<String, dynamic>> _linesToMaps(List<OcrLine> lines) {
    return lines
        .map((l) => <String, dynamic>{
              'text': l.text,
              'box': {
                'x': l.box.left,
                'y': l.box.top,
                'w': l.box.width,
                'h': l.box.height,
              },
            })
        .toList();
  }

  UserProfile _mapToUserProfile(OcrResult result, String imagePath) {
    return UserProfile(
      uid: _uuid.v4(),
      email: result.email,
      displayName: result.displayName,
      title: result.title,
      company: result.company,
      phone: result.phone,
      mobile: result.mobile,
      website: result.website,
      address: result.address,
      customFields: result.customFields,
      createdAt: DateTime.now(),
      originalImagePath: imagePath,
      source: 'ocr',
    );
  }

  void dispose() {
    _ocr.dispose();
  }
}
