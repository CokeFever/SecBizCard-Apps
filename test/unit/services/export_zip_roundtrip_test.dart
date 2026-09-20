import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:secbizcard/features/contacts/data/services/contact_export_service.dart';
import 'package:secbizcard/features/contacts/data/services/zip_import_service.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';

import '../test_mocks.mocks.dart';

class FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;
  @override
  Future<String?> getApplicationDocumentsPath() async =>
      Directory.systemTemp.path;
}

/// Minimal valid 1x1 JPEG bytes.
final _jpeg = <int>[
  0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, //
  0x00, 0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
  0xFF, 0xD9,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late String frontPath;

  setUp(() async {
    PathProviderPlatform.instance = FakePathProviderPlatform();
    tmp = await Directory.systemTemp.createTemp('export_roundtrip_');
    frontPath = '${tmp.path}/card_front.jpg';
    await File(frontPath).writeAsBytes(_jpeg);
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('export -> import round-trip preserves fields and image', () async {
    final service = ContactExportService(MockContactsRepository());

    final profile = UserProfile(
      uid: 'u1',
      email: 'jane@example.com',
      displayName: 'Jane Doe',
      title: 'Manager',
      company: 'Example Inc.',
      department: 'Sales',
      phone: '+10000000000',
      mobile: '+10000000001',
      website: 'www.example.com',
      address: '123 Main St, City',
      customFields: const {'fax': '+10000000009', 'note': 'met at conf'},
      cardFrontPath: frontPath,
      source: 'ocr',
      createdAt: DateTime.now(),
    );

    // Export (pure, no share sheet / no filesystem output).
    final zipBytes = service.buildZipBytes([profile]);

    // Import back through the app's own parser.
    final result = await ZipImportService.parse(zipBytes);

    expect(result.skipped, 0);
    expect(result.contacts, hasLength(1));
    final c = result.contacts.first;
    expect(c.displayName, 'Jane Doe');
    expect(c.company, 'Example Inc.');
    expect(c.department, 'Sales');
    expect(c.title, 'Manager');
    expect(c.email, 'jane@example.com');
    expect(c.phone, '+10000000000');
    expect(c.mobile, '+10000000001');
    expect(c.website, 'www.example.com');
    expect(c.address, '123 Main St, City');
    expect(c.customFields['fax'], '+10000000009');
    expect(c.customFields['note'], 'met at conf');

    // The front image survived the round-trip as a real file.
    expect(c.cardFrontPath, isNotNull);
    expect(File(c.cardFrontPath!).existsSync(), isTrue);
    expect(await File(c.cardFrontPath!).readAsBytes(), _jpeg);
  });

  test('a contact with no local image exports text and imports cleanly',
      () async {
    final service = ContactExportService(MockContactsRepository());
    final profile = UserProfile(
      uid: 'u2',
      email: 'no-image@example.com',
      displayName: 'No Image',
      createdAt: DateTime.now(),
    );

    final zipBytes = service.buildZipBytes([profile]);
    final result = await ZipImportService.parse(zipBytes);

    expect(result.contacts, hasLength(1));
    expect(result.contacts.first.displayName, 'No Image');
    expect(result.contacts.first.cardFrontPath, isNull);
  });
}
