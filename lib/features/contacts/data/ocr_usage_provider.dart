import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
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

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(app: Firebase.app(), region: 'us-central1');

  String? _cacheKeyFor(String uid) => '$_cachePrefix$uid';

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
    if (prev?.tier == tier) return; // nothing to change
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
    state = AsyncData(fresh);
    await _writeCache(uid, fresh);
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
