// Shared OCR subscription-tier types, aligned with the backend two-counter
// quota model (SecBizCard/functions/src/quota.ts).
//
// The backend resolves one of: basic / plus / pro / vip. Flex/BYOK is a
// CLIENT-side state — when the device has a saved Cloud Vision key, OCR goes
// straight to Google with that key and never reaches the backend, so the
// backend never reports "flex". The app synthesizes Flex from `hasApiKey()`
// and it takes precedence over whatever tier the backend would report.

/// A subscription tier as understood by the app UI.
enum OcrTier {
  /// Free track: shared key, gated by global 800 + per-user 5.
  basic,

  /// Paid: independent 20/month pool, bypasses the free budget pool.
  plus,

  /// Paid: independent 100/month pool.
  pro,

  /// Internal allow-list (owner + early testers): unlimited.
  vip,

  /// BYOK: the user brought their own Cloud Vision key. Client-only; unlimited
  /// via the user's own key/billing. Not tracked by our backend.
  flex;

  /// Parse a backend tier string. Unknown/absent → basic (fail-safe, matches
  /// the backend's own resolveTier default). Backend never sends "flex".
  static OcrTier fromBackend(String? s) {
    switch (s) {
      case 'plus':
        return OcrTier.plus;
      case 'pro':
        return OcrTier.pro;
      case 'vip':
        return OcrTier.vip;
      case 'basic':
      default:
        return OcrTier.basic;
    }
  }

  /// Whether this tier has a finite monthly cap the UI shows as "used/cap".
  /// VIP is unlimited (shown as ∞); Flex is BYOK (shown as "BYOK").
  bool get hasFiniteCap => this == OcrTier.basic || this == OcrTier.plus || this == OcrTier.pro;

  /// True for the paid subscription tiers.
  bool get isPaid => this == OcrTier.plus || this == OcrTier.pro;

  /// The backend string for this tier (inverse of [fromBackend]). Used when
  /// serializing a cached [OcrUsage] so it round-trips through [fromBackend].
  /// Flex is client-only and never persisted as a backend tier; it maps to
  /// "basic" defensively (a cached snapshot never carries flex — see OcrUsage).
  String toBackend() {
    switch (this) {
      case OcrTier.plus:
        return 'plus';
      case OcrTier.pro:
        return 'pro';
      case OcrTier.vip:
        return 'vip';
      case OcrTier.basic:
      case OcrTier.flex:
        return 'basic';
    }
  }
}

/// Admin-only observability counters (returned by getOcrUsage only for accounts
/// on ADMIN_UIDS). Null for everyone else.
class OcrAdminStats {
  const OcrAdminStats({
    required this.shared800Used,
    required this.shared800Cap,
    required this.totalUsed,
  });

  /// Free budget pool consumed this month (Basic users only feed this).
  final int shared800Used;
  final int shared800Cap;

  /// Real total Vision calls on the shared key this month, across all tiers
  /// (billing observability).
  final int totalUsed;

  static OcrAdminStats? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    final shared = m['shared800'] is Map
        ? Map<String, dynamic>.from(m['shared800'] as Map)
        : null;
    final total = m['total'] is Map
        ? Map<String, dynamic>.from(m['total'] as Map)
        : null;
    if (shared == null || total == null) return null;
    return OcrAdminStats(
      shared800Used: (shared['used'] as num?)?.toInt() ?? 0,
      shared800Cap: (shared['cap'] as num?)?.toInt() ?? 0,
      totalUsed: (total['used'] as num?)?.toInt() ?? 0,
    );
  }

  /// Serializes back to the same `{shared800:{used,cap}, total:{used}}` shape
  /// `fromMap` reads, so a cached snapshot round-trips.
  Map<String, dynamic> toMap() => {
        'shared800': {'used': shared800Used, 'cap': shared800Cap},
        'total': {'used': totalUsed},
      };
}

/// The caller's current OCR usage snapshot from getOcrUsage / recognizeCard,
/// aligned with the backend `{tier, tierUsed, tierCap}` shape.
///
/// This represents the BACKEND view (basic/plus/pro/vip). The app overlays Flex
/// on top when a BYOK key is present — see [effectiveTier].
class OcrUsage {
  const OcrUsage({
    required this.tier,
    this.tierUsed,
    this.tierCap,
    this.admin,
  });

  final OcrTier tier;

  /// Scans used this month on the gating tier. Null when unknown (offline).
  final int? tierUsed;

  /// Cap for the gating tier. Null = unlimited (VIP). Also null when unknown.
  final int? tierCap;

  /// Admin observability block; non-null only for admin accounts.
  final OcrAdminStats? admin;

  bool get isAdmin => admin != null;

  /// Parse the getOcrUsage response. `tierCap` is intentionally allowed to be
  /// null (VIP = unlimited); we distinguish "unlimited" from "unknown" via the
  /// tier (VIP → unlimited; others with null cap → unknown/offline).
  factory OcrUsage.fromMap(Map<String, dynamic> data) {
    return OcrUsage(
      tier: OcrTier.fromBackend(data['tier']?.toString()),
      tierUsed: (data['tierUsed'] as num?)?.toInt(),
      tierCap: (data['tierCap'] as num?)?.toInt(),
      admin: OcrAdminStats.fromMap(
        data['admin'] is Map
            ? Map<String, dynamic>.from(data['admin'] as Map)
            : null,
      ),
    );
  }

  /// Serializes to the same shape [fromMap] reads, so a snapshot can be cached
  /// on disk and restored losslessly. `tierUsed`/`tierCap` are only written when
  /// non-null, preserving the "null cap = unlimited (VIP) vs unknown" semantics:
  /// on restore, [fromMap] re-derives unlimited-vs-unknown from the tier exactly
  /// as it does for a fresh backend response. Admin stats are observability-only
  /// and intentionally NOT cached (recomputed live for admins).
  Map<String, dynamic> toMap() => {
        'tier': tier.toBackend(),
        if (tierUsed != null) 'tierUsed': tierUsed,
        if (tierCap != null) 'tierCap': tierCap,
      };
}
