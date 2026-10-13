import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'force_update_screen.dart';
import 'soft_update_alert.dart';
import 'version_gate_decision.dart';
import 'version_gate_provider.dart';

/// Wraps the app shell (the router's built widget) and applies the version gate
/// on top of it.
///
/// Behavior by [GateDecision]:
///   - forceBlock => replace [child] with the non-dismissible
///     [ForceUpdateScreen]. A force-blocked user never reaches a route.
///   - softAlert  => show [child], and once per launch schedule the dismissible
///     [showSoftUpdateAlert]. Guarded by [_softShown] so it doesn't nag on
///     every rebuild/screen.
///   - proceed / loading / error => show [child] (FAIL-OPEN: while the decision
///     is resolving or if it errored, the app is shown normally; the gate never
///     blocks startup).
class VersionGate extends ConsumerStatefulWidget {
  const VersionGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<VersionGate> createState() => _VersionGateState();
}

class _VersionGateState extends ConsumerState<VersionGate> {
  // In-memory, not persisted: the soft alert shows once per app launch/session.
  // A cold restart re-shows it, which is intended.
  bool _softShown = false;

  @override
  Widget build(BuildContext context) {
    final decision = ref.watch(versionGateDecisionProvider);

    // Fail-open: loading or error => show the app. Only a resolved decision
    // can gate.
    final result = decision.valueOrNull ?? GateDecision.proceed;

    if (result == GateDecision.forceBlock) {
      return const ForceUpdateScreen();
    }

    if (result == GateDecision.softAlert && !_softShown) {
      _softShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showSoftUpdateAlert(context);
      });
    }

    return widget.child;
  }
}
