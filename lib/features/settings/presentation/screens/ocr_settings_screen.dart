import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:secbizcard/core/responsive/adaptive_container.dart';
import 'package:secbizcard/core/responsive/breakpoints.dart';
import 'package:secbizcard/features/settings/data/ocr_settings_service.dart';
import 'package:secbizcard/features/contacts/data/services/ocr_tier.dart';
import 'package:secbizcard/features/contacts/presentation/ocr_tier_display.dart';
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

  /// Backend usage snapshot (tier/tierUsed/tierCap + admin stats). Null while
  /// loading or when offline/unavailable.
  OcrUsage? _usage;
  bool _loadingUsage = true;

  late final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(app: Firebase.app(), region: 'us-central1');

  /// The tier to DISPLAY: Flex overlays the backend tier whenever a BYOK key is
  /// present (OCR then goes straight to Google with the user's key, so the
  /// backend tier is irrelevant). Otherwise use the backend tier, defaulting to
  /// Basic while usage is still loading.
  OcrTier get _effectiveTier {
    if (_hasKey) return OcrTier.flex;
    return _usage?.tier ?? OcrTier.basic;
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

  Future<void> _load() async {
    final has = await ref.read(ocrSettingsServiceProvider).hasApiKey();
    if (mounted) setState(() => _hasKey = has);
    await _loadUsage();
  }

  /// Fetch the backend usage/tier. Never throws — offline just leaves numbers
  /// unknown. BYOK users still fetch it so removing the key reveals their real
  /// backend tier (e.g. a paid subscriber who also set a key).
  Future<void> _loadUsage() async {
    if (mounted) setState(() => _loadingUsage = true);
    OcrUsage? usage;
    try {
      final res = await _functions
          .httpsCallable('getOcrUsage')
          .call()
          .timeout(const Duration(seconds: 8));
      usage = OcrUsage.fromMap(Map<String, dynamic>.from(res.data as Map));
    } catch (_) {
      usage = null; // offline / error → unknown
    }
    if (mounted) {
      setState(() {
        _usage = usage;
        _loadingUsage = false;
      });
    }
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
              _buildTierCard(theme, l10n),

              // ② Free-tier (Basic) 800 shared-pool rule — only for Basic users
              // without a BYOK key. Paid/VIP/Flex bypass the pool, so it would
              // only confuse them.
              if (_effectiveTier == OcrTier.basic) ...[
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
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
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
                initiallyExpanded: true,
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
  Widget _buildTierCard(ThemeData theme, AppLocalizations l10n) {
    final tier = _effectiveTier;
    final tierName = OcrTierDisplay.tierName(l10n, tier);
    final used = _usage?.tierUsed;
    final cap = _usage?.tierCap;

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
    } else if (_loadingUsage) {
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
          if (tier == OcrTier.basic || tier == OcrTier.plus) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _showSubscribeSheet,
                icon: const Icon(Icons.arrow_upward, size: 18),
                label: Text(tier == OcrTier.plus
                    ? l10n.ocrUpgradeToPro
                    : l10n.ocrSubscribe),
              ),
            ),
          ],

          // Admin-only observability: shared800 + total counters.
          if (_usage?.admin != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _buildAdminStats(theme, l10n, _usage!.admin!),
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
  /// The actual purchase is wired to RevenueCat later; for now the CTA shows a
  /// "coming soon" notice so the flow is visible without a live store product.
  Future<void> _showSubscribeSheet() async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
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
                _planTile(theme, l10n.ocrTierPlus, l10n.ocrPlanPlusPrice,
                    l10n.ocrPlanPlusDesc),
                const SizedBox(height: 10),
                _planTile(theme, l10n.ocrTierPro, l10n.ocrPlanProPrice,
                    l10n.ocrPlanProDesc),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    // TODO(revenuecat): launch RevenueCat purchase flow once
                    // store products + entitlements are live.
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.ocrSubscribeComingSoon)),
                    );
                  },
                  child: Text(l10n.ocrSubscribe),
                ),
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

  Widget _planTile(
      ThemeData theme, String name, String price, String desc) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
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
        ],
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
