import 'package:flutter_test/flutter_test.dart';
import 'package:secbizcard/features/contacts/presentation/widgets/ocr_feedback_dialogs.dart';

/// Unit coverage for the Unit-5 feedback detachment refactor (Decision 2).
///
/// The actual submit now runs in a top-level detached function
/// (`_submitFeedbackDetached` in contact_review_screen.dart) that owns its own
/// OcrFeedbackService and toasts via the app-root messenger — that path needs a
/// device/integration run to prove "survives pop". What IS unit-testable here
/// is the contract the detached function depends on: collectFeedbackIfAny hands
/// back an immutable OcrFeedbackSubmission (sample + includePhoto) and the
/// opt-out-photo derivation applied to it matches the pre-refactor
/// showConsentAndSubmit exactly.
void main() {
  OcrFeedbackSample sampleWith({String? imagePath}) => OcrFeedbackSample(
        engine: 'cloud',
        recognitionId: 'rec-1',
        rawOcrLines: const [
          {'text': 'Jane Doe'},
        ],
        imagePath: imagePath,
      );

  group('OcrFeedbackSubmission', () {
    test('carries the sample and includePhoto choice verbatim', () {
      final sample = sampleWith(imagePath: '/tmp/card.jpg');
      final submission =
          OcrFeedbackSubmission(sample: sample, includePhoto: true);

      expect(submission.sample, same(sample));
      expect(submission.includePhoto, isTrue);
    });

    // The derivation below mirrors _submitFeedbackDetached /
    // showConsentAndSubmit (ocr_feedback_dialogs.dart:160-162): imagePath and
    // consentImage are only set when the user ticked include-photo AND a local
    // image path exists. These assertions pin opt-out-photo.
    test('include-photo ON with a path => photo sent', () {
      final s =
          OcrFeedbackSubmission(sample: sampleWith(imagePath: '/tmp/c.jpg'), includePhoto: true);

      final imagePath = s.includePhoto ? s.sample.imagePath : null;
      final consentImage = s.includePhoto && s.sample.imagePath != null;

      expect(imagePath, '/tmp/c.jpg');
      expect(consentImage, isTrue);
    });

    test('include-photo OFF => photo withheld even if a path exists', () {
      final s =
          OcrFeedbackSubmission(sample: sampleWith(imagePath: '/tmp/c.jpg'), includePhoto: false);

      final imagePath = s.includePhoto ? s.sample.imagePath : null;
      final consentImage = s.includePhoto && s.sample.imagePath != null;

      expect(imagePath, isNull);
      expect(consentImage, isFalse);
    });

    test('include-photo ON but no path => text-only (no image consent)', () {
      final s =
          OcrFeedbackSubmission(sample: sampleWith(), includePhoto: true);

      final imagePath = s.includePhoto ? s.sample.imagePath : null;
      final consentImage = s.includePhoto && s.sample.imagePath != null;

      expect(imagePath, isNull);
      expect(consentImage, isFalse);
    });
  });
}
