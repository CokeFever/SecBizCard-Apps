import 'package:secbizcard/features/contacts/data/card_detection_config.dart';

/// Signals captured during a single card recognition, used to predict whether
/// the result is likely poor. All fields are optional/nullable so callers can
/// pass whatever they have — a missing signal simply doesn't contribute.
///
/// See docs/ocr_feedback_design.md ("Predicting a likely-poor result"). This is
/// deliberately a simple rule over already-available signals (no ML). Its only
/// job is to decide whether to OFFER the "report bad recognition" prompt when
/// the user leaves; it never blocks or alters recognition.
class RecognitionSignals {
  const RecognitionSignals({
    this.detectionFallback,
    this.detectionScore,
    this.bestNameScore,
    this.orientationMismatch,
    this.coverageRatio,
    this.hasName,
    this.hasAnyPhone,
  });

  /// Card detection fell back to manual corners (no card found). Strong signal.
  final bool? detectionFallback;

  /// Geometric detection score (0..1) from processCard. Low = shaky geometry.
  final double? detectionScore;

  /// The winning name-candidate's absolute score from the parser. Low = nothing
  /// looked like a real name.
  final double? bestNameScore;

  /// The capture was misoriented: the server derived a non-zero text
  /// orientation (0/90/180/270 from Vision word baselines) and the app had to
  /// rotate it upright. Catches the "high geometry score but wrong orientation"
  /// ambiguous-zone case the detection score alone cannot see. Cloud Vision path
  /// only (own-key/ML Kit report 0); null/false when not applicable.
  final bool? orientationMismatch;

  /// Fraction of the camera frame the detected card occupied (0..1) from
  /// processCard. A small value means the card was found but tiny in frame —
  /// often poor edge detection or the user too far away. Null when unknown.
  final double? coverageRatio;

  /// Parsed result completeness: a name was extracted.
  final bool? hasName;

  /// Parsed result completeness: at least one phone/mobile/fax was extracted.
  final bool? hasAnyPhone;
}

/// Pure predictor: is this recognition likely poor enough to offer a report?
/// Thresholds come from Remote Config ([CardDetectionConfig]) so they can be
/// tuned without a release. Returns true if ANY signal fires.
bool predictLikelyPoorRecognition(
  RecognitionSignals s, [
  CardDetectionConfig? config,
]) {
  final cfg = config ?? CardDetectionConfig.current;

  // 1. No card detected at all.
  if (s.detectionFallback == true) return true;

  // 2. Detection accepted but geometry is shaky (score just above the accept
  //    threshold). Only meaningful when we actually have a score.
  final detScore = s.detectionScore;
  if (detScore != null && detScore < cfg.value('poorDetectionScoreBelow')) {
    return true;
  }

  // 3. Orientation contradicts the user's guide — the ambiguous-zone signal.
  if (s.orientationMismatch == true) return true;

  // 3b. Card found but occupies too little of the frame (poor edge detection /
  //     user too far). Only meaningful when we have a positive ratio; 0 means
  //     no card was detected (already covered by the fallback signal).
  final coverage = s.coverageRatio;
  if (coverage != null && coverage > 0 &&
      coverage < cfg.value('poorCoverageBelow')) {
    return true;
  }

  // 4. Nothing looked like a real name.
  final nameScore = s.bestNameScore;
  if (nameScore != null && nameScore < cfg.value('poorNameScoreBelow')) {
    return true;
  }

  // 5. Result is incomplete: no name, or no contact number at all. A normal
  //    card yields at least a name plus one way to reach the person.
  if (s.hasName == false) return true;
  if (s.hasAnyPhone == false && s.hasName == false) return true;

  return false;
}
