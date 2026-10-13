/// Pure decision logic for the remote-controlled app version gate.
///
/// This file has ZERO Flutter / Firebase / plugin imports on purpose, so the
/// decision rules are unit-testable with no mocks and no platform channels.
/// All UI and Remote-Config plumbing lives elsewhere; this is just the math.
///
/// The gate compares BUILD NUMBERS (integers), never version strings. The
/// running build comes from `package_info_plus`; the two thresholds come from
/// Firebase Remote Config (reused from `CardDetectionConfig`):
///   - `min_supported_build` (default 180): FORCE threshold.
///   - `latest_build`        (default 0):   SOFT-ALERT threshold (0 = off).
///
/// FAIL-OPEN CONTRACT (critical): if any input is null/unavailable — Remote
/// Config not activated yet, a key missing, or the running build unknown — the
/// gate returns [GateDecision.proceed]. A user is NEVER locked out because
/// Remote Config could not be read. Downgrade/sideload protection is therefore
/// an ONLINE-time guarantee only: a rare user who downgrades while offline (so
/// no fresh RC) may slip through until the next online launch. That is an
/// accepted trade-off — never block on unavailable config.
enum GateDecision {
  /// Normal startup; show the app.
  proceed,

  /// Running build is below `latest_build` (but at/above `min_supported_build`):
  /// show a dismissible "update available" prompt, user may continue.
  softAlert,

  /// Running build is below `min_supported_build`: show a non-dismissible
  /// full-screen update wall. Force wins over soft-alert.
  forceBlock,
}

/// Decide what the version gate should do.
///
/// Rules (compare by int build number):
///   - [runningBuild] null                       => [GateDecision.proceed] (fail-open)
///   - runningBuild <  minSupportedBuild          => [GateDecision.forceBlock] (force wins)
///   - minSupportedBuild <= runningBuild < latestBuild (latestBuild > 0)
///                                                => [GateDecision.softAlert]
///   - otherwise                                  => [GateDecision.proceed]
///
/// Missing thresholds fail open: a null [minSupportedBuild] is treated as 0 (no
/// force wall) and a null/0 [latestBuild] disables the soft alert.
GateDecision evaluateVersionGate({
  required int? runningBuild,
  required int? minSupportedBuild,
  required int? latestBuild,
}) {
  // Fail-open: unknown running build => never gate.
  if (runningBuild == null) return GateDecision.proceed;

  // Missing thresholds mean "no gate configured" => treat as 0.
  final minBuild = minSupportedBuild ?? 0;
  final latest = latestBuild ?? 0;

  // Force wins over alert.
  if (runningBuild < minBuild) return GateDecision.forceBlock;

  // Soft alert only when latest_build is set (> 0) and we're below it.
  if (latest > 0 && runningBuild < latest) return GateDecision.softAlert;

  return GateDecision.proceed;
}
