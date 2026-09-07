import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:secbizcard/core/responsive/adaptive_container.dart';
import 'package:secbizcard/core/responsive/breakpoints.dart';
import 'package:secbizcard/features/settings/data/ocr_settings_service.dart';
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
              // Active engine summary
              _card(
                theme,
                child: Row(
                  children: [
                    Icon(
                      _hasKey ? Icons.verified : Icons.cloud_outlined,
                      color:
                          _hasKey ? Colors.green : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _hasKey
                                ? l10n.ocrUsingOwnKey
                                : l10n.ocrUsingSharedQuota,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _hasKey
                                ? l10n.ocrUsingOwnKeyDesc
                                : l10n.ocrUsingSharedQuotaDesc(
                                    OcrSettingsService.sharedPerUserMonthly),
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

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

              // BYO key input
              Text(
                _hasKey ? l10n.ocrUpdateOwnKeyHeading : l10n.ocrUseOwnKeyHeading,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
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
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save),
                      label: Text(_hasKey ? l10n.update : l10n.save),
                    ),
                  ),
                  if (_hasKey) ...[
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _remove,
                      icon: const Icon(Icons.delete_outline),
                      label: Text(l10n.remove),
                    ),
                  ],
                ],
              ),

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
