import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:secbizcard/features/contacts/data/card_detection_config.dart';
import 'version_gate_decision.dart';

/// Reads the running app BUILD NUMBER as an int.
///
/// Fail-open: any error (plugin failure, unparseable build string) resolves to
/// null, which the decision function treats as [GateDecision.proceed].
Future<int?> readRunningBuild() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber);
  } catch (e) {
    debugPrint('[VersionGate] readRunningBuild failed (fail-open): $e');
    return null;
  }
}

/// Resolves the version-gate decision from the running build and the two
/// Remote Config thresholds (reused from the already-activated
/// [CardDetectionConfig] instance — no second RC setup, no blocking network
/// wait).
///
/// FAIL-OPEN: the whole computation is wrapped so any error returns
/// [GateDecision.proceed]. Startup is never awaited on this; the gate widget
/// shows the app while this resolves and only reacts once a decision is ready.
final versionGateDecisionProvider = FutureProvider<GateDecision>((ref) async {
  try {
    final runningBuild = await readRunningBuild();
    final config = CardDetectionConfig.current;
    return evaluateVersionGate(
      runningBuild: runningBuild,
      minSupportedBuild: config.intValue('min_supported_build'),
      latestBuild: config.intValue('latest_build'),
    );
  } catch (e) {
    debugPrint('[VersionGate] decision failed (fail-open to proceed): $e');
    return GateDecision.proceed;
  }
});
