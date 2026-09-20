import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
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

  /// Writes [profiles] to a single `.vcf` file (TEXT ONLY) and opens the OS
  /// share sheet.
  ///
  /// vCard here is deliberately text-only for both single and batch exports —
  /// card images travel via [shareAsZip] instead. This keeps `.vcf` files small
  /// and gives a clean split: `.vcf` = structured text, `.zip` = text + images.
  /// (Note: SecBizCard's own vCard importer ignores inline PHOTO anyway, so a
  /// base64 photo would only ever reach third-party address books.)
  ///
  /// Returns nothing meaningful — the share sheet is fire-and-forget — but
  /// throws are surfaced to the caller.
  Future<void> shareAsVCard(List<UserProfile> profiles) async {
    if (profiles.isEmpty) return;

    final single = profiles.length == 1;
    // includePhoto: false for a single card too, so behaviour is uniform.
    final vcardString = single
        ? VCardService.generate(profiles.first, includePhoto: false)
        : VCardService.generateMultiple(profiles);

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

  /// Writes [profiles] to a `.zip` package (structured text + card images) in
  /// SecBizCard's own import format (see docs/zip_import_format.md) and opens
  /// the OS share sheet.
  ///
  /// The package contains a root `manifest.json` (one entry per contact) plus an
  /// `images/` folder. Front image is taken from cardFrontPath, falling back to
  /// flatImagePath then originalImagePath; back image from cardBackPath. This is
  /// the export counterpart to the zip import, so a package produced here can be
  /// re-imported into SecBizCard with the card photos intact.
  Future<void> shareAsZip(List<UserProfile> profiles) async {
    if (profiles.isEmpty) return;

    final zipBytes = buildZipBytes(profiles);

    final single = profiles.length == 1;
    final tempDir = await getTemporaryDirectory();
    final fileName = single
        ? '${_safeName(profiles.first.displayName)}.zip'
        : 'contacts_${profiles.length}.zip';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(zipBytes);

    final subject = single
        ? 'Business Card: ${profiles.first.displayName}'
        : '${profiles.length} Business Cards';

    // ignore: deprecated_member_use
    await Share.shareXFiles([XFile(file.path)], subject: subject);
  }

  /// Builds the raw `.zip` bytes for [profiles] in SecBizCard's import format
  /// (manifest.json + images/). Pure and side-effect-free (no filesystem output,
  /// no share sheet) so it can be unit-tested and reused. Image bytes are read
  /// synchronously from each profile's local card-image paths.
  List<int> buildZipBytes(List<UserProfile> profiles) {
    final archive = Archive();
    final contacts = <Map<String, dynamic>>[];

    for (var i = 0; i < profiles.length; i++) {
      final pf = profiles[i];
      final entry = <String, dynamic>{};

      void put(String key, String? value) {
        final v = value?.trim();
        if (v != null && v.isNotEmpty) entry[key] = v;
      }

      put('name', pf.displayName);
      put('company', pf.company);
      put('department', pf.department);
      put('title', pf.title);
      put('email', pf.email);
      put('phone', pf.phone);
      put('mobile', pf.mobile);
      put('fax', pf.customFields['fax']);
      put('website', pf.website);
      put('address', pf.address);
      put('note', pf.customFields['note']);

      // Front image: prefer the flattened card, then the raw capture.
      final frontSource = _firstExistingImage([
        pf.cardFrontPath,
        pf.flatImagePath,
        pf.originalImagePath,
      ]);
      if (frontSource != null) {
        final zipName = 'images/${_seq(i)}_front${_ext(frontSource)}';
        if (_addImage(archive, zipName, frontSource)) {
          entry['frontImage'] = zipName;
        }
      }

      final backSource = _firstExistingImage([pf.cardBackPath]);
      if (backSource != null) {
        final zipName = 'images/${_seq(i)}_back${_ext(backSource)}';
        if (_addImage(archive, zipName, backSource)) {
          entry['backImage'] = zipName;
        }
      }

      contacts.add(entry);
    }

    final manifest = {
      'version': 1,
      'source': 'secbizcard',
      'contacts': contacts,
    };
    final manifestBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );

    return ZipEncoder().encode(archive);
  }

  // --- zip helpers ---------------------------------------------------------

  static String _seq(int i) => (i + 1).toString().padLeft(4, '0');

  static String _ext(String path) {
    final e = p.extension(path).toLowerCase();
    // Normalise to a safe, known image extension; default .jpg.
    const allowed = {'.jpg', '.jpeg', '.png', '.webp'};
    return allowed.contains(e) ? e : '.jpg';
  }

  /// Returns the first path in [candidates] that points at an existing file.
  String? _firstExistingImage(List<String?> candidates) {
    for (final c in candidates) {
      if (c == null || c.isEmpty) continue;
      if (c.startsWith('http')) continue; // remote avatar, not a local card
      if (File(c).existsSync()) return c;
    }
    return null;
  }

  /// Reads [sourcePath] and adds it to [archive] under [zipName]. Returns
  /// whether the file was added (false if the read failed).
  bool _addImage(Archive archive, String zipName, String sourcePath) {
    try {
      final bytes = File(sourcePath).readAsBytesSync();
      archive.addFile(ArchiveFile(zipName, bytes.length, bytes));
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('shareAsZip: skipped image $sourcePath: $e');
      return false;
    }
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
