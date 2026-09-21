import 'package:flutter/material.dart';

import 'package:secbizcard/generated/l10n/app_localizations.dart';
import 'package:secbizcard/features/contacts/data/services/ocr_tier.dart';

/// Presentation helpers that turn an [OcrTier] + usage numbers into the
/// localized strings/icons shown on the scan badge and the AI Recognition
/// screen. Kept in one place so the badge and settings card stay consistent.
///
/// Display rules (decided 2026-09-21):
///   Basic/Plus/Pro → "<Tier> · used/cap this month"
///   VIP            → "VIP · ∞"  (infinity icon, not the word)
///   Flex (BYOK)    → "Flex · BYOK"  (own key, usage untracked)
class OcrTierDisplay {
  const OcrTierDisplay._();

  /// The localized tier name (Basic/Plus/Pro/VIP/Flex).
  static String tierName(AppLocalizations l10n, OcrTier tier) {
    switch (tier) {
      case OcrTier.basic:
        return l10n.ocrTierBasic;
      case OcrTier.plus:
        return l10n.ocrTierPlus;
      case OcrTier.pro:
        return l10n.ocrTierPro;
      case OcrTier.vip:
        return l10n.ocrTierVip;
      case OcrTier.flex:
        return l10n.ocrTierFlex;
    }
  }

  /// Whether the usage portion for this tier is the infinity symbol (VIP).
  static bool isUnlimited(OcrTier tier) => tier == OcrTier.vip;

  /// Whether the usage portion is the "BYOK" label (Flex).
  static bool isByok(OcrTier tier) => tier == OcrTier.flex;

  /// The usage portion as a string, or null when it should be rendered as an
  /// icon (VIP → caller draws the ∞ icon). Flex → "BYOK"; finite → "x/cap".
  /// Returns null when finite but numbers are unknown (offline).
  static String? usageText(
    AppLocalizations l10n,
    OcrTier tier, {
    int? used,
    int? cap,
  }) {
    if (tier == OcrTier.flex) return l10n.ocrUsageByok;
    if (tier == OcrTier.vip) return null; // caller renders ∞ icon
    if (used != null && cap != null) {
      return l10n.ocrTierUsageCount(used, cap);
    }
    return null; // unknown (offline)
  }

  /// A single combined badge string for compact places (scan badge). VIP uses a
  /// literal ∞ here since the badge is text-only.
  static String badgeLabel(
    AppLocalizations l10n,
    OcrTier tier, {
    int? used,
    int? cap,
  }) {
    final name = tierName(l10n, tier);
    if (tier == OcrTier.vip) return l10n.ocrTierBadge(name, '∞');
    final usage = usageText(l10n, tier, used: used, cap: cap);
    if (usage == null) return name; // unknown numbers → just the tier name
    return l10n.ocrTierBadge(name, usage);
  }

  /// Icon representing "unlimited" for VIP rows.
  static const IconData unlimitedIcon = Icons.all_inclusive;
}
