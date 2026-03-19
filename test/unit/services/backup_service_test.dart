import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:secbizcard/core/services/backup_service.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
// import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:secbizcard/features/auth/data/auth_repository.dart';
import 'package:secbizcard/features/contacts/data/contacts_repository.dart';
import 'package:secbizcard/features/storage/data/drive_repository.dart';
import 'package:secbizcard/core/errors/failure.dart';
import '../test_mocks.mocks.dart';

// Helper for PathProvider mock
class FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async {
    return Directory.systemTemp.path;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.path;
  }
}

// Fake Drive Repository to bypass Mockito complexity with Generics/FP
class FakeDriveRepository implements DriveRepository {
  final Map<String, List<int>> _files = {};

  @override
  Future<Either<Failure, String?>> searchBackupFile(String fileName) async {
    // Return a fake ID if file exists in our map or if testing restore
    if (_files.containsKey(fileName)) {
      return right(fileName); // Use name as ID for simplicity
    }

    // Check if we pre-seeded a "found" state for specific test
    if (fileName == 'ixo_app_backup.zip' && _files.containsKey('backup_id')) {
      return right('backup_id');
    }

    return right(null);
  }

  @override
  Future<Either<Failure, bool>> checkBackupExists(String fileName) async {
    // Check local map or specific test triggers
    if (fileName == 'ixo_app_backup.zip' && _files.containsKey('backup_id')) {
      return right(true);
    }
    return right(false);
  }

  @override
  Future<Either<Failure, List<int>>> downloadFile(String fileId) async {
    if (_files.containsKey(fileId)) {
      return right(_files[fileId]!);
    }
    return left(const GeneralFailure('File not found'));
  }

  @override
  Future<Either<Failure, String>> uploadBackup(
    File file,
    String fileName, {
    String? existingFileId,
  }) async {
    final bytes = await file.readAsBytes();
    // Simulate upload by saving to map
    _files['new_file_id'] = bytes;
    _files[fileName] = bytes;

    return right('new_file_id');
  }

  // Stubs for other methods if needed
  @override
  Future<Either<Failure, void>> deleteFile(String fileId) async => right(null);

  @override
  String getFileUrl(String fileId) => 'http://fake.url/$fileId';

  @override
  Future<Either<Failure, String>> uploadImage(
    File imageFile,
    String fileName,
  ) async => right('img_id');
}

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockContactsRepository mockContactsRepo;
  late FakeDriveRepository fakeDriveRepo; // Changed to Fake
  late ProviderContainer container;

  setUp(() async {
    // Register dummies for Mockito
    provideDummy<Either<Failure, String?>>(right(null));
    provideDummy<Either<Failure, String>>(right('id'));
    provideDummy<Either<Failure, void>>(right(null));
    provideDummy<Either<Failure, List<UserProfile>>>(right([]));

    PathProviderPlatform.instance = FakePathProviderPlatform();

    PackageInfo.setMockInitialValues(
      appName: 'SecBizCard',
      packageName: 'com.secbizcard.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );

    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});

    mockAuthRepo = MockAuthRepository();
    mockContactsRepo = MockContactsRepository();
    fakeDriveRepo = FakeDriveRepository();

    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        contactsRepositoryProvider.overrideWithValue(mockContactsRepo),
        driveRepositoryProvider.overrideWithValue(fakeDriveRepo),
      ],
    );
  });

  group('BackupService Test', () {
    final testUser = MockUser();
    const uid = 'test_uid_12345';

    setUp(() {
      when(testUser.uid).thenReturn(uid);
      when(testUser.email).thenReturn('test@example.com');
      when(mockAuthRepo.getCurrentUser()).thenReturn(testUser);
    });

    test('backup() should create encrypted zip and upload', () async {
      // 1. Setup Data
      final contact = UserProfile(
        uid: 'c1',
        email: 'c1@test.com',
        displayName: 'Contact 1',
        phone: '123',
        createdAt: DateTime.now(),
      );

      when(
        mockContactsRepo.getSavedContacts(),
      ).thenAnswer((_) async => right([contact]));

      // 2. Action
      print('Starting backup action...');
      final service = container.read(backupServiceProvider);
      final result = await service.backup();
      print('Backup result: $result');

      // 3. Verify Success
      expect(
        result.isRight(),
        true,
        reason: result.fold((l) => l.message, (r) => ''),
      );

      // Verify Upload Happened in Fake
      expect(fakeDriveRepo._files.containsKey('new_file_id'), true);

      // 4. Verify Content (Encryption & Data)
      final bytes = fakeDriveRepo._files['new_file_id']!;

      // Attempt Decrypt
      final keyString = uid.padRight(32, '*').substring(0, 32);
      final key = encrypt.Key.fromUtf8(keyString);
      final iv = encrypt.IV(Uint8List.fromList(bytes.sublist(0, 16)));
      final encryptedBytes = bytes.sublist(16);

      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final decrypted = encrypter.decryptBytes(
        encrypt.Encrypted(Uint8List.fromList(encryptedBytes)),
        iv: iv,
      );

      // Unzip
      final archive = ZipDecoder().decodeBytes(decrypted);
      final dataFile = archive.findFile('data.json')!;
      final jsonContent = utf8.decode(dataFile.content);
      final data = jsonDecode(jsonContent);

      // Check Data
      expect(data['contacts'][0]['displayName'], 'Contact 1');
      expect(data['settings']['theme_mode'], 'dark');
    });

    test('restore() should decrypt, unzip and save data', () async {
      // 1. Create a valid encrypted backup file in memory
      final archive = Archive();
      final backupData = {
        'contacts': [
          {
            'uid': 'c2',
            'displayName': 'Restored Contact',
            'email': 'r@test.com',
            'customFields': {},
            'createdAt': DateTime.now().toIso8601String(),
          },
        ],
        'settings': {'theme_mode': 'light'},
      };
      final jsonBytes = utf8.encode(jsonEncode(backupData));
      archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));
      final zipBytes = ZipEncoder().encode(archive);

      final keyString = uid.padRight(32, '*').substring(0, 32);
      final key = encrypt.Key.fromUtf8(keyString);
      final iv = encrypt.IV.fromLength(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final encrypted = encrypter.encryptBytes(zipBytes, iv: iv);
      final fullBytes = iv.bytes + encrypted.bytes;

      // 2. Mock Drive via Fake
      // Seed the fake repo
      fakeDriveRepo._files['backup_id'] = fullBytes;

      when(
        mockContactsRepo.saveContactLocally(any),
      ).thenAnswer((_) async => right(null));
      when(
        mockContactsRepo.getSavedContacts(),
      ).thenAnswer((_) async => right([]));

      // 3. Action
      final service = container.read(backupServiceProvider);
      final result = await service.restore();

      // 4. Verify
      expect(result.isRight(), true);

      // Verify Contact Restoration
      verify(
        mockContactsRepo.saveContactLocally(
          argThat(
            predicate<UserProfile>((u) => u.displayName == 'Restored Contact'),
          ),
        ),
      ).called(1);

      // Verify Settings Restoration
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'light');
    });
  });
}
