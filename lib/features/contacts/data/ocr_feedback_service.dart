import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Client service for the "report bad recognition" feature.
///
/// Responsibilities:
///  - Track the rolling 24-hour "don't ask again" suppression locally
///    (shared_preferences; no backend; offline-safe).
///  - Submit a feedback sample via the `submitOcrFeedback` Cloud Function.
///
/// See docs/ocr_feedback_design.md. Everything here is opt-in and only invoked
/// after the user consents in the UI. When the user consents to include the
/// card photo, the full-resolution image is uploaded to Firebase Storage at
/// `ocr_feedback/{uid}/{id}.jpg` first; the resulting Storage object path is
/// then passed to the callable as [imagePath]. If the upload fails, the
/// feedback is still submitted as text-only (graceful degradation) so a poor
/// network never blocks the report.
class OcrFeedbackService {
  OcrFeedbackService([
    FirebaseFunctions? functions,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  ])  : _functions = functions ??
            FirebaseFunctions.instanceFor(
                app: Firebase.app(), region: 'us-central1'),
        _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  static const _suppressKey = 'ocrFeedbackPromptSuppressedUntilMs';

  /// True if the Back-press prompt is currently suppressed (within the rolling
  /// 24h window the user opted into).
  Future<bool> isPromptSuppressed() async {
    final prefs = await SharedPreferences.getInstance();
    final untilMs = prefs.getInt(_suppressKey);
    if (untilMs == null) return false;
    return DateTime.now().millisecondsSinceEpoch < untilMs;
  }

  /// Suppress the prompt for a rolling 24 hours from now.
  Future<void> suppressPromptFor24h() async {
    final prefs = await SharedPreferences.getInstance();
    final until =
        DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch;
    await prefs.setInt(_suppressKey, until);
  }

  /// Submit a bad-recognition sample. Returns the outcome (refunded / limit /
  /// error) so the UI can show the right message. Never throws for expected
  /// server states (limit reached) — those come back as [FeedbackResult].
  Future<FeedbackResult> submit({
    required String engine,
    String? recognitionId,
    String? appVersion,
    String? ocrPkgVersion,
    String? cardLanguage,
    String? region,
    required List<Map<String, dynamic>> rawOcrLines,
    Map<String, dynamic>? parsedResult,
    Map<String, dynamic>? confidence,
    String? imagePath,
    required bool consentData,
    required bool consentImage,
  }) async {
    // If the user consented to include the photo, upload the full-resolution
    // local image to Storage first and send the resulting Storage object path
    // (not the local device path) to the server. On any upload failure we fall
    // back to a text-only submission so a poor network never blocks the report.
    String? storagePath;
    bool imageConsented = consentImage;
    if (consentImage && imagePath != null) {
      storagePath = await _uploadImage(imagePath, recognitionId);
      if (storagePath == null) {
        imageConsented = false; // degrade to text-only
      }
    }

    // Fill the app version centrally so every submit path records it (the
    // caller usually doesn't pass one). Best-effort: a lookup failure must
    // never block the report, so fall back to whatever the caller gave (null).
    var resolvedAppVersion = appVersion;
    if (resolvedAppVersion == null) {
      try {
        final info = await PackageInfo.fromPlatform();
        resolvedAppVersion = '${info.version}+${info.buildNumber}';
      } catch (e) {
        debugPrint('[OcrFeedback] appVersion lookup failed: $e');
      }
    }

    try {
      final callable = _functions.httpsCallable('submitOcrFeedback');
      final res = await callable.call(<String, dynamic>{
        'engine': engine,
        if (recognitionId != null) 'recognitionId': recognitionId,
        if (resolvedAppVersion != null) 'appVersion': resolvedAppVersion,
        if (ocrPkgVersion != null) 'ocrPkgVersion': ocrPkgVersion,
        if (cardLanguage != null) 'cardLanguage': cardLanguage,
        if (region != null) 'region': region,
        'rawOcrLines': rawOcrLines,
        if (parsedResult != null) 'parsedResult': parsedResult,
        if (confidence != null) 'confidence': confidence,
        'imagePath': storagePath,
        'consentData': consentData,
        'consentImage': imageConsented,
      }).timeout(const Duration(seconds: 20));

      final data = Map<String, dynamic>.from(res.data as Map);
      return FeedbackResult(
        success: data['success'] == true,
        refunded: data['refunded'] == true,
      );
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        return const FeedbackResult(success: false, limitReached: true);
      }
      debugPrint('[OcrFeedback] submit failed: ${e.code} ${e.message}');
      return const FeedbackResult(success: false);
    } catch (e) {
      debugPrint('[OcrFeedback] submit error: $e');
      return const FeedbackResult(success: false);
    }
  }

  /// Upload the full-resolution card image to `ocr_feedback/{uid}/{id}.jpg`.
  ///
  /// Returns the Storage object path on success, or null on any failure
  /// (not signed in, missing file, upload error) so the caller can degrade to
  /// a text-only submission. The path is uid-scoped so the Storage rules can
  /// restrict writes to the owner; images are never client-readable.
  Future<String?> _uploadImage(String localPath, String? recognitionId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return null;

      final file = File(localPath);
      if (!await file.exists()) return null;

      // Use the recognitionId when available (ties the image to its ledger
      // entry); otherwise fall back to a timestamp so uploads never collide.
      final id = (recognitionId != null && recognitionId.isNotEmpty)
          ? recognitionId
          : DateTime.now().millisecondsSinceEpoch.toString();
      final objectPath = 'ocr_feedback/$uid/$id.jpg';

      final ref = _storage.ref(objectPath);
      await ref
          .putFile(file, SettableMetadata(contentType: 'image/jpeg'))
          .timeout(const Duration(seconds: 30));
      return objectPath;
    } catch (e) {
      debugPrint('[OcrFeedback] image upload failed: $e');
      return null;
    }
  }
}

/// Result of a feedback submission for UI messaging.
class FeedbackResult {
  const FeedbackResult({
    required this.success,
    this.refunded = false,
    this.limitReached = false,
  });
  final bool success;
  final bool refunded;
  final bool limitReached;
}
