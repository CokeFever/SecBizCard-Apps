import 'package:flutter_test/flutter_test.dart';
import 'package:secbizcard/features/contacts/data/recognition_quality.dart';

void main() {
  group('predictLikelyPoorRecognition', () {
    test('a clean, complete result does NOT flag', () {
      final poor = predictLikelyPoorRecognition(const RecognitionSignals(
        detectionFallback: false,
        detectionScore: 0.9,
        bestNameScore: 120,
        coverageRatio: 0.9,
        orientationMismatch: false,
        hasName: true,
        hasAnyPhone: true,
        nameLooksSuspicious: false,
      ));
      expect(poor, isFalse);
    });

    test('detection fallback flags', () {
      final poor = predictLikelyPoorRecognition(
          const RecognitionSignals(detectionFallback: true));
      expect(poor, isTrue);
    });

    test('orientation mismatch flags', () {
      final poor = predictLikelyPoorRecognition(
          const RecognitionSignals(orientationMismatch: true));
      expect(poor, isTrue);
    });

    test('no name flags', () {
      final poor = predictLikelyPoorRecognition(
          const RecognitionSignals(hasName: false));
      expect(poor, isTrue);
    });

    // The Kantar blind spot: name scored HIGH (so #4 never fires) but the
    // chosen name is actually the job title. nameLooksSuspicious must catch it.
    test('confidently-wrong name (suspicious) flags even with a high score', () {
      final poor = predictLikelyPoorRecognition(const RecognitionSignals(
        detectionFallback: false,
        detectionScore: 0.9,
        bestNameScore: 148, // high — the old blind spot
        coverageRatio: 0.9,
        orientationMismatch: false,
        hasName: true,
        hasAnyPhone: true,
        nameLooksSuspicious: true,
      ));
      expect(poor, isTrue);
    });
  });
}
