import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:secbizcard/core/responsive/adaptive_container.dart';
import 'package:secbizcard/core/responsive/breakpoints.dart';
import 'package:secbizcard/features/settings/data/ocr_settings_service.dart';
import 'package:secbizcard/features/contacts/data/services/ocr_tier.dart';
import 'package:secbizcard/features/contacts/data/ocr_usage_provider.dart';
import 'package:secbizcard/features/contacts/data/card_detection_config.dart';
import 'package:secbizcard/features/contacts/presentation/ocr_tier_display.dart';
import 'package:secbizcard/features/subscription/data/subscription_providers.dart';
import 'package:secbizcard/features/subscription/data/subscription_service.dart';
import 'package:secbizcard/generated/l10n/app_localizations.dart';

/// Unified, compact settings for AI-based business-card recognition (OCR).
///
/// Shows which engine is active, lets the user provide their own Google Cloud
/// Vision API key (stored only in the device secure keychain), displays this
/// month's usage, and includes a short how-to + clear on-device safety copy.
class OcrSettingsScreen extends ConsumerStatefulWidget {
  const OcrSettingsScreen({super.key});

  @override
  ConsumerState<OcrSettingsScreen> createState() => _OcrSettingsScreenState();
}

class _OcrSettingsScreenState extends ConsumerState<OcrSettingsScreen> {
  final _keyController = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  bool _hasKey = false;

  /// Whether the text currently in the key field looks like a valid Google
  /// Cloud API key. Drives the Save button's enabled state so we don't store an
  /// obviously-malformed key. The pattern is remote-tunable (see
  /// CardDetectionConfig 'byokKeyRegex') so a Google format change can be fixed
  /// from the console without a release.
  bool _keyLooksValid = false;

  /// The BYOK key-format regex, from Remote Config (falls back to the built-in
  /// Google API key format when unset/invalid).
  RegExp get _googleApiKeyPattern {
    final pattern = CardDetectionConfig.current.string('byokKeyRegex');
    try {
      return RegExp(pattern);
    } catch (_) {
      // Defensive: string() already validates, but never throw from the getter.
      return RegExp(r'^AIza[A-Za-z0-9_-]{35}$');
    }
  }

  /// The tier to DISPLAY: Flex overlays the backend tier whenever a BYOK key is
  /// present (OCR then goes straight to Google with the user's key, so the
  /// backend tier is irrelevant). Otherwise use the backend tier ([usage],
  /// from the app-level cache-first provider), defaulting to Basic while it's
  /// still unknown.
  OcrTier _effectiveTierFor(OcrUsage? usage) {
    if (_hasKey) return OcrTier.flex;
    return usage?.tier ?? OcrTier.basic;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  /// Loads only the local BYOK key flag. The backend tier/usage now comes from
  /// the app-level [ocrUsageNotifierProvider] (cache-first + revalidate), which
  /// is watched in [build] — no per-entry getOcrUsage call here anymore.
  Future<void> _load() async {
    final has = await ref.read(ocrSettingsServiceProvider).hasApiKey();
    if (mounted) setState(() => _hasKey = has);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final value = _keyController.text.trim();
    if (value.isEmpty) return;

    // If a key already exists, confirm the overwrite.
    if (_hasKey) {
      final ok = await _confirm(
        title: l10n.ocrReplaceKeyTitle,
        body: l10n.ocrReplaceKeyBody,
        confirmLabel: l10n.update,
      );
      if (ok != true) return;
    }

    setState(() => _saving = true);
    await ref.read(ocrSettingsServiceProvider).setApiKey(value);
    ref.invalidate(hasOwnVisionKeyProvider);
    _keyController.clear();
    await _load();
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.ocrKeySaved)));
    }
  }

  Future<void> _remove() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await _confirm(
      title: l10n.ocrRemoveKeyTitle,
      body: l10n.ocrRemoveKeyBody,
      confirmLabel: l10n.remove,
      destructive: true,
    );
    if (ok != true) return;

    await ref.read(ocrSettingsServiceProvider).clearApiKey();
    ref.invalidate(hasOwnVisionKeyProvider);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.ocrKeyRemoved)));
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
    bool destructive = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // App-level cache-first tier/usage. `loading` is true only before the first
    // (cache or network) value arrives; after that the card shows numbers while
    // a background revalidate may still be in flight.
    final usageAsync = ref.watch(ocrUsageNotifierProvider);
    final usage = usageAsync.valueOrNull;
    final loadingUsage = usageAsync.isLoading && !usageAsync.hasValue;
    final effectiveTier = _effectiveTierFor(usage);
    // True while a purchase/restore is still syncing with the backend. All
    // subscription actions are disabled until it completes, so the user can't
    // fire a second store action (upgrade/manage/restore) that would race the
    // pending webhook and risk a duplicate subscription.
    final syncing = ref.watch(ocrUsageSyncingProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.aiRecognitionTitle,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: AdaptiveContainer(
          maxWidth: Breakpoints.maxContentWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ① Tier + usage card.
              _buildTierCard(theme, l10n, usage, loadingUsage, syncing),

              // ② Free-tier (Basic) 800 shared-pool rule — only for Basic users
              // without a BYOK key. Paid/VIP/Flex bypass the pool, so it would
              // only confuse them.
              if (effectiveTier == OcrTier.basic) ...[
                const SizedBox(height: 12),
                _buildSharedPoolRule(theme, l10n),
              ],

              // "A key is saved on this device" reassurance (masked).
              if (_hasKey) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.lock_outline,
                        size: 14, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      '${l10n.ocrKeyMasked}  ••••••••',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),

              // BYO key section.
              Text(
                _hasKey ? l10n.ocrUpdateOwnKeyHeading : l10n.ocrUseOwnKeyHeading,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              // When a key IS set, the input is locked — the only action is to
              // remove it (which drops the user back to their real backend tier).
              // To change a key, remove it then add a new one. This makes the
              // "BYOK is active / Flex" state unambiguous.
              if (_hasKey) ...[
                Text(
                  l10n.ocrKeyLockedNote,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _remove,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.ocrRemoveKeyAction),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _keyController,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: (value) {
                    final valid =
                        _googleApiKeyPattern.hasMatch(value.trim());
                    if (valid != _keyLooksValid) {
                      setState(() => _keyLooksValid = valid);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: l10n.ocrKeyHint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.ocrKeyFormatHint,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    // Disabled until the key matches the Google API key format,
                    // so we never store an obviously-invalid key.
                    onPressed:
                        (_saving || !_keyLooksValid) ? null : _save,
                    icon: const Icon(Icons.save),
                    label: Text(l10n.save),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // How-to
              _expandable(
                theme,
                title: l10n.ocrHowToTitle,
                children: [
                  _StepText(l10n.ocrHowTo1),
                  _StepText(l10n.ocrHowTo2),
                  _StepText(l10n.ocrHowTo3),
                  _StepText(l10n.ocrHowTo4),
                ],
                actionLabel: l10n.ocrOpenConsole,
                actionUrl:
                    'https://console.cloud.google.com/apis/library/vision.googleapis.com',
              ),
              const SizedBox(height: 12),
              // Safety — lead with "your key stays on your device".
              _expandable(
                theme,
                title: l10n.ocrSafetyTitle,
                children: [
                  _StepText(l10n.ocrSafety1),
                  _StepText(l10n.ocrSafety2),
                  _StepText(l10n.ocrSafety3),
                  _StepText(l10n.ocrSafety4),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ① Tier + usage card: the effective tier, this month's usage (x/cap, ∞ for
  /// VIP, BYOK for Flex), an upgrade entry for Basic/Plus, and — for Admins —
  /// the shared800/total observability counters.
  Widget _buildTierCard(ThemeData theme, AppLocalizations l10n, OcrUsage? usage,
      bool loadingUsage, bool syncing) {
    final tier = _effectiveTierFor(usage);
    final tierName = OcrTierDisplay.tierName(l10n, tier);
    final used = usage?.tierUsed;
    final cap = usage?.tierCap;

    // Usage line on the right: ∞ icon for VIP, "BYOK" for Flex, x/cap otherwise.
    Widget usageWidget;
    if (OcrTierDisplay.isUnlimited(tier)) {
      usageWidget = Icon(OcrTierDisplay.unlimitedIcon,
          size: 20, color: theme.colorScheme.primary);
    } else if (OcrTierDisplay.isByok(tier)) {
      usageWidget = Text(
        l10n.ocrUsageByok,
        style: TextStyle(
            fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
      );
    } else if (loadingUsage) {
      usageWidget = const SizedBox(
        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
    } else {
      final usageText =
          OcrTierDisplay.usageText(l10n, tier, used: used, cap: cap);
      usageWidget = Text(
        usageText ?? l10n.ocrUsageUnknown,
        style: const TextStyle(fontWeight: FontWeight.w600),
      );
    }

    return _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                tier == OcrTier.flex ? Icons.verified : Icons.workspace_premium,
                color: tier == OcrTier.flex
                    ? Colors.green
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.ocrYourPlan,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                    const SizedBox(height: 2),
                    Text(tierName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              usageWidget,
            ],
          ),

          // Progress bar for finite paid/free tiers with known numbers.
          if (tier.hasFiniteCap && used != null && cap != null && cap > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (used / cap).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ],

          // Upgrade entry: Basic → subscribe; Plus → upgrade to Pro.
          // (Pro is the top tier — no upgrade entry; it can only be cancelled
          // via "Manage subscription" below. There is no in-app downgrade.)
          // While syncing a just-completed purchase, the button is disabled and
          // shows a "syncing" state so a second store action can't race the
          // pending webhook.
          if (tier == OcrTier.basic || tier == OcrTier.plus) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: syncing ? null : () => _showSubscribeSheet(tier),
                icon: syncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.arrow_upward, size: 18),
                label: Text(syncing
                    ? l10n.ocrSyncing
                    : (tier == OcrTier.plus
                        ? l10n.ocrUpgradeToPro
                        : l10n.ocrSubscribe)),
              ),
            ),
          ],

          // Pro ONLY: Manage subscription + Restore. Pro is the top tier, so it
          // has NO button into the paywall sheet — which is where Basic/Plus
          // users reach Manage/Restore. Without these links a Pro user would
          // have no in-app way to cancel (via the store's page) or restore, so
          // we surface them here. Basic/Plus intentionally DON'T show these:
          // their Subscribe/Upgrade button opens the paywall, which carries
          // Restore (and Manage), so duplicating them on the card is redundant.
          // Apple 3.1.1 restore is satisfied for every tier (Pro here;
          // Basic/Plus in the paywall). Disabled while syncing.
          if (tier == OcrTier.pro) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: syncing ? null : _openManageSubscription,
                  child: Text(
                      syncing ? l10n.ocrSyncing : l10n.ocrManageSubscription),
                ),
                TextButton(
                  onPressed: syncing ? null : _runRestore,
                  child: Text(l10n.ocrRestorePurchases),
                ),
              ],
            ),
          ],

          // Admin-only observability: shared800 + total counters.
          if (usage?.admin != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _buildAdminStats(theme, l10n, usage!.admin!),
          ],
        ],
      ),
    );
  }

  Widget _buildAdminStats(
      ThemeData theme, AppLocalizations l10n, OcrAdminStats stats) {
    TextStyle labelStyle = TextStyle(
        fontSize: 12, color: theme.colorScheme.onSurfaceVariant);
    TextStyle valueStyle =
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.admin_panel_settings,
              size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(l10n.ocrAdminObservability, style: labelStyle),
        ]),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.ocrAdminShared800, style: labelStyle),
            Text('${stats.shared800Used}/${stats.shared800Cap}',
                style: valueStyle),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.ocrAdminTotal, style: labelStyle),
            Text('${stats.totalUsed}', style: valueStyle),
          ],
        ),
      ],
    );
  }

  /// ② Basic-only explanation of the shared 800/month free pool + per-user 5.
  Widget _buildSharedPoolRule(ThemeData theme, AppLocalizations l10n) {
    return _card(
      theme,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline,
              size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.ocrUsingSharedQuotaDesc(
                  OcrSettingsService.sharedPerUserMonthly),
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The subscribe/upgrade sheet: explains Plus vs Pro and lets the user pick.
  /// The subscribe/upgrade sheet. Fetches the live RevenueCat offering; when
  /// packages are available (SDK keys set + store products live) it shows real
  /// prices and drives the purchase/restore flow. When the offering isn't
  /// available yet (keys not provisioned or products not created), it falls
  /// back to a static description + a "coming soon" notice — so the entry point
  /// works end-to-end today and lights up automatically once RevenueCat is set.
  Future<void> _showSubscribeSheet(OcrTier currentTier) async {
    final l10n = AppLocalizations.of(context)!;
    final service = ref.read(subscriptionServiceProvider);
    final offering = await service.fetchCurrentOffering();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        // Hide the tier the user already owns (and anything not an upgrade): a
        // Plus subscriber only sees Pro, so they can't re-buy Plus (which threw
        // the "already subscribed" error). Basic sees both.
        final allLive = offering?.availablePackages ?? const [];
        final packages = [
          for (final pkg in allLive)
            if (_isUpgradeFrom(currentTier, pkg)) pkg,
        ];
        final hasLivePackages = packages.isNotEmpty;
        // The offering exists but every plan was filtered out as already-owned
        // (e.g. only Pro exists and the user is already Pro). Don't fall back to
        // the misleading static Plus/Pro tiles in that case.
        final offeringLiveButAllOwned = allLive.isNotEmpty && packages.isEmpty;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.ocrPaywallTitle,
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold, fontSize: 20)),
                const SizedBox(height: 4),
                Text(l10n.ocrPaywallSubtitle,
                    style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 16),

                if (hasLivePackages) ...[
                  // Live RevenueCat packages: our own clean name/description
                  // (keyed on the package identifier) + the REAL store price.
                  // We deliberately avoid storeProduct.title/description, which
                  // on Android append the app name, e.g. "SecBizCard Plus
                  // (SecBizCard - Card Manager)".
                  for (final pkg in packages) ...[
                    _planTile(
                      theme,
                      _packageName(l10n, pkg),
                      pkg.storeProduct.priceString,
                      _packageDesc(l10n, pkg),
                      onTap: () => _purchase(ctx, pkg),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 10),
                  // Restore for everyone; Manage subscription only when the user
                  // already has a paid plan (a Plus user here to upgrade can
                  // instead cancel via the store). Basic has nothing to manage.
                  if (currentTier.isPaid)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _openManageSubscription();
                          },
                          child: Text(l10n.ocrManageSubscription),
                        ),
                        TextButton(
                          onPressed: () => _restore(ctx),
                          child: Text(l10n.ocrRestorePurchases),
                        ),
                      ],
                    )
                  else
                    TextButton(
                      onPressed: () => _restore(ctx),
                      child: Text(l10n.ocrRestorePurchases),
                    ),
                ] else if (offeringLiveButAllOwned) ...[
                  // Offering is live but the user already owns the top plan —
                  // offer Manage + Restore, no misleading static tiles.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openManageSubscription();
                        },
                        child: Text(l10n.ocrManageSubscription),
                      ),
                      TextButton(
                        onPressed: () => _restore(ctx),
                        child: Text(l10n.ocrRestorePurchases),
                      ),
                    ],
                  ),
                ] else ...[
                  // Fallback: static plan info until the offering goes live.
                  _planTile(theme, l10n.ocrTierPlus, l10n.ocrPlanPlusPrice,
                      l10n.ocrPlanPlusDesc),
                  const SizedBox(height: 10),
                  _planTile(theme, l10n.ocrTierPro, l10n.ocrPlanProPrice,
                      l10n.ocrPlanProDesc),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.ocrSubscribeComingSoon)),
                      );
                    },
                    child: Text(l10n.ocrSubscribe),
                  ),
                ],

                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.cancel),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The paid tier a package represents, inferred from its identifier
  /// (pro/plus). Null if unrecognized.
  OcrTier? _packageTier(Package pkg) {
    final id = pkg.identifier.toLowerCase();
    if (id.contains('pro')) return OcrTier.pro;
    if (id.contains('plus')) return OcrTier.plus;
    return null;
  }

  /// Whether [pkg] is a strict upgrade relative to [currentTier], so the paywall
  /// only offers plans above what the user already has. Basic → both Plus & Pro;
  /// Plus → only Pro; Pro → nothing. Unknown-tier packages are shown (fail open,
  /// so a mis-identified package is never silently hidden).
  bool _isUpgradeFrom(OcrTier currentTier, Package pkg) {
    final pkgTier = _packageTier(pkg);
    if (pkgTier == null) return true;
    int rank(OcrTier t) => switch (t) {
          OcrTier.pro => 2,
          OcrTier.plus => 1,
          _ => 0, // basic/vip/flex treated as "no paid plan owned" baseline
        };
    return rank(pkgTier) > rank(currentTier);
  }

  /// Clean display name for a package, keyed on its identifier (plus/pro), so
  /// we don't show the store's app-suffixed title. Falls back to the store
  /// title if the identifier is unrecognized.
  String _packageName(AppLocalizations l10n, Package pkg) {
    final id = pkg.identifier.toLowerCase();
    if (id.contains('pro')) return l10n.ocrPaywallPlanPro;
    if (id.contains('plus')) return l10n.ocrPaywallPlanPlus;
    return pkg.storeProduct.title;
  }

  /// Clean description for a package (e.g. "20 cloud scans per month").
  String _packageDesc(AppLocalizations l10n, Package pkg) {
    final id = pkg.identifier.toLowerCase();
    if (id.contains('pro')) return l10n.ocrPlanProDesc;
    if (id.contains('plus')) return l10n.ocrPlanPlusDesc;
    return pkg.storeProduct.description;
  }

  /// Run a purchase for [pkg]. Closes the sheet, then refreshes usage so the
  /// tier card reflects the new entitlement. User-cancel is silent.
  Future<void> _purchase(BuildContext sheetCtx, Package pkg) async {
    final l10n = AppLocalizations.of(context)!;
    final service = ref.read(subscriptionServiceProvider);
    Navigator.pop(sheetCtx);
    try {
      // If the user already has a paid subscription and is switching plans
      // (e.g. Plus → Pro), pass its product id so Google Play REPLACES the old
      // subscription instead of opening a second one (which caused both to stay
      // active + duplicate billing). Only when it differs from the target.
      final oldProductId = await service.currentActiveProductId();
      final targetProductId = pkg.storeProduct.identifier.split(':').first;
      final upgradeFrom = (oldProductId != null &&
              oldProductId.isNotEmpty &&
              oldProductId != targetProductId)
          ? oldProductId
          : null;

      final tier = await service.purchase(pkg, oldProductIdentifier: upgradeFrom);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.ocrSubscribeThanks)));
      // Optimistically reflect the new tier immediately (RevenueCat already
      // confirmed it) so the card shows Plus/Pro at once, then POLL the backend
      // until the entitlement webhook has written Firestore and getOcrUsage
      // returns the real used/cap (e.g. Plus 0/20). This avoids the old "shows
      // Plus, flickers back to Basic, only correct after leaving+returning":
      // the poll keeps the optimistic tier until the authoritative numbers land
      // (a couple of seconds with RTDN), then caches them for every screen.
      _applyOptimisticTier(tier);
      final target = _optimisticOcrTierFor(tier);
      final notifier = ref.read(ocrUsageNotifierProvider.notifier);
      if (target != null) {
        await notifier.refreshUntilTierReached(target);
      } else {
        await notifier.refresh();
      }
    } on PlatformException catch (e) {
      // User cancellation is not an error worth surfacing.
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.ocrSubscribeFailed)));
    }
  }

  Future<void> _restore(BuildContext sheetCtx) async {
    Navigator.pop(sheetCtx);
    await _runRestore();
  }

  Future<void> _runRestore() async {
    final l10n = AppLocalizations.of(context)!;
    final service = ref.read(subscriptionServiceProvider);
    try {
      final tier = await service.restore();
      if (!mounted) return;
      // Reflect the real outcome: only say "restored" when an active paid
      // entitlement actually came back. A restore that finds nothing (e.g. the
      // user already cancelled, or never purchased on this account) must not
      // claim success — that was the misleading "Purchases restored" after a
      // cancel. `none` → "no purchases to restore".
      final restored = tier != SubscriptionTier.none;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(restored ? l10n.ocrRestoreDone : l10n.ocrRestoreNone),
      ));
      // _applyOptimisticTier no-ops on `none`, so a failed restore never
      // re-raises the displayed tier. When something WAS restored, poll until
      // the backend confirms the tier + real usage (same as purchase); when
      // nothing was, a single refresh reconciles the truth.
      _applyOptimisticTier(tier);
      final target = _optimisticOcrTierFor(tier);
      final notifier = ref.read(ocrUsageNotifierProvider.notifier);
      if (target != null) {
        await notifier.refreshUntilTierReached(target);
      } else {
        await notifier.refresh();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.ocrSubscribeFailed)));
    }
  }

  /// Opens the platform's subscription management page (Play/Apple) via the
  /// RevenueCat-provided managementURL. This is the (by-design) only place to
  /// cancel — there is no in-app downgrade. Falls back to a snackbar if no URL.
  Future<void> _openManageSubscription() async {
    final l10n = AppLocalizations.of(context)!;
    final url = await ref.read(subscriptionServiceProvider).managementUrl();
    if (!mounted) return;
    if (url == null) {
      // No management URL (e.g. sandbox edge / not configured) — nothing to open.
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.ocrSubscribeFailed)));
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.ocrSubscribeFailed)));
    }
  }

  /// The [OcrTier] a RevenueCat [SubscriptionTier] result maps to, or null when
  /// it carries no paid entitlement (`none`) — used both to set the optimistic
  /// tier and as the poll target.
  OcrTier? _optimisticOcrTierFor(SubscriptionTier tier) => switch (tier) {
        SubscriptionTier.plus => OcrTier.plus,
        SubscriptionTier.pro => OcrTier.pro,
        SubscriptionTier.none => null,
      };

  /// Map a RevenueCat [SubscriptionTier] result to our [OcrTier] and push it to
  /// the shared usage provider for an instant UI update. Skipped when a BYOK
  /// key is set (Flex overrides the backend tier) or when RevenueCat reports no
  /// active entitlement (let the backend refresh decide, don't downgrade the
  /// display optimistically).
  void _applyOptimisticTier(SubscriptionTier tier) {
    if (_hasKey) return;
    final mapped = _optimisticOcrTierFor(tier);
    if (mapped == null) return;
    ref.read(ocrUsageNotifierProvider.notifier).setTierOptimistic(mapped);
  }

  Widget _planTile(
      ThemeData theme, String name, String price, String desc,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(desc,
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Text(price,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.chevron_right,
                  size: 18, color: theme.colorScheme.onSurfaceVariant),
            ],
          ],
        ),
      ),
    );
  }

  Widget _card(ThemeData theme, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: child,
    );
  }

  Widget _expandable(
    ThemeData theme, {
    required String title,
    required List<Widget> children,
    String? actionLabel,
    String? actionUrl,
    bool initiallyExpanded = false,
  }) {
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        initiallyExpanded: initiallyExpanded,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        expandedAlignment: Alignment.centerLeft,
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        children: [
          ...children,
          if (actionLabel != null && actionUrl != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(actionUrl),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(actionLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepText extends StatelessWidget {
  const _StepText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: SizedBox(
        width: double.infinity,
        child: Text(
          text,
          textAlign: TextAlign.left,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
