import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:secbizcard/core/responsive/adaptive_container.dart';
import 'package:secbizcard/core/responsive/breakpoints.dart';
import 'package:secbizcard/core/widgets/collapsible_section.dart';
import 'package:secbizcard/features/contacts/data/services/vcard_service.dart';
import 'package:secbizcard/features/contacts/data/services/zip_import_service.dart';
import 'package:secbizcard/features/contacts/data/contacts_repository.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';
import 'package:secbizcard/generated/l10n/app_localizations.dart';

/// Cheap structural precheck for the "Import from Text" enable gate (Task 4).
///
/// Returns true when [input] plausibly contains a vCard: non-empty after
/// trimming AND contains both `BEGIN:VCARD` and `END:VCARD` (case-insensitive).
/// This only greys/enables the button — the real parse/validation still runs
/// in full on tap via [VCardService.parse].
bool looksLikeVCard(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return false;
  final upper = trimmed.toUpperCase();
  return upper.contains('BEGIN:VCARD') && upper.contains('END:VCARD');
}

/// The prompt copied to the clipboard by the "Copy AI Prompt" button.
///
/// Intentionally hardcoded ENGLISH (it is fed to an LLM such as ChatGPT,
/// Gemini, or Grok, not shown as app UI, so it is NOT localized). It instructs
/// the AI to handle a photo that may contain 1 to 6 business cards, emit one
/// vCard 2.1 entry per card, and crop/straighten each card.
const String kVCardAiPrompt =
    'I have one or more photos of business cards. Each photo may contain 1 to 6 business cards. Please:\n'
    '1. Detect every business card in the photo(s) and extract all contact information for EACH card separately.\n'
    '2. For each card, create one vCard 2.1 (.vcf) entry. If there are multiple cards, concatenate the entries into a single block — one BEGIN:VCARD...END:VCARD block per card, back to back.\n'
    '3. Also crop and straighten each business card from the photo(s) and provide each as a clean, individual image.\n\n'
    'Finally, output the combined vCard text (all entries together) so I can copy it directly.';

class VCardImportScreen extends ConsumerStatefulWidget {
  const VCardImportScreen({super.key});

  @override
  ConsumerState<VCardImportScreen> createState() => _VCardImportScreenState();
}

class _VCardImportScreenState extends ConsumerState<VCardImportScreen> {
  final _textController = TextEditingController();
  bool _isImporting = false;
  // Drives the "Import from Text" button's enabled state (Task 4): true only
  // when the pasted text looks structurally like a vCard. Recomputed on every
  // keystroke in the paste field.
  bool _canImportText = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    // Accept both the public .vcf format and the advanced .zip package (a
    // manifest.json + cropped card images — see docs/zip_import_format.md).
    // We branch on extension so the zip path stays discoverable without being
    // advertised in the UI.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['vcf', 'zip'],
    );

    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    try {
      if (path.toLowerCase().endsWith('.zip')) {
        final bytes = await File(path).readAsBytes();
        await _processZipBytes(bytes);
      } else {
        final content = await File(path).readAsString();
        await _processVCardContent(content);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.vcardErrorReadingFile('$e'))),
        );
      }
    }
  }

  /// Handles a `.zip` batch-import package: parse (on-device) into contacts,
  /// preview, then persist through the same save path as vCard imports so
  /// images land in permanent storage automatically.
  Future<void> _processZipBytes(List<int> bytes) async {
    ZipImportResult result;
    try {
      result = await ZipImportService.parse(bytes);
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.vcardInvalidPackage(e.message))),
        );
      }
      return;
    }

    if (result.contacts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.vcardNoContactsInPackage)),
        );
      }
      return;
    }

    if (!mounted) return;
    final shouldImport = await _showPreviewDialog(result.contacts);
    if (shouldImport != true) return;

    await _saveContacts(
      result.contacts,
      skipped: result.skipped,
    );
  }

  void _importFromText() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.vcardPasteFirst)),
      );
      return;
    }
    _processVCardContent(text);
  }

  Future<void> _processVCardContent(String content) async {
    final contacts = VCardService.parse(content);

    if (contacts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.vcardNoContactsInContent)),
        );
      }
      return;
    }

    if (!mounted) return;

    final shouldImport = await _showPreviewDialog(contacts);
    if (shouldImport != true) return;

    await _saveContacts(contacts);
  }

  /// Persists the given contacts locally (shared by the vCard and zip paths)
  /// and shows an "imported X (skipped Y)" summary.
  Future<void> _saveContacts(
    List<UserProfile> contacts, {
    int skipped = 0,
  }) async {
    if (!mounted) return;
    setState(() => _isImporting = true);

    try {
      final contactsRepo = ref.read(contactsRepositoryProvider);
      int savedCount = 0;
      for (final contact in contacts) {
        final saveResult = await contactsRepo.saveContactLocally(contact);
        if (saveResult.isRight()) savedCount++;
      }

      ref.invalidate(savedContactsProvider);

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        final skippedNote = skipped > 0 ? l10n.vcardSkippedNote(skipped) : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.vcardImportedCount(savedCount, skippedNote)),
            action: SnackBarAction(
              label: l10n.vcardViewAction,
              onPressed: () => context.go('/home?tab=1'),
            ),
          ),
        );
        _textController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.vcardImportFailed('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<bool?> _showPreviewDialog(List<UserProfile> contacts) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.vcardPreviewTitle(contacts.length)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: contacts.length,
            itemBuilder: (_, index) {
              final c = contacts[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    c.displayName.isNotEmpty
                        ? c.displayName[0].toUpperCase()
                        : '?',
                  ),
                ),
                title: Text(c.displayName),
                subtitle: Text(
                  (c.email?.isNotEmpty == true)
                      ? c.email!
                      : (c.phone?.isNotEmpty == true
                          ? c.phone!
                          : l10n.vcardNoContactInfo),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.vcardImportAction),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.drawerImportVcard,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      // SafeArea(bottom) + a scrollable body whose bottom padding adds the
      // system inset so the "Import from Text" button always clears the Android
      // nav bar (Task 3).
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + MediaQuery.paddingOf(context).bottom,
          ),
          child: AdaptiveContainer(
            maxWidth: Breakpoints.maxContentWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // "How it works" — explanation + Copy-AI-Prompt + the two
                // numbered steps, in a collapsible section (collapsed by
                // default to keep the screen compact; tap to expand guidance).
                CollapsibleSection(
                  title: l10n.vcardHowItWorks,
                  icon: Icons.lightbulb_outline,
                  initiallyExpanded: false,
                  children: [
                    Text(
                      l10n.vcardHowItWorksDesc,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          Clipboard.setData(
                            const ClipboardData(text: kVCardAiPrompt),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.vcardPromptCopied),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 18),
                        label: Text(l10n.vcardCopyPrompt),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.vcardThen,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildStep(theme, '1', l10n.vcardStep1),
                    const SizedBox(height: 8),
                    _buildStep(theme, '2', l10n.vcardStep2),
                  ],
                ),

                const SizedBox(height: 12),

                // Option 1: File Upload
                CollapsibleSection(
                  title: l10n.vcardOption1,
                  icon: Icons.file_upload_outlined,
                  initiallyExpanded: true,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isImporting ? null : _pickFile,
                        icon: const Icon(Icons.file_upload),
                        label: Text(l10n.vcardChooseFile),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.primary,
                          side: BorderSide(color: theme.colorScheme.outline),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Option 2: Paste Text
                CollapsibleSection(
                  title: l10n.vcardOption2,
                  icon: Icons.content_paste,
                  initiallyExpanded: true,
                  children: [
                    TextField(
                      controller: _textController,
                      maxLines: 8,
                      onChanged: (value) {
                        final can = looksLikeVCard(value);
                        if (can != _canImportText) {
                          setState(() => _canImportText = can);
                        }
                      },
                      style: GoogleFonts.firaCode(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'BEGIN:VCARD\nVERSION:2.1\nN:Doe;John\nFN:John Doe\nORG:Company Inc.\nTITLE:Manager\nTEL:+1234567890\nEMAIL:john@example.com\nEND:VCARD',
                        hintStyle: GoogleFonts.firaCode(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.colorScheme.outline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: theme.colorScheme.outlineVariant),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: theme.colorScheme.primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        // Greyed out until the pasted text structurally looks
                        // like a vCard (Task 4). The real parse still fully
                        // validates on tap.
                        onPressed: (_isImporting || !_canImportText)
                            ? null
                            : _importFromText,
                        icon: _isImporting
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              )
                            : const Icon(Icons.download_done),
                        label: Text(_isImporting
                            ? l10n.vcardImporting
                            : l10n.vcardImportFromText),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(ThemeData theme, String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }
}
