import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:secbizcard/core/responsive/adaptive_container.dart';
import 'package:secbizcard/core/responsive/breakpoints.dart';
import 'package:secbizcard/features/contacts/data/services/vcard_service.dart';
import 'package:secbizcard/features/contacts/data/services/zip_import_service.dart';
import 'package:secbizcard/features/contacts/data/contacts_repository.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';
import 'package:secbizcard/generated/l10n/app_localizations.dart';

class VCardImportScreen extends ConsumerStatefulWidget {
  const VCardImportScreen({super.key});

  @override
  ConsumerState<VCardImportScreen> createState() => _VCardImportScreenState();
}

class _VCardImportScreenState extends ConsumerState<VCardImportScreen> {
  final _textController = TextEditingController();
  bool _isImporting = false;

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: AdaptiveContainer(
          maxWidth: Breakpoints.maxContentWidth,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Explanation Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.vcardHowItWorks,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                        Clipboard.setData(const ClipboardData(
                          text: 'I have a photo of a business card. Please:\n'
                              '1. Extract all contact information from the card.\n'
                              '2. Format the result as vCard 2.1 (.vcf) format.\n'
                              '3. Also crop and straighten the business card area from the photo and provide it as a clean image.\n\n'
                              'Please output the vCard text so I can copy it directly.',
                        ));
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
            ),

            const SizedBox(height: 32),

            // Option 1: File Upload
            Text(
              l10n.vcardOption1,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isImporting ? null : _pickFile,
                icon: const Icon(Icons.file_download),
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

            const SizedBox(height: 32),

            // Divider with "OR"
            Row(
              children: [
                Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    l10n.vcardOr,
                    style: GoogleFonts.inter(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
              ],
            ),

            const SizedBox(height: 32),

            // Option 2: Paste Text
            Text(
              l10n.vcardOption2,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              maxLines: 8,
              style: GoogleFonts.firaCode(
                fontSize: 12,
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'BEGIN:VCARD\nVERSION:2.1\nN:Doe;John\nFN:John Doe\nORG:Company Inc.\nTITLE:Manager\nTEL:+1234567890\nEMAIL:john@example.com\nEND:VCARD',
                hintStyle: GoogleFonts.firaCode(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isImporting ? null : _importFromText,
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
                label: Text(_isImporting ? l10n.vcardImporting : l10n.vcardImportFromText),
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
