import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:secbizcard/features/profile/domain/user_profile.dart';

/// Result of parsing a `.zip` import package: the contacts that were built plus
/// how many entries were skipped (no usable data / broken rows), so the UI can
/// report an honest "imported X, skipped Y" summary.
class ZipImportResult {
  const ZipImportResult({required this.contacts, required this.skipped});
  final List<UserProfile> contacts;
  final int skipped;
}

/// Parses SecBizCard's `.zip` batch-import format (see docs/zip_import_format.md).
///
/// A package is a zip containing a root `manifest.json` (UTF-8) and an optional
/// `images/` folder. Each manifest contact carries structured text fields plus
/// optional image references (`frontImage` / `backImage` / `originalImage`)
/// pointing at files inside the zip.
///
/// This runs ENTIRELY on-device: image bytes are extracted to a temp dir and
/// the resulting [UserProfile]s point at those temp files. Persisting them via
/// the normal `saveContactLocally` path then copies the images into the app's
/// permanent storage (cardFront/Back -> profile/, original -> contacts/). No
/// data leaves the device.
class ZipImportService {
  static const _uuid = Uuid();

  /// Current supported manifest version. Packages declaring a newer major
  /// version are rejected rather than silently mis-parsed.
  static const int supportedVersion = 1;

  static const _imageExtensions = {'.jpg', '.jpeg', '.png', '.webp'};

  /// Parses [zipBytes] and returns the built contacts + skipped count.
  ///
  /// Throws [FormatException] when the package is structurally invalid (not a
  /// zip, missing/invalid manifest, unsupported version) so the caller can show
  /// a clear error. Individual bad contact rows are skipped, not fatal.
  static Future<ZipImportResult> parse(List<int> zipBytes) async {
    late final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } catch (e) {
      throw const FormatException('Not a valid .zip file.');
    }

    final manifestFile = _findFile(archive, 'manifest.json');
    if (manifestFile == null) {
      throw const FormatException('Package is missing manifest.json.');
    }

    Map<String, dynamic> manifest;
    try {
      manifest =
          jsonDecode(utf8.decode(manifestFile.content as List<int>))
              as Map<String, dynamic>;
    } catch (e) {
      throw const FormatException('manifest.json is not valid JSON.');
    }

    final version = manifest['version'];
    if (version is int && version > supportedVersion) {
      throw FormatException(
        'This package needs a newer app version (manifest version $version).',
      );
    }

    final rawContacts = manifest['contacts'];
    if (rawContacts is! List) {
      throw const FormatException('manifest.json has no "contacts" array.');
    }

    // Extract images into a unique temp dir so multiple imports don't collide.
    final tempRoot = await getTemporaryDirectory();
    final workDir = Directory(
      p.join(tempRoot.path, 'zip_import_${DateTime.now().millisecondsSinceEpoch}'),
    );
    await workDir.create(recursive: true);

    final contacts = <UserProfile>[];
    var skipped = 0;

    for (final entry in rawContacts) {
      if (entry is! Map) {
        skipped++;
        continue;
      }
      final map = Map<String, dynamic>.from(entry);
      final profile = await _buildContact(map, archive, workDir);
      if (profile == null) {
        skipped++;
      } else {
        contacts.add(profile);
      }
    }

    return ZipImportResult(contacts: contacts, skipped: skipped);
  }

  /// Builds one [UserProfile] from a manifest contact map, extracting any
  /// referenced images to [workDir]. Returns null when the row has no usable
  /// contact information.
  static Future<UserProfile?> _buildContact(
    Map<String, dynamic> map,
    Archive archive,
    Directory workDir,
  ) async {
    String? str(String key) {
      final v = map[key];
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    final name = str('name');
    final email = str('email') ?? _firstFromList(map['emails']);
    var phone = str('phone');
    var mobile = str('mobile');

    // Fold a generic `phones` list into the phone/mobile slots.
    final phonesList = _stringList(map['phones']);
    for (final ph in phonesList) {
      if (phone == null) {
        phone = ph;
      } else if (mobile == null && ph != phone) {
        mobile = ph;
      }
    }

    // A row with no identifying info at all is not worth importing.
    if (name == null && email == null && phone == null && mobile == null) {
      return null;
    }

    final customFields = <String, String>{};
    final fax = str('fax');
    if (fax != null) customFields['fax'] = fax;
    final note = str('note');
    if (note != null) customFields['note'] = note;
    // Preserve any extra emails beyond the primary.
    final extraEmails = _stringList(map['emails'])
        .where((e) => e != email)
        .toList();
    if (extraEmails.isNotEmpty) {
      customFields['altEmail'] = extraEmails.join(', ');
    }

    final frontPath =
        await _extractImage(str('frontImage'), archive, workDir);
    final backPath = await _extractImage(str('backImage'), archive, workDir);
    final originalPath =
        await _extractImage(str('originalImage'), archive, workDir);

    return UserProfile(
      uid: _uuid.v4(),
      email: email ?? '',
      displayName: name ?? email ?? 'Unknown',
      title: str('title'),
      company: str('company'),
      department: str('department'),
      phone: phone,
      mobile: mobile,
      website: str('website'),
      address: str('address'),
      customFields: customFields,
      cardFrontPath: frontPath,
      cardBackPath: backPath,
      originalImagePath: originalPath,
      source: 'ocr',
      createdAt: DateTime.now(),
    );
  }

  /// Extracts the zip entry at [ref] (a manifest-relative path) into [workDir]
  /// and returns the absolute temp path, or null if [ref] is empty, points at
  /// a non-image, or is not found in the archive.
  static Future<String?> _extractImage(
    String? ref,
    Archive archive,
    Directory workDir,
  ) async {
    if (ref == null || ref.isEmpty) return null;

    // Normalise and guard against path traversal (e.g. "../../etc").
    final normalized = p.normalize(ref).replaceAll('\\', '/');
    if (normalized.startsWith('..') || p.isAbsolute(normalized)) {
      if (kDebugMode) debugPrint('zip import: rejected image path "$ref"');
      return null;
    }

    final ext = p.extension(normalized).toLowerCase();
    if (!_imageExtensions.contains(ext)) return null;

    final file = _findFile(archive, normalized);
    if (file == null) {
      if (kDebugMode) debugPrint('zip import: image not found "$normalized"');
      return null;
    }

    // Flatten to a unique filename in workDir to avoid nested-dir surprises.
    final outName = '${_uuid.v4()}$ext';
    final outPath = p.join(workDir.path, outName);
    final outFile = File(outPath);
    await outFile.writeAsBytes(file.content as List<int>);
    return outPath;
  }

  /// Case-insensitive lookup that tolerates a leading "./" and either slash
  /// direction, since archives from different tools vary.
  static ArchiveFile? _findFile(Archive archive, String name) {
    final target = name.replaceAll('\\', '/').replaceFirst(RegExp(r'^\./'), '');
    for (final f in archive.files) {
      if (!f.isFile) continue;
      final n = f.name.replaceAll('\\', '/').replaceFirst(RegExp(r'^\./'), '');
      if (n == target) return f;
    }
    return null;
  }

  static String? _firstFromList(dynamic v) {
    final list = _stringList(v);
    return list.isEmpty ? null : list.first;
  }

  static List<String> _stringList(dynamic v) {
    if (v is! List) return const [];
    return v
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }
}
