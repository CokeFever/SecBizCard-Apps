import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Remote-tunable configuration for business-card detection.
///
/// Layer 1 of the OCR-tuning-without-releases plan: the geometric scoring
/// constants (documented in `docs/card_detection_scoring.md` and implemented
/// natively in `OpenCVProcessor.kt` / `CardScoring.swift`) are externalized to
/// Firebase Remote Config so they can be tuned from the console without
/// shipping a new app build. iOS and Android read the SAME keys here (route A:
/// Dart reads, passes values into the native `processCard` / `manualCrop` calls
/// via the method channel), which also keeps the two platforms in lockstep.
///
/// Partial layer 2: the `useCentroidCornerSort` gradual-rollout flag lets the
/// corner-ordering fix ship enabled-by-default while remaining reversible from
/// the console (flip it off to fall back to the legacy sort) without a release.
///
/// Safety contract:
///  - **Offline / first launch always works.** Until a fetch has activated,
///    the in-app defaults (identical to the native built-in constants) are
///    used. Init never blocks the scan flow.
///  - **Every value is range-clamped.** Remote Config can change behavior,
///    which means it can also change it *badly*; out-of-range or nonsensical
///    values are ignored in favor of the default so a console typo can't break
///    detection in the field.
///  - **Restart-to-apply.** We fetch on startup and activate; the activated
///    values are used on the *next* launch (long minimum fetch interval), which
///    is the agreed refresh cadence.
///
/// The native side ALSO keeps its own built-in constants and treats every key
/// in the passed map as optional — so if this map is empty or a key is missing,
/// behavior is exactly the current shipped behavior.
class CardDetectionConfig {
  CardDetectionConfig._(this._values, this._flags, this._strings, this._ints);

  final Map<String, double> _values;
  final Map<String, bool> _flags;
  final Map<String, String> _strings;
  final Map<String, int> _ints;

  // ---- In-app defaults: MUST match OpenCVProcessor.kt `object S` and
  //      CardScoring.swift `static let`. Keep in sync with the spec. ---------
  static const Map<String, double> _defaults = <String, double>{
    'minAcceptScore': 0.55,
    'wAngle': 0.40,
    'wParallel': 0.20,
    'wAspect': 0.15,
    'wArea': 0.10,
    'wGuide': 0.15,
    'angleToleranceDeg': 35.0,
    'parallelToleranceDeg': 25.0,
    'cardAspectRatio': 1.586,
    'minAreaRatio': 0.10,
    'maxAreaRatio': 0.99,
    // Edge-detection thresholds (collectCandidates strategies A & B).
    'cannyLowA': 75.0,
    'cannyHighA': 200.0,
    'cannyLowB': 30.0,
    'cannyHighB': 120.0,
    // Low-confidence prediction (drives the "report bad recognition" prompt on
    // Back). A detection score at/below this (but still >= minAcceptScore, i.e.
    // it was accepted) is considered shaky. Name score at/below this means no
    // line looked like a real name. Tunable via Remote Config.
    'poorDetectionScoreBelow': 0.68,
    'poorNameScoreBelow': 40.0,
    // Card detected but covering less than this fraction of the frame is
    // treated as poor (likely bad edge detection / user too far). Tunable.
    'poorCoverageBelow': 0.7,
    // OCR name-scorer weight: penalty applied when a candidate line is a PURE
    // job-title phrase (every word a title keyword/modifier, e.g. "Managing
    // Director"), so it can't win the Name slot over the real name. Passed to
    // SecBizCardOcr.parseLines(tuning:). Negative. Tunable via Remote Config;
    // the detection RULE itself is code in the OCR package.
    'pureTitleNamePenalty': -120.0,
    // Guide+margin pre-crop: how far the guide rect is expanded outward on
    // EACH side before the hard pre-crop (fraction of the guide dimension).
    // 0.25 = +25% per side. Range-clamped. See docs/card_detection_scoring.md.
    'precropMarginRatio': 0.25,
    // STATE 2 guide-crop fallback: when card-edge detection fails, the stored
    // "original scan" (and OCR input) is a crop of the guide region expanded by
    // this fraction on EACH side — NOT the full camera frame. Distinct from
    // precropMarginRatio (which only scopes the detection ROI, 0.25); this is
    // the SAVED/OCR crop tightness, defaulting to 0.20 (+20% per side) per the
    // owner spec. Range-clamped. See docs/card_detection_scoring.md.
    'fallbackGuideMarginRatio': 0.20,
  };

  static const Map<String, bool> _flagDefaults = <String, bool>{
    // Centroid+atan2 polar corner sort instead of the legacy x+y sort. Fixes
    // the tilted-card corner mislabeling (warped/flipped result). Defaults ON
    // as the new correct behavior; can be flipped OFF from the console as an
    // emergency rollback to the legacy sort without a release.
    'useCentroidCornerSort': true,
    // Guide+25% pre-crop: run card-edge detection on the guide region
    // (expanded by precropMarginRatio) FIRST, then fall back to full-image
    // detection on a miss. Defaults ON; flip OFF from the console as a remote
    // kill-switch without a release. The mandatory full-image fallback makes
    // ON-by-default unable to regress detection relative to today.
    'usePrecrop': true,
  };

  // ---- Integer-valued remote config: the APP VERSION GATE thresholds. -------
  //
  // These two keys drive the remote-controlled version gate (force-update +
  // soft-alert). They are compared against the running app BUILD NUMBER (int),
  // never a version string. They live here so the gate reuses the SAME
  // activated Remote Config instance as card-detection (no second RC setup).
  //
  //  - min_supported_build (default 180): FORCE threshold. A build below this
  //    gets the non-dismissible update wall (and is blocked from running an
  //    older sideloaded/downgraded build while online).
  //  - latest_build (default 0): SOFT-ALERT threshold. 0 = soft alert OFF.
  //
  // Restart-to-apply, same as the other keys. FAIL-OPEN is handled by the gate
  // (see version_gate_decision.dart / version_gate_provider.dart), NOT here:
  // this map only supplies defaults so a missing/invalid remote value falls
  // back to the shipped default rather than null.
  static const Map<String, int> _intDefaults = <String, int>{
    'min_supported_build': 180,
    'latest_build': 0,
  };

  static const Map<String, String> _stringDefaults = <String, String>{
    // Regex the BYOK settings screen uses to validate a pasted Google Cloud
    // API key before enabling Save. Externalized so that if Google ever changes
    // the key format we can update it from the console WITHOUT shipping a new
    // build. Current format: "AIza" + 35 chars of [A-Za-z0-9_-] = 39 total.
    // A remote value that isn't a compilable regex is rejected (see
    // _fromRemoteConfig) so a console typo can't lock out all keys.
    'byokKeyRegex': r'^AIza[A-Za-z0-9_-]{35}$',
  };

  /// Plausible inclusive ranges for each numeric key. A remote value outside
  /// its range is rejected and the default is kept.
  static const Map<String, List<double>> _ranges = <String, List<double>>{
    'minAcceptScore': [0.0, 1.0],
    'wAngle': [0.0, 1.0],
    'wParallel': [0.0, 1.0],
    'wAspect': [0.0, 1.0],
    'wArea': [0.0, 1.0],
    'wGuide': [0.0, 1.0],
    'angleToleranceDeg': [1.0, 89.0],
    'parallelToleranceDeg': [1.0, 89.0],
    'cardAspectRatio': [1.0, 3.0],
    'minAreaRatio': [0.0, 1.0],
    'maxAreaRatio': [0.0, 1.0],
    'poorDetectionScoreBelow': [0.0, 1.0],
    'poorNameScoreBelow': [0.0, 500.0],
    'poorCoverageBelow': [0.0, 1.0],
    'pureTitleNamePenalty': [-500.0, 0.0],
    'cannyLowA': [1.0, 500.0],
    'cannyHighA': [1.0, 500.0],
    'cannyLowB': [1.0, 500.0],
    'cannyHighB': [1.0, 500.0],
    'precropMarginRatio': [0.0, 1.0],
    'fallbackGuideMarginRatio': [0.0, 1.0],
  };

  /// Fallback instance using only in-app defaults. Used before any successful
  /// activation and whenever Remote Config is unavailable.
  factory CardDetectionConfig.defaults() => CardDetectionConfig._(
        Map.of(_defaults),
        Map.of(_flagDefaults),
        Map.of(_stringDefaults),
        Map.of(_intDefaults),
      );

  /// The current activated configuration, or in-app defaults if init hasn't
  /// run / failed. Safe to read synchronously anywhere.
  static CardDetectionConfig current = CardDetectionConfig.defaults();

  /// Initialize Remote Config and activate previously-fetched values.
  ///
  /// Fire-and-forget from startup: callers should NOT await this in a way that
  /// blocks UI. On any failure we keep the defaults. Restart-to-apply: a fetch
  /// is kicked off for the *next* launch; this launch uses whatever was
  /// activated last time.
  static Future<void> initialize() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          // Long interval => "restart to apply". A new value set in the console
          // is picked up on a subsequent launch, not mid-session.
          minimumFetchInterval: const Duration(hours: 24),
        ),
      );
      // Seed console defaults so getValue never returns a static-only miss.
      await rc.setDefaults(<String, dynamic>{
        for (final e in _defaults.entries) e.key: e.value,
        for (final e in _flagDefaults.entries) e.key: e.value,
        for (final e in _stringDefaults.entries) e.key: e.value,
        for (final e in _intDefaults.entries) e.key: e.value,
      });

      // Activate values fetched on a previous launch, then fetch for next time.
      await rc.activate();
      current = _fromRemoteConfig(rc);

      // Fire-and-forget fetch for the next launch; don't block or fail startup.
      unawaited(rc.fetch().catchError((Object e) {
        debugPrint('[CardDetectionConfig] background fetch failed: $e');
      }));
    } catch (e) {
      debugPrint('[CardDetectionConfig] init failed, using defaults: $e');
      current = CardDetectionConfig.defaults();
    }
  }

  static CardDetectionConfig _fromRemoteConfig(FirebaseRemoteConfig rc) {
    final values = Map.of(_defaults);
    for (final key in _defaults.keys) {
      final raw = rc.getDouble(key);
      final range = _ranges[key];
      if (range != null && raw >= range[0] && raw <= range[1]) {
        values[key] = raw;
      } // else keep default (out of range / not set)
    }
    final flags = Map.of(_flagDefaults);
    for (final key in _flagDefaults.keys) {
      flags[key] = rc.getBool(key);
    }
    final strings = Map.of(_stringDefaults);
    for (final key in _stringDefaults.keys) {
      final raw = rc.getString(key);
      if (raw.isEmpty) continue; // not set → keep default
      // Reject a remote value that isn't a compilable regex, so a console typo
      // can't break validation in the field (keep the shipped default instead).
      if (key == 'byokKeyRegex') {
        try {
          RegExp(raw);
        } catch (_) {
          continue; // invalid regex → keep default
        }
      }
      strings[key] = raw;
    }
    // Integer version-gate thresholds. A negative remote value is nonsensical
    // for a build number => keep the default. (Fail-open on unavailability is
    // the gate's job; here we just guard against a bad console value.)
    final ints = Map.of(_intDefaults);
    for (final key in _intDefaults.keys) {
      final raw = rc.getInt(key);
      if (raw >= 0) {
        ints[key] = raw;
      } // else keep default (negative / nonsensical)
    }
    return CardDetectionConfig._(values, flags, strings, ints);
  }

  double value(String key) => _values[key] ?? _defaults[key] ?? 0.0;
  bool flag(String key) => _flags[key] ?? _flagDefaults[key] ?? false;
  String string(String key) =>
      _strings[key] ?? _stringDefaults[key] ?? '';

  /// Reads an integer remote-config value (version-gate thresholds). Returns
  /// the shipped default if the key is unknown.
  int intValue(String key) => _ints[key] ?? _intDefaults[key] ?? 0;

  /// Packs the current tuning into a map for the native `processCard` /
  /// `manualCrop` method-channel calls. The native side treats every entry as
  /// optional and falls back to its own built-in constant for anything missing.
  Map<String, dynamic> toTuningMap() => <String, dynamic>{
        ..._values,
        ..._flags,
      };
}
