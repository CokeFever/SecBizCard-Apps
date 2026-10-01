import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
import 'package:secbizcard/features/settings/data/magic_word_service.dart';
import 'package:secbizcard/features/storage/data/drive_repository.dart';
import 'package:secbizcard/core/errors/failure.dart';
import 'package:secbizcard/core/services/backup_codec.dart';
import '../test_mocks.mocks.dart';

/// In-memory [MagicWordService] so tests never touch flutter_secure_storage.
/// Overrides the public methods with a plain field.
class FakeMagicWordService extends MagicWordService {
  FakeMagicWordService() : super(const FlutterSecureStorage());
  String? _word;

  @override
  Future<String?> getMagicWord() async => _word;

  @override
  Future<void> setMagicWord(String value) async {
    final normalized = MagicWordService.normalize(value);
    if (normalized.length < MagicWordService.minLength ||
        normalized.length > MagicWordService.maxLength) {
      throw const MagicWordValidationFailure();
    }
    _word = normalized;
  }

  @override
  Future<void> clearMagicWord() async => _word = null;

  @override
  Future<bool> hasMagicWord() async => _word != null;
}

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

  // Fixed id handed back by ensureSecBizCardFolder()/fileExists().
  static const String folderId = 'secbizcard_folder_id';

  @override
  Future<Either<Failure, String>> ensureSecBizCardFolder() async =>
      right(folderId);

  @override
  Future<Either<Failure, bool>> fileExists(String fileId) async =>
      right(fileId == folderId);

  @override
  Future<Either<Failure, String?>> searchBackupFile(
    String fileName, {
    String? parentFolderId,
  }) async {
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
    String? parentFolderId,
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
  Future<Either<Failure, DateTime?>> getBackupModifiedTime(
    String fileName, {
    String? parentFolderId,
  }) async {
    // No cloud modified-time in this fake → null ("no cloud backup"), which
    // keeps the existing backup tests' behavior unchanged.
    return right(null);
  }

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
  late FakeMagicWordService fakeMagicWord;
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
    fakeMagicWord = FakeMagicWordService();

    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        contactsRepositoryProvider.overrideWithValue(mockContactsRepo),
        driveRepositoryProvider.overrideWithValue(fakeDriveRepo),
        magicWordServiceProvider.overrideWithValue(fakeMagicWord),
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

      // 4. Verify Content (Encryption & Data). No magic word set → the new
      // file is SBCB v2 encMode=uid.
      final bytes = fakeDriveRepo._files['new_file_id']!;
      expect(bytes.sublist(0, 4), BackupCodec.magic);

      final codec = BackupCodec();
      final header = codec.readHeaderOrNull(bytes);
      expect(header!.encMode, BackupCodec.encModeUid);

      final decrypted = await codec.decrypt(bytes, uid: uid);

      // Unzip
      final archive = ZipDecoder().decodeBytes(decrypted);
      final dataFile = archive.findFile('data.json')!;
      final jsonContent = utf8.decode(dataFile.content);
      final data = jsonDecode(jsonContent);

      // Check Data
      expect(data['contacts'][0]['displayName'], 'Contact 1');
      expect(data['settings']['theme_mode'], 'dark');
    });

    test('backup() with a magic word set writes magicword mode', () async {
      await fakeMagicWord.setMagicWord('correcthorse');
      when(
        mockContactsRepo.getSavedContacts(),
      ).thenAnswer((_) async => right([]));

      final service = container.read(backupServiceProvider);
      final result = await service.backup();
      expect(result.isRight(), true,
          reason: result.fold((l) => l.message, (r) => ''));

      final bytes = fakeDriveRepo._files['new_file_id']!;
      final codec = BackupCodec();
      final header = codec.readHeaderOrNull(bytes);
      expect(header!.encMode, BackupCodec.encModeMagicWord);

      // Only the magic word decrypts it; uid can no longer read it.
      final decrypted =
          await codec.decrypt(bytes, uid: uid, magicWord: 'correcthorse');
      expect(ZipDecoder().decodeBytes(decrypted).findFile('data.json'),
          isNotNull);
      expect(
        () => codec.decrypt(bytes, uid: uid, magicWord: 'wrongword123'),
        throwsA(isA<WrongMagicWordFailure>()),
      );
    });

    test('restore() should decrypt a LEGACY v1 file, unzip and save data',
        () async {
      // 1. Create a valid LEGACY (v1: IV(16)+CTR, uid-as-key) backup in memory.
      // This exercises the forever-supported legacy decrypt path.
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

    test('restore() of a magicword file requires the stored word', () async {
      // Build a magicword SBCB v2 file and seed it as the cloud backup.
      final zipArchive = Archive();
      final backupData = {
        'contacts': const <dynamic>[],
        'settings': {'theme_mode': 'dark'},
      };
      final jsonBytes = utf8.encode(jsonEncode(backupData));
      zipArchive.addFile(
          ArchiveFile('data.json', jsonBytes.length, jsonBytes));
      final zipBytes = ZipEncoder().encode(zipArchive);

      final codec = BackupCodec();
      final mwBytes = await codec.encryptNew(
        zipBytes,
        encMode: BackupCodec.encModeMagicWord,
        keySource: 'correcthorse',
      );
      fakeDriveRepo._files['backup_id'] = mwBytes;
      when(mockContactsRepo.getSavedContacts())
          .thenAnswer((_) async => right([]));

      final service = container.read(backupServiceProvider);

      // No local magic word → clean WrongMagicWordFailure, never a uid fallback.
      final noWord = await service.restore();
      expect(noWord.isLeft(), true);
      noWord.fold((l) => expect(l, isA<WrongMagicWordFailure>()),
          (_) => fail('should fail without the word'));

      // With the correct local word → restores.
      await fakeMagicWord.setMagicWord('correcthorse');
      final withWord = await service.restore();
      expect(withWord.isRight(), true,
          reason: withWord.fold((l) => l.message, (r) => ''));
    });

    test('setMagicWordAndRepack repacks a uid file into magicword mode',
        () async {
      // Seed an existing uid-mode SBCB v2 cloud file (what backup writes today).
      final zipArchive = Archive();
      final jsonBytes = utf8.encode(jsonEncode({
        'contacts': const <dynamic>[],
        'settings': {'theme_mode': 'dark'},
      }));
      zipArchive.addFile(
          ArchiveFile('data.json', jsonBytes.length, jsonBytes));
      final zipBytes = ZipEncoder().encode(zipArchive);

      final codec = BackupCodec();
      final uidBytes = await codec.encryptNew(
        zipBytes,
        encMode: BackupCodec.encModeUid,
        keySource: uid,
      );
      // searchBackupFile returns 'backup_id' when _files has that key; download
      // returns _files['backup_id'].
      fakeDriveRepo._files['backup_id'] = uidBytes;

      final service = container.read(backupServiceProvider);
      final result = await service.setMagicWordAndRepack('mysecretword');
      expect(result.isRight(), true,
          reason: result.fold((l) => l.message, (r) => ''));

      // The word is now stored, and the re-uploaded file is magicword mode.
      expect(await fakeMagicWord.getMagicWord(), 'mysecretword');
      final repacked = fakeDriveRepo._files['new_file_id']!;
      final header = codec.readHeaderOrNull(repacked);
      expect(header!.encMode, BackupCodec.encModeMagicWord);

      // Only the word decrypts the repacked file; uid can no longer read it.
      final out =
          await codec.decrypt(repacked, uid: uid, magicWord: 'mysecretword');
      expect(ZipDecoder().decodeBytes(out).findFile('data.json'), isNotNull);
      expect(
        () => codec.decrypt(repacked, uid: uid, magicWord: 'notitatall'),
        throwsA(isA<WrongMagicWordFailure>()),
      );
    });
  });
}
