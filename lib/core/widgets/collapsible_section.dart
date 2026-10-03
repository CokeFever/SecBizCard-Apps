import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shared collapsible-section building blocks used by the settings-style
/// screens (AI Recognition, Import vCard, Backup & Restore) so they present
/// content consistently.
///
/// These are a 1:1 extraction of the inline helpers that originally lived in
/// `ocr_settings_screen.dart` (`_expandable`, `_card`, `_StepText`); the visual
/// treatment is identical, so screens that adopt them render the same as the
/// AI Recognition template.

/// A borderless [ExpansionTile] with a compact title and left-aligned body,
/// matching the AI Recognition "How-to" / "Safety" sections. When
/// [actionLabel] and [actionUrl] are both provided, an "open in new" link is
/// appended below the children. [icon] is optional and, when null, the title
/// renders exactly as the original (no leading glyph).
class CollapsibleSection extends StatelessWidget {
  const CollapsibleSection({
    super.key,
    required this.title,
    required this.children,
    this.actionLabel,
    this.actionUrl,
    this.initiallyExpanded = false,
    this.icon,
  });

  final String title;
  final List<Widget> children;
  final String? actionLabel;
  final String? actionUrl;
  final bool initiallyExpanded;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleText = Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    );
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        initiallyExpanded: initiallyExpanded,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        expandedAlignment: Alignment.centerLeft,
        title: icon == null
            ? titleText
            : Row(
                children: [
                  Icon(icon, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(child: titleText),
                ],
              ),
        children: [
          ...children,
          if (actionLabel != null && actionUrl != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(actionUrl!),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A soft, outlined box used for always-visible cards (the AI Recognition tier
/// card, the Backup status card, the Magic Word section). Default padding is
/// `EdgeInsets.all(16)`.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}

/// A single body line inside a [CollapsibleSection] (13px, muted colour,
/// 1.4 line height), matching the AI Recognition step/safety copy.
class SectionStepText extends StatelessWidget {
  const SectionStepText(this.text, {super.key});

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
