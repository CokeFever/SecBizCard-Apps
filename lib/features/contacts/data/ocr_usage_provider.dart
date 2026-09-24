import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:secbizcard/features/auth/data/auth_repository.dart';
import 'package:secbizcard/features/contacts/data/services/ocr_tier.dart';

part 'ocr_usage_provider.g.dart';

/// App-level, cache-first source of truth for the caller's backend OCR tier +
/// monthly usage ({tier, tierUsed, tierCap}).
///
/// Why this exists: the AI Recognition screen and the scan screen each used to
/// call the `getOcrUsage` Cloud Function on entry, causing a visible delay/
/// flicker before the tier/badge could render. This provider centralizes that
/// fetch and serves it **stale-while-revalidate**:
///
///  1. `build()` seeds `state` from a per-uid disk cache (SharedPreferences) so
///     consumers render instantly with the last-known tier.
///  2. It then revalidates in the background via `getOcrUsage`; on success it
///     updates `state` and rewrites the cache.
///
/// It is keyed on the current Firebase uid (via [authStateProvider]): when the
/// uid changes (sign-in / user-switch) Riverpod rebuilds against the new user's
/// cache; on logout (uid → null) the state is null and the previous user's
/// cache entry is cleared.
///
/// Scope: this caches the **backend** view only (basic/plus/pro/vip). The
/// client-side Flex/BYOK overlay is NOT cached here — consumers must overlay it
/// live from `hasApiKey()` / `hasOwnVisionKeyProvider`, because a saved Cloud
/// Vision key sends OCR straight to Google and overrides the backend tier.
///
/// Freshness: the cache only affects DISPLAY. Real quota gating happens on the
/// backend on every scan, so a briefly-stale cache (e.g. right after a plan
/// expires) never grants the wrong quota — it just shows a slightly old tier
/// until the next revalidate lands.
@riverpod
class OcrUsageNotifier extends _$OcrUsageNotifier {
  static const _cachePrefix = 'ocr_usage_cache_';

  /// How long an optimistic tier is protected from being overwritten by a
  /// LOWER backend tier. After a purchase the app sets the tier optimistically,
  /// then immediately refreshes — but the RevenueCat webhook often hasn't
  /// written the backend yet, so that refresh would read the OLD (lower) tier
  /// and clobber the optimistic one (the "jumps back to Basic" flicker). During
  /// this window a lower fresh tier is ignored; a same-or-higher one (webhook
  /// landed) is accepted and clears the window. RTDN makes the webhook fast, so
  /// this window rarely needs its full length.
  static const _optimisticHold = Duration(seconds: 45);

  /// The optimistically-set tier and its protection deadline. Null when no
  /// optimistic tier is active (never set, or the window elapsed / was cleared).
  OcrTier? _optimisticTier;
  DateTime? _optimisticUntil;

  /// True while a post-purchase poll is running — i.e. the tier is shown
  /// optimistically but the backend hasn't confirmed the authoritative used/cap
  /// yet. The UI disables further subscription actions (subscribe / upgrade /
  /// manage / restore) during this window so the user can't fire a second
  /// store action before the first is fully synced (which would race
  /// currentActiveProductId and risk a duplicate subscription). Exposed via
  /// [ocrUsageSyncingProvider].
  bool _syncing = false;
  bool get isSyncing => _syncing;

  void _setSyncing(bool value) {
    if (_syncing == value) return;
    _syncing = value;
    ref.notifyListeners(); // wake ocrUsageSyncingProvider watchers
  }

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(app: Firebase.app(), region: 'us-central1');

  String? _cacheKeyFor(String uid) => '$_cachePrefix$uid';

  /// Paid-rank ordering for protecting an optimistic tier: pro > plus > every
  /// other tier (basic/vip/flex treated as the non-paid baseline here — this
  /// guard only ever protects a freshly-purchased paid tier).
  int _rank(OcrTier t) => switch (t) {
        OcrTier.pro => 2,
        OcrTier.plus => 1,
        _ => 0,
      };

  @override
  Future<OcrUsage?> build() async {
    // Rebuilds whenever the signed-in user changes.
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    if (uid == null) return null;

    // 1. Seed from disk cache for an instant first paint.
    final cached = await _readCache(uid);

    // 2. Revalidate in the background; update state + cache on success.
    //    Detached from build() so we don't block the first paint on the network.
    Future.microtask(() => _revalidate(uid));

    return cached;
  }

  /// Forces a fresh `getOcrUsage` fetch and updates the cache. Call after a
  /// purchase / restore, or when RevenueCat reports an entitlement change.
  Future<void> refresh() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    await _revalidate(uid);
  }

  /// Poll the backend until it reports [target] (or higher), then stop.
  ///
  /// After a purchase the tier is set optimistically (Plus, usage unknown), but
  /// the authoritative used/cap only appear once the RevenueCat webhook has
  /// written Firestore. A single refresh often races ahead of that write, so we
  /// poll a few times: each attempt fetches `getOcrUsage`; once the backend tier
  /// reaches [target] it carries the real numbers (e.g. Plus 0/20), we apply +
  /// cache them and stop. Bounded so it never spins forever — if the webhook is
  /// unusually slow, the optimistic tier stays shown and the next screen entry
  /// (build) or app-resume refresh reconciles it. With RTDN configured the
  /// webhook is typically 1–3s, so this resolves in a couple of polls.
  ///
  /// No-op when signed out or [target] isn't a paid tier.
  Future<void> refreshUntilTierReached(
    OcrTier target, {
    int maxAttempts = 8,
    Duration interval = const Duration(milliseconds: 1200),
  }) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null || _rank(target) == 0) return;

    _setSyncing(true);
    try {
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        final fresh = await _fetch();
        // User switched mid-poll → abandon.
        if (ref.read(authStateProvider).valueOrNull?.uid != uid) return;

        if (fresh != null && _rank(fresh.tier) >= _rank(target)) {
          // Webhook landed: authoritative tier + used/cap. Apply, cache, done.
          _clearOptimistic();
          state = AsyncData(fresh);
          await _writeCache(uid, fresh);
          return;
        }
        // Backend hasn't caught up yet (fresh is null/lower). Keep the
        // optimistic tier visible (the hold window in _revalidate protects it)
        // and wait before the next attempt — except after the final attempt.
        if (attempt < maxAttempts - 1) {
          await Future<void>.delayed(interval);
        }
      }
      // Timed out: leave the optimistic tier in place; build()/resume fixes up.
    } finally {
      _setSyncing(false);
    }
  }

  /// Immediately reflect a locally-confirmed tier (from a RevenueCat
  /// purchase/restore result) WITHOUT waiting for the backend webhook + a
  /// getOcrUsage round-trip. The used/cap numbers aren't known client-side, so
  /// they're left null (the tier card shows the new tier name, and usage
  /// resolves to "unknown" / no progress bar) until the subsequent [refresh]
  /// lands the authoritative counts. Also writes the cache so a quick screen
  /// re-entry shows the new tier too. No-op when signed out or when the tier is
  /// unchanged.
  Future<void> setTierOptimistic(OcrTier tier) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    final prev = state.valueOrNull;
    // Arm the protection window regardless of whether the tier value changed,
    // so a refresh racing an in-flight webhook can't drop us below this tier.
    _optimisticTier = tier;
    _optimisticUntil = DateTime.now().add(_optimisticHold);
    if (prev?.tier == tier) return; // display already correct; window is armed
    final optimistic = OcrUsage(
      tier: tier,
      // Unknown until the backend refresh; leaving null avoids showing a stale
      // count against the new cap.
      tierUsed: null,
      tierCap: null,
      admin: prev?.admin,
    );
    state = AsyncData(optimistic);
    await _writeCache(uid, optimistic);
  }

  Future<void> _revalidate(String uid) async {
    final fresh = await _fetch();
    if (fresh == null) return; // offline / error → keep whatever we have
    // Guard against a user-switch that happened mid-flight.
    if (ref.read(authStateProvider).valueOrNull?.uid != uid) return;

    // Optimistic-tier protection: within the hold window, ignore a fresh tier
    // that ranks BELOW the optimistic one — it's almost certainly the backend
    // read racing ahead of the RevenueCat webhook (the "jumps back to Basic"
    // flicker right after purchase). A same-or-higher fresh tier means the
    // webhook has landed (and carries real used/cap), so accept it and clear
    // the window. Once the window elapses, all fresh values apply normally
    // (so a genuine cancel/expiry downgrade is never blocked).
    final opt = _optimisticTier;
    final until = _optimisticUntil;
    if (opt != null && until != null) {
      if (DateTime.now().isBefore(until)) {
        if (_rank(fresh.tier) < _rank(opt)) {
          return; // keep the optimistic tier; webhook hasn't caught up yet
        }
        // Fresh tier reached (or exceeded) the optimistic one → webhook landed.
        _clearOptimistic();
      } else {
        _clearOptimistic(); // window elapsed
      }
    }

    state = AsyncData(fresh);
    await _writeCache(uid, fresh);
  }

  void _clearOptimistic() {
    _optimisticTier = null;
    _optimisticUntil = null;
  }

  /// One `getOcrUsage` call. Never throws — offline/error returns null so the
  /// cached value (if any) stays in place.
  Future<OcrUsage?> _fetch() async {
    try {
      final res = await _functions
          .httpsCallable('getOcrUsage')
          .call()
          .timeout(const Duration(seconds: 8));
      return OcrUsage.fromMap(Map<String, dynamic>.from(res.data as Map));
    } catch (_) {
      return null;
    }
  }

  Future<OcrUsage?> _readCache(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKeyFor(uid)!);
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return OcrUsage.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(String uid, OcrUsage usage) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKeyFor(uid)!, jsonEncode(usage.toMap()));
    } catch (e) {
      if (kDebugMode) debugPrint('[OcrUsage] cache write failed: $e');
    }
  }

  /// Clears the cached snapshot for [uid] (call on logout so a shared device
  /// doesn't leak the previous user's tier).
  Future<void> clearCacheFor(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKeyFor(uid)!);
    } catch (_) {
      // best-effort
    }
  }
}

/// Whether a post-purchase sync is in progress (tier shown optimistically, but
/// the backend hasn't confirmed the authoritative usage yet). The subscription
/// UI watches this to disable further store actions (subscribe / upgrade /
/// manage / restore) until the first action is fully synced — preventing a
/// second store action from racing the still-pending webhook (which could open
/// a duplicate subscription). Depends on [ocrUsageNotifierProvider] so it
/// rebuilds whenever the notifier calls notifyListeners().
@riverpod
bool ocrUsageSyncing(Ref ref) {
  // Establish the dependency + rebuild trigger.
  ref.watch(ocrUsageNotifierProvider);
  return ref.read(ocrUsageNotifierProvider.notifier).isSyncing;
}
