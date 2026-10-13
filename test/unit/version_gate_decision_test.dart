import 'package:flutter_test/flutter_test.dart';
import 'package:secbizcard/core/version_gate/version_gate_decision.dart';

/// Unit tests for the PURE version-gate decision function.
///
/// Pure Dart, no Flutter/Firebase/plugin imports — matches the project's
/// pure-Dart unit-test style (see precrop_state2_geometry_test.dart). Covers
/// force/soft/proceed thresholds, force precedence, boundaries, and the
/// fail-open contract (null / missing values => proceed).
void main() {
  group('evaluateVersionGate', () {
    test('running build null => proceed (fail-open)', () {
      expect(
        evaluateVersionGate(
          runningBuild: null,
          minSupportedBuild: 180,
          latestBuild: 200,
        ),
        GateDecision.proceed,
      );
    });

    test('both thresholds null => proceed (no gate configured)', () {
      expect(
        evaluateVersionGate(
          runningBuild: 191,
          minSupportedBuild: null,
          latestBuild: null,
        ),
        GateDecision.proceed,
      );
    });

    test('running < min => forceBlock', () {
      expect(
        evaluateVersionGate(
          runningBuild: 179,
          minSupportedBuild: 180,
          latestBuild: 0,
        ),
        GateDecision.forceBlock,
      );
    });

    test('running == min, latest > min => softAlert', () {
      expect(
        evaluateVersionGate(
          runningBuild: 180,
          minSupportedBuild: 180,
          latestBuild: 200,
        ),
        GateDecision.softAlert,
      );
    });

    test('min <= running < latest => softAlert', () {
      expect(
        evaluateVersionGate(
          runningBuild: 191,
          minSupportedBuild: 180,
          latestBuild: 200,
        ),
        GateDecision.softAlert,
      );
    });

    test('running >= latest (and >= min) => proceed', () {
      expect(
        evaluateVersionGate(
          runningBuild: 200,
          minSupportedBuild: 180,
          latestBuild: 200,
        ),
        GateDecision.proceed,
      );
      expect(
        evaluateVersionGate(
          runningBuild: 250,
          minSupportedBuild: 180,
          latestBuild: 200,
        ),
        GateDecision.proceed,
      );
    });

    test('force precedence: running < min AND < latest => forceBlock', () {
      expect(
        evaluateVersionGate(
          runningBuild: 100,
          minSupportedBuild: 180,
          latestBuild: 200,
        ),
        GateDecision.forceBlock,
      );
    });

    test('running == latest => proceed (latest is exclusive upper bound)', () {
      expect(
        evaluateVersionGate(
          runningBuild: 200,
          minSupportedBuild: 180,
          latestBuild: 200,
        ),
        GateDecision.proceed,
      );
    });

    test('min null but latest set, running < latest => softAlert', () {
      expect(
        evaluateVersionGate(
          runningBuild: 150,
          minSupportedBuild: null,
          latestBuild: 200,
        ),
        GateDecision.softAlert,
      );
    });

    test('latest == 0 (default) with running >= min => proceed', () {
      expect(
        evaluateVersionGate(
          runningBuild: 191,
          minSupportedBuild: 180,
          latestBuild: 0,
        ),
        GateDecision.proceed,
      );
    });

    test('latest == 0 never triggers softAlert even when running >= min', () {
      expect(
        evaluateVersionGate(
          runningBuild: 180,
          minSupportedBuild: 180,
          latestBuild: 0,
        ),
        GateDecision.proceed,
      );
    });
  });
}
