import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Client service for the "report bad recognition" feature.
///
/// Responsibilities:
///  - Track the rolling 24-hour "don't ask again" suppression locally
///    (shared_preferences; no backend; offline-safe).
///  - Submit a feedback sample via the `submitOcrFeedback` Cloud Function.
///
/// See docs/ocr_feedback_design.md. Everything here is opt-in and only invoked
/// after the user consents in the UI. NOTE: this feature is unreleased; the
/// backend function is not yet deployed. Image upload to Storage is a follow-up
/// (firebase_storage is not yet a dependency) — for now [imagePath] is passed
/// as metadata only and the server stores whatever path it's given, or null.
class OcrFeedbackService {
  OcrFeedbackService([FirebaseFunctions? functions])
      : _functions = functions ??
            FirebaseFunctions.instanceFor(
                app: Firebase.app(), region: 'us-central1');

  final FirebaseFunctions _functions;

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
    try {
      final callable = _functions.httpsCallable('submitOcrFeedback');
      final res = await callable.call(<String, dynamic>{
        'engine': engine,
        if (recognitionId != null) 'recognitionId': recognitionId,
        if (appVersion != null) 'appVersion': appVersion,
        if (ocrPkgVersion != null) 'ocrPkgVersion': ocrPkgVersion,
        if (cardLanguage != null) 'cardLanguage': cardLanguage,
        if (region != null) 'region': region,
        'rawOcrLines': rawOcrLines,
        if (parsedResult != null) 'parsedResult': parsedResult,
        if (confidence != null) 'confidence': confidence,
        'imagePath': imagePath,
        'consentData': consentData,
        'consentImage': consentImage,
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
