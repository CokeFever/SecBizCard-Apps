import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:secbizcard/features/contacts/data/services/zip_import_service.dart';

class FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;

  @override
  Future<String?> getApplicationDocumentsPath() async =>
      Directory.systemTemp.path;
}

/// Minimal valid 1x1 JPEG so extracted files are real image bytes.
final _jpegBytes = <int>[
  0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, //
  0x00, 0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
  0xFF, 0xD9,
];

List<int> _buildZip(Map<String, dynamic> manifest, {bool addImages = true}) {
  final archive = Archive();
  final manifestBytes = utf8.encode(jsonEncode(manifest));
  archive.addFile(
    ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
  );
  if (addImages) {
    for (final name in ['images/0001_front.jpg', 'images/0001_back.jpg']) {
      archive.addFile(ArchiveFile(name, _jpegBytes.length, _jpegBytes));
    }
  }
  return ZipEncoder().encode(archive)!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PathProviderPlatform.instance = FakePathProviderPlatform();
  });

  test('parses contacts and maps fields correctly', () async {
    final zip = _buildZip({
      'version': 1,
      'source': 'test',
      'contacts': [
        {
          'name': 'Louis Lu',
          'company': 'Softmobile',
          'department': 'Marketing',
          'title': 'AVP',
          'email': 'louis@example.com',
          'phone': '+886287525527',
          'mobile': '+886920221660',
          'fax': '+886287525596',
          'website': 'www.example.com',
          'address': 'Taipei 114, Taiwan',
          'note': 'met at conf',
          'frontImage': 'images/0001_front.jpg',
          'backImage': 'images/0001_back.jpg',
        },
      ],
    });

    final result = await ZipImportService.parse(zip);

    expect(result.skipped, 0);
    expect(result.contacts, hasLength(1));
    final c = result.contacts.first;
    expect(c.displayName, 'Louis Lu');
    expect(c.company, 'Softmobile');
    expect(c.department, 'Marketing');
    expect(c.title, 'AVP');
    expect(c.email, 'louis@example.com');
    expect(c.phone, '+886287525527');
    expect(c.mobile, '+886920221660');
    expect(c.website, 'www.example.com');
    expect(c.address, 'Taipei 114, Taiwan');
    expect(c.customFields['fax'], '+886287525596');
    expect(c.customFields['note'], 'met at conf');
    expect(c.source, 'ocr');
    // Images extracted to real temp files.
    expect(c.cardFrontPath, isNotNull);
    expect(File(c.cardFrontPath!).existsSync(), isTrue);
    expect(c.cardBackPath, isNotNull);
    expect(File(c.cardBackPath!).existsSync(), isTrue);
  });

  test('skips rows with no identifying info', () async {
    final zip = _buildZip({
      'version': 1,
      'contacts': [
        {'note': 'nothing useful here'},
        {'name': 'Valid Person'},
      ],
    }, addImages: false);

    final result = await ZipImportService.parse(zip);
    expect(result.contacts, hasLength(1));
    expect(result.skipped, 1);
    expect(result.contacts.first.displayName, 'Valid Person');
  });

  test('tolerates a missing image reference (contact still imported)', () async {
    final zip = _buildZip({
      'version': 1,
      'contacts': [
        {'name': 'No Image', 'frontImage': 'images/does_not_exist.jpg'},
      ],
    }, addImages: false);

    final result = await ZipImportService.parse(zip);
    expect(result.contacts, hasLength(1));
    expect(result.contacts.first.cardFrontPath, isNull);
  });

  test('folds emails[] and phones[] into primary + custom fields', () async {
    final zip = _buildZip({
      'version': 1,
      'contacts': [
        {
          'name': 'Multi',
          'emails': ['a@x.com', 'b@x.com'],
          'phones': ['+111', '+222'],
        },
      ],
    }, addImages: false);

    final result = await ZipImportService.parse(zip);
    final c = result.contacts.first;
    expect(c.email, 'a@x.com');
    expect(c.customFields['altEmail'], contains('b@x.com'));
    expect(c.phone, '+111');
    expect(c.mobile, '+222');
  });

  test('rejects an unsupported (newer) manifest version', () async {
    final zip = _buildZip({'version': 99, 'contacts': []});
    expect(
      () => ZipImportService.parse(zip),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects a non-zip payload', () async {
    expect(
      () => ZipImportService.parse(utf8.encode('not a zip')),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects a zip with no manifest', () async {
    final archive = Archive();
    final bytes = utf8.encode('hi');
    archive.addFile(ArchiveFile('readme.txt', bytes.length, bytes));
    final zip = ZipEncoder().encode(archive)!;
    expect(
      () => ZipImportService.parse(zip),
      throwsA(isA<FormatException>()),
    );
  });

  // --- security / resource-limit guards ---

  test('rejects a manifest with a missing/non-int version', () async {
    final zip = _buildZip({'contacts': []}, addImages: false); // no version
    expect(
      () => ZipImportService.parse(zip),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects a package with too many contacts', () async {
    final many = List.generate(
      ZipImportService.maxContacts + 1,
      (i) => {'name': 'C$i'},
    );
    final zip = _buildZip({'version': 1, 'contacts': many}, addImages: false);
    expect(
      () => ZipImportService.parse(zip),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects an image path traversal attempt', () async {
    final zip = _buildZip({
      'version': 1,
      'contacts': [
        {'name': 'Evil', 'frontImage': '../../etc/passwd.jpg'},
      ],
    }, addImages: false);
    final result = await ZipImportService.parse(zip);
    expect(result.contacts, hasLength(1));
    // Traversal path is rejected -> no image attached, contact still imported.
    expect(result.contacts.first.cardFrontPath, isNull);
  });

  test('skips an oversized image but still imports the contact', () async {
    final archive = Archive();
    final manifest = {
      'version': 1,
      'contacts': [
        {'name': 'Big', 'frontImage': 'images/big.jpg'},
      ],
    };
    final mb = utf8.encode(jsonEncode(manifest));
    archive.addFile(ArchiveFile('manifest.json', mb.length, mb));
    // One byte over the per-image cap.
    final huge = List<int>.filled(ZipImportService.maxImageBytes + 1, 0x41);
    archive.addFile(ArchiveFile('images/big.jpg', huge.length, huge));
    final zip = ZipEncoder().encode(archive)!;

    final result = await ZipImportService.parse(zip);
    expect(result.contacts, hasLength(1));
    expect(result.contacts.first.cardFrontPath, isNull);
  });
}
