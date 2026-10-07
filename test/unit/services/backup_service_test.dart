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
import 'package:secbizcard/core/services/backup_reminder_service.dart';
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

// Fake Drive Repository to bypass Mockito complexity with Generics/FP.
//
// This fake models Drive location faithfully enough to catch the ROOT-vs-folder
// bug: files are keyed by id and each id has a parent (null = My Drive root,
// [folderId] = the SecBizCard folder). `searchBackupFile` honors
// `parentFolderId`, and `uploadBackup` records what it was called with and
// places the resulting file under the parent it was told to use (an
// update-in-place keeps the existing file's parent; a create uses
// `parentFolderId`). This is what lets a test assert "the repack created a file
// INSIDE the folder" vs "updated the root file in place".
class FakeDriveRepository implements DriveRepository {
  // id -> bytes
  final Map<String, List<int>> _files = {};
  // id -> parentFolderId (null means My Drive root)
  final Map<String, String?> _parents = {};
  final List<String> deleted = [];

  // Records of the last uploadBackup call, for assertions.
  String? lastUploadExistingFileId;
  String? lastUploadParentFolderId;
  String? lastUploadResultId;
  int uploadCount = 0;
  int _createdCounter = 0;
  bool uploadShouldFail = false;

  /// Settable server-side modifiedTime returned by [getBackupModifiedTime].
  /// Defaults to null ("no cloud backup") to keep existing tests unchanged.
  DateTime? backupModifiedTime;

  // Fixed id handed back by ensureSecBizCardFolder()/fileExists().
  static const String folderId = 'secbizcard_folder_id';
  static const String backupFileName = 'ixo_app_backup.zip';

  /// Test helper: seed a backup file at a given location.
  void seedFile(String id, List<int> bytes, {String? parentFolderId}) {
    _files[id] = bytes;
    _parents[id] = parentFolderId;
  }

  bool hasFileWithParent(String id, String? parentFolderId) =>
      _files.containsKey(id) && _parents[id] == parentFolderId;

  List<int>? bytesOf(String id) => _files[id];

  @override
  Future<Either<Failure, String>> ensureSecBizCardFolder() async =>
      right(folderId);

  @override
  Future<Either<Failure, bool>> fileExists(String fileId) async =>
      right(fileId == folderId || _files.containsKey(fileId));

  @override
  Future<Either<Failure, String?>> searchBackupFile(
    String fileName, {
    String? parentFolderId,
    bool rootOnly = false,
  }) async {
    if (fileName != backupFileName) return right(null);
    for (final entry in _files.keys) {
      final parent = _parents[entry];
      final bool matches;
      if (parentFolderId != null) {
        // Constrained to a specific folder.
        matches = parent == parentFolderId;
      } else if (rootOnly) {
        // Legacy-root lookup: ONLY a file that actually lives in root (null
        // parent) matches. An in-folder file must never be seen as "root".
        matches = parent == null;
      } else {
        // "Search anywhere": real Drive matches a file in ANY parent, so the
        // fake must too. (The old fake modeled this as root-only, which hid
        // the self-delete bug.)
        matches = true;
      }
      if (matches) return right(entry);
    }
    return right(null);
  }

  @override
  Future<Either<Failure, String?>> searchRootBackupFile(String fileName) =>
      searchBackupFile(fileName, rootOnly: true);

  @override
  Future<Either<Failure, bool>> checkBackupExists(String fileName) async {
    final r = await searchBackupFile(fileName);
    return r.map((id) => id != null);
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
    uploadCount++;
    lastUploadExistingFileId = existingFileId;
    lastUploadParentFolderId = parentFolderId;
    if (uploadShouldFail) {
      return left(const ServerFailure('upload failed'));
    }

    if (existingFileId != null) {
      // Update-in-place: keep the file where it already lives UNLESS a
      // parentFolderId was supplied and differs, in which case relocate it
      // (mirrors the addParents/removeParents defense-in-depth in the repo).
      _files[existingFileId] = bytes;
      if (parentFolderId != null) {
        _parents[existingFileId] = parentFolderId;
      }
      lastUploadResultId = existingFileId;
      return right(existingFileId);
    }
    // Create a new file under the requested parent (root when null).
    final newId = 'created_${_createdCounter++}';
    _files[newId] = bytes;
    _parents[newId] = parentFolderId;
    lastUploadResultId = newId;
    return right(newId);
  }

  @override
  Future<Either<Failure, void>> deleteFile(String fileId) async {
    deleted.add(fileId);
    _files.remove(fileId);
    _parents.remove(fileId);
    return right(null);
  }

  @override
  Future<Either<Failure, DateTime?>> getBackupModifiedTime(
    String fileName, {
    String? parentFolderId,
  }) async {
    // Returns the settable [backupModifiedTime]; null by default ("no cloud
    // backup"), which keeps the existing backup tests' behavior unchanged.
    return right(backupModifiedTime);
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

      // Verify Upload Happened in Fake, as a CREATE inside the SecBizCard
      // folder (no pre-existing file).
      expect(fakeDriveRepo.uploadCount, 1);
      expect(fakeDriveRepo.lastUploadExistingFileId, isNull);
      expect(fakeDriveRepo.lastUploadParentFolderId,
          FakeDriveRepository.folderId);
      final uploadedId = fakeDriveRepo.lastUploadResultId!;

      // 4. Verify Content (Encryption & Data). No magic word set → the new
      // file is SBCB v2 encMode=uid.
      final bytes = fakeDriveRepo.bytesOf(uploadedId)!;
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
      // Seed one contact so the new empty-data guard does not abort the backup.
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

      final service = container.read(backupServiceProvider);
      final result = await service.backup();
      expect(result.isRight(), true,
          reason: result.fold((l) => l.message, (r) => ''));

      final bytes = fakeDriveRepo.bytesOf(fakeDriveRepo.lastUploadResultId!)!;
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

      // 2. Mock Drive via Fake — seed a LEGACY file in Drive ROOT.
      fakeDriveRepo.seedFile('backup_id', fullBytes, parentFolderId: null);

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
      fakeDriveRepo.seedFile('backup_id', mwBytes, parentFolderId: null);
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

    test('setMagicWord stores the word and performs NO Drive operation',
        () async {
      // Seed an existing uid-mode cloud file so we can prove setMagicWord does
      // NOT touch it (no download/upload/delete/repack).
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
      fakeDriveRepo.seedFile('root_backup_id', uidBytes, parentFolderId: null);

      final service = container.read(backupServiceProvider);
      final result = await service.setMagicWord('mysecretword');

      expect(result.isRight(), true,
          reason: result.fold((l) => l.message, (r) => ''));
      // The word is stored locally.
      expect(await fakeMagicWord.getMagicWord(), 'mysecretword');
      // D1: zero Drive operations — nothing uploaded, nothing deleted.
      expect(fakeDriveRepo.uploadCount, 0);
      expect(fakeDriveRepo.deleted, isEmpty);
      // The seeded cloud file is untouched (still uid mode).
      final existing = fakeDriveRepo.bytesOf('root_backup_id')!;
      expect(codec.readHeaderOrNull(existing)!.encMode,
          BackupCodec.encModeUid);
    });

    test('setMagicWord rejects an invalid word', () async {
      final service = container.read(backupServiceProvider);
      final result = await service.setMagicWord('short'); // < 8 chars

      expect(result.isLeft(), true);
      result.fold((l) => expect(l, isA<MagicWordValidationFailure>()),
          (_) => fail('a too-short word must be rejected'));
      // Nothing stored.
      expect(await fakeMagicWord.getMagicWord(), isNull);
      // And still no Drive activity.
      expect(fakeDriveRepo.uploadCount, 0);
    });

    test('backup() aborts with EmptyBackupFailure when contacts are empty',
        () async {
      when(mockContactsRepo.getSavedContacts())
          .thenAnswer((_) async => right(<UserProfile>[]));

      final service = container.read(backupServiceProvider);
      final result = await service.backup();

      expect(result.isLeft(), true);
      result.fold((l) => expect(l, isA<EmptyBackupFailure>()),
          (_) => fail('empty contacts must abort the backup'));
      expect(fakeDriveRepo.uploadCount, 0);
    });

    test('backup(force: true) still aborts on empty contacts (force cannot '
        'bypass)', () async {
      when(mockContactsRepo.getSavedContacts())
          .thenAnswer((_) async => right(<UserProfile>[]));

      final service = container.read(backupServiceProvider);
      final result = await service.backup(force: true);

      expect(result.isLeft(), true);
      result.fold((l) => expect(l, isA<EmptyBackupFailure>()),
          (_) => fail('force must NOT bypass the empty-data guard'));
      expect(fakeDriveRepo.uploadCount, 0);
    });

    test('backup(allowEmpty: true) uploads even when contacts are empty',
        () async {
      when(mockContactsRepo.getSavedContacts())
          .thenAnswer((_) async => right(<UserProfile>[]));

      final service = container.read(backupServiceProvider);
      final result = await service.backup(allowEmpty: true);

      expect(result.isRight(), true,
          reason: result.fold((l) => l.message, (r) => ''));
      expect(fakeDriveRepo.uploadCount, 1);
    });

    test('restore(overrideMagicWord:) decrypts without persisting', () async {
      // Seed a magicword cloud file keyed by 'correcthorse'.
      final zipArchive = Archive();
      final jsonBytes = utf8.encode(jsonEncode({
        'contacts': const <dynamic>[],
        'settings': {'theme_mode': 'dark'},
      }));
      zipArchive.addFile(
          ArchiveFile('data.json', jsonBytes.length, jsonBytes));
      final zipBytes = ZipEncoder().encode(zipArchive);
      final codec = BackupCodec();
      final mwBytes = await codec.encryptNew(
        zipBytes,
        encMode: BackupCodec.encModeMagicWord,
        keySource: 'correcthorse',
      );
      fakeDriveRepo.seedFile('backup_id', mwBytes, parentFolderId: null);
      when(mockContactsRepo.getSavedContacts())
          .thenAnswer((_) async => right([]));

      final service = container.read(backupServiceProvider);
      // No stored word; the override alone must unlock the restore.
      final result = await service.restore(overrideMagicWord: 'correcthorse');

      expect(result.isRight(), true,
          reason: result.fold((l) => l.message, (r) => ''));
      // Override must NOT be persisted.
      expect(await fakeMagicWord.getMagicWord(), isNull);
    });

    test('restore(overrideMagicWord: wrong) surfaces WrongMagicWordFailure',
        () async {
      final zipArchive = Archive();
      final jsonBytes = utf8.encode(jsonEncode({
        'contacts': const <dynamic>[],
        'settings': {'theme_mode': 'dark'},
      }));
      zipArchive.addFile(
          ArchiveFile('data.json', jsonBytes.length, jsonBytes));
      final zipBytes = ZipEncoder().encode(zipArchive);
      final codec = BackupCodec();
      final mwBytes = await codec.encryptNew(
        zipBytes,
        encMode: BackupCodec.encModeMagicWord,
        keySource: 'correcthorse',
      );
      fakeDriveRepo.seedFile('backup_id', mwBytes, parentFolderId: null);

      final service = container.read(backupServiceProvider);
      final result = await service.restore(overrideMagicWord: 'wrongword123');

      expect(result.isLeft(), true);
      result.fold((l) => expect(l, isA<WrongMagicWordFailure>()),
          (_) => fail('a wrong override must fail'));
      // Still nothing persisted.
      expect(await fakeMagicWord.getMagicWord(), isNull);
    });

    test('cloudBackupModifiedTime returns the drive modifiedTime', () async {
      final when = DateTime.utc(2026, 1, 2, 3, 4, 5);
      fakeDriveRepo.backupModifiedTime = when;

      final service = container.read(backupServiceProvider);
      final t = await service.cloudBackupModifiedTime();

      expect(t, when);
    });

    test('cloudIsMagicWordProtected true for a magicword file', () async {
      final zipArchive = Archive();
      final jsonBytes = utf8.encode(jsonEncode({
        'contacts': const <dynamic>[],
        'settings': {'theme_mode': 'dark'},
      }));
      zipArchive.addFile(
          ArchiveFile('data.json', jsonBytes.length, jsonBytes));
      final zipBytes = ZipEncoder().encode(zipArchive);
      final codec = BackupCodec();
      final mwBytes = await codec.encryptNew(
        zipBytes,
        encMode: BackupCodec.encModeMagicWord,
        keySource: 'correcthorse',
      );
      fakeDriveRepo.seedFile('backup_id', mwBytes, parentFolderId: null);

      final service = container.read(backupServiceProvider);
      expect(await service.cloudIsMagicWordProtected(), true);
    });

    test('cloudIsMagicWordProtected false for a uid file', () async {
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
      fakeDriveRepo.seedFile('backup_id', uidBytes, parentFolderId: null);

      final service = container.read(backupServiceProvider);
      expect(await service.cloudIsMagicWordProtected(), false);
    });

    test('cloudIsMagicWordProtected false when no cloud file exists', () async {
      final service = container.read(backupServiceProvider);
      expect(await service.cloudIsMagicWordProtected(), false);
    });

    // FIX 1 — conflict guard compares cloud modifiedTime against THIS device's
    // last successful backup (keyLastBackup), not the local data-change time.
    // Seeds keyLastBackup via SharedPreferences and drives cloudTime via the
    // fake's settable backupModifiedTime.
    group('backup() conflict guard (last-backup based)', () {
      final contact = UserProfile(
        uid: 'c1',
        email: 'c1@test.com',
        displayName: 'Contact 1',
        phone: '123',
        createdAt: DateTime.now(),
      );

      void seedOneContact() {
        when(mockContactsRepo.getSavedContacts())
            .thenAnswer((_) async => right([contact]));
      }

      // Re-seed SharedPreferences with the base theme AND a last-backup
      // timestamp, then rebuild the container so BackupService reads the
      // seeded prefs. (BackupReminderService() uses the shared singleton.)
      Future<void> seedLastBackup(DateTime? t) async {
        SharedPreferences.setMockInitialValues({
          'theme_mode': 'dark',
          if (t != null)
            BackupReminderService.keyLastBackup: t.millisecondsSinceEpoch,
        });
        container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
            contactsRepositoryProvider.overrideWithValue(mockContactsRepo),
            driveRepositoryProvider.overrideWithValue(fakeDriveRepo),
            magicWordServiceProvider.overrideWithValue(fakeMagicWord),
          ],
        );
      }

      test('(a) same-device re-backup, no data change (cloudTime ≈ '
          'lastBackup) → NO conflict, uploads', () async {
        final t = DateTime.utc(2026, 10, 7, 12, 0, 0);
        await seedLastBackup(t);
        // Cloud file is this device's own backup; its server time is a few
        // seconds after our local markBackedUp stamp — within skew.
        fakeDriveRepo.backupModifiedTime = t.add(const Duration(seconds: 5));
        seedOneContact();

        final service = container.read(backupServiceProvider);
        final result = await service.backup();

        expect(result.isRight(), true,
            reason: result.fold((l) => l.message, (r) => ''));
        expect(fakeDriveRepo.uploadCount, 1);
      });

      test('(b) another device wrote cloud AFTER our last backup → conflict, '
          'no upload', () async {
        final t = DateTime.utc(2026, 10, 7, 12, 0, 0);
        await seedLastBackup(t);
        fakeDriveRepo.backupModifiedTime = t.add(const Duration(minutes: 10));
        seedOneContact();

        final service = container.read(backupServiceProvider);
        final result = await service.backup();

        expect(result.isLeft(), true);
        result.fold((l) => expect(l, isA<BackupConflictFailure>()),
            (_) => fail('a newer other-device backup must conflict'));
        expect(fakeDriveRepo.uploadCount, 0);
      });

      test('(c) fresh device, never backed up, cloud exists → conflict',
          () async {
        await seedLastBackup(null); // no keyLastBackup
        fakeDriveRepo.backupModifiedTime = DateTime.utc(2026, 10, 7, 12, 0, 0);
        seedOneContact();

        final service = container.read(backupServiceProvider);
        final result = await service.backup();

        expect(result.isLeft(), true);
        result.fold((l) => expect(l, isA<BackupConflictFailure>()),
            (_) => fail('first-run-on-new-device with a cloud file must '
                'conflict'));
        expect(fakeDriveRepo.uploadCount, 0);
      });

      test('(d) force: true bypasses the conflict guard, uploads', () async {
        final t = DateTime.utc(2026, 10, 7, 12, 0, 0);
        await seedLastBackup(t);
        fakeDriveRepo.backupModifiedTime = t.add(const Duration(minutes: 10));
        seedOneContact();

        final service = container.read(backupServiceProvider);
        final result = await service.backup(force: true);

        expect(result.isRight(), true,
            reason: result.fold((l) => l.message, (r) => ''));
        expect(fakeDriveRepo.uploadCount, 1);
      });
    });

    // ISSUE 1 (+182) regression — brand-new account self-delete.
    //
    // Repro of the TestFlight report: a brand-new account (NO cloud file
    // anywhere) runs its first backup. The success toast fired but the
    // SecBizCard folder ended up empty, so the next restore failed. Root cause:
    // the migrate step's "find legacy ROOT file" used an unscoped
    // searchBackupFile, which matched the file JUST created inside the folder
    // and then deleted it.
    //
    // This test MUST fail against the pre-fix source (the in-folder file is
    // deleted / restore fails) and pass after (root-scoped search +
    // rootId==newHomeId guard). It depends on the fakes modeling a no-parent,
    // non-rootOnly search as "match any parent" (real-Drive semantics).
    test('backup() on a brand-new account does NOT self-delete the new file',
        () async {
      // Brand-new account: seed NOTHING in Drive.
      final contact = UserProfile(
        uid: 'c1',
        email: 'c1@test.com',
        displayName: 'New Account Contact',
        phone: '123',
        createdAt: DateTime.now(),
      );
      when(mockContactsRepo.getSavedContacts())
          .thenAnswer((_) async => right([contact]));
      when(mockContactsRepo.saveContactLocally(any))
          .thenAnswer((_) async => right(null));

      final service = container.read(backupServiceProvider);

      // First backup of a fresh account.
      final result = await service.backup(force: true);
      expect(result.isRight(), true,
          reason: result.fold((l) => l.message, (r) => ''));

      // The file was CREATED inside the SecBizCard folder.
      expect(fakeDriveRepo.lastUploadExistingFileId, isNull);
      expect(fakeDriveRepo.lastUploadParentFolderId,
          FakeDriveRepository.folderId);
      final createdId = fakeDriveRepo.lastUploadResultId!;

      // (a) The in-folder file STILL EXISTS (was not self-deleted by migrate).
      expect(
        fakeDriveRepo.hasFileWithParent(
            createdId, FakeDriveRepository.folderId),
        true,
        reason: 'the just-created in-folder backup must survive the migrate '
            'step; +182 deleted it',
      );
      // (b) Nothing was deleted (there was no legacy root file to migrate).
      expect(fakeDriveRepo.deleted, isEmpty);

      // (c) A subsequent restore finds the file and succeeds.
      final restored = await service.restore();
      expect(restored.isRight(), true,
          reason: restored.fold((l) => l.message, (r) => ''));
      verify(
        mockContactsRepo.saveContactLocally(
          argThat(predicate<UserProfile>(
              (u) => u.displayName == 'New Account Contact')),
        ),
      ).called(1);
    });
  });
}
