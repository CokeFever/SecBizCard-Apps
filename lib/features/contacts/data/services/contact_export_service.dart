import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:secbizcard/features/contacts/data/contacts_repository.dart';
import 'package:secbizcard/features/contacts/data/services/vcard_service.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';

/// Result of a batch "Export to Google Contacts" run.
class GoogleExportResult {
  const GoogleExportResult({
    required this.succeeded,
    required this.failed,
    this.firstError,
  });

  final int succeeded;
  final int failed;
  final String? firstError;

  int get total => succeeded + failed;
  bool get allOk => failed == 0;
}

/// Shared implementation of the contact export/share actions, used by the
/// single-contact detail screen AND the multi-select list flow so both behave
/// identically (one source of truth for "Share as vCard" / "Export to Google").
class ContactExportService {
  const ContactExportService(this._contactsRepo);

  final ContactsRepository _contactsRepo;

  /// Writes [profiles] to a single `.vcf` file and opens the OS share sheet.
  ///
  /// A single contact keeps its photo; a batch omits photos so the combined
  /// file stays small enough to email/share. Returns nothing meaningful — the
  /// share sheet is fire-and-forget — but throws are surfaced to the caller.
  Future<void> shareAsVCard(List<UserProfile> profiles) async {
    if (profiles.isEmpty) return;

    final single = profiles.length == 1;
    final vcardString = single
        ? VCardService.generate(profiles.first) // keep photo for one card
        : VCardService.generateMultiple(profiles); // no photos in a batch

    final tempDir = await getTemporaryDirectory();
    final fileName = single
        ? '${_safeName(profiles.first.displayName)}.vcf'
        : 'contacts_${profiles.length}.vcf';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(vcardString);

    final subject = single
        ? 'Business Card: ${profiles.first.displayName}'
        : '${profiles.length} Business Cards';

    // ignore: deprecated_member_use
    await Share.shareXFiles([XFile(file.path)], subject: subject);
  }

  /// Exports [profiles] to Google Contacts one by one, tallying success/failure
  /// so the caller can report a partial result (e.g. "8 of 10 exported").
  ///
  /// [forceAccountSelection] forces the Google account chooser on the first
  /// call (subsequent calls reuse the chosen account).
  Future<GoogleExportResult> exportToGoogle(
    List<UserProfile> profiles, {
    bool forceAccountSelection = false,
  }) async {
    var succeeded = 0;
    var failed = 0;
    String? firstError;

    for (var i = 0; i < profiles.length; i++) {
      final result = await _contactsRepo.saveToGoogleContacts(
        profiles[i],
        // Only offer the account chooser once, on the first contact.
        forceAccountSelection: forceAccountSelection && i == 0,
      );
      result.fold(
        (l) {
          failed++;
          firstError ??= l.message;
        },
        (_) => succeeded++,
      );
    }

    return GoogleExportResult(
      succeeded: succeeded,
      failed: failed,
      firstError: firstError,
    );
  }

  String _safeName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'contact';
    return trimmed.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
  }
}
