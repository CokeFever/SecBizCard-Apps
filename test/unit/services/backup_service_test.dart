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
      when(
        mockContactsRepo.getSavedContacts(),
      ).thenAnswer((_) async => right([]));

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
      // ISSUE 1 regression: the ONLY existing file is a legacy ROOT file. The
      // repack must NOT update it in place (that left the file in root); it
      // must CREATE a new file INSIDE the SecBizCard folder and then
      // migrate-then-delete the root file.
      fakeDriveRepo.seedFile('root_backup_id', uidBytes, parentFolderId: null);

      final service = container.read(backupServiceProvider);
      final result = await service.setMagicWordAndRepack('mysecretword');
      expect(result.isRight(), true,
          reason: result.fold((l) => l.message, (r) => ''));

      // The word is now stored.
      expect(await fakeMagicWord.getMagicWord(), 'mysecretword');

      // The upload CREATED a new file inside the folder (existingFileId null,
      // parentFolderId set) — it did NOT update the root file in place.
      expect(fakeDriveRepo.lastUploadExistingFileId, isNull);
      expect(fakeDriveRepo.lastUploadParentFolderId,
          FakeDriveRepository.folderId);

      // The repacked file lives INSIDE the folder and is magicword mode.
      final newId = fakeDriveRepo.lastUploadResultId!;
      expect(
          fakeDriveRepo.hasFileWithParent(newId, FakeDriveRepository.folderId),
          true);
      final repacked = fakeDriveRepo.bytesOf(newId)!;
      final header = codec.readHeaderOrNull(repacked);
      expect(header!.encMode, BackupCodec.encModeMagicWord);

      // Migrate-then-delete removed the legacy root file (after the new-home
      // file read back OK).
      expect(fakeDriveRepo.deleted, contains('root_backup_id'));

      // Only the word decrypts the repacked file; uid can no longer read it.
      final out =
          await codec.decrypt(repacked, uid: uid, magicWord: 'mysecretword');
      expect(ZipDecoder().decodeBytes(out).findFile('data.json'), isNotNull);
      expect(
        () => codec.decrypt(repacked, uid: uid, magicWord: 'notitatall'),
        throwsA(isA<WrongMagicWordFailure>()),
      );
    });

    test(
        'setMagicWordAndRepack updates the IN-FOLDER file in place when one exists',
        () async {
      // An in-folder uid-mode file already exists → the repack should UPDATE it
      // in place (keeps the folder's share relationships), not create another.
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
      fakeDriveRepo.seedFile('folder_backup_id', uidBytes,
          parentFolderId: FakeDriveRepository.folderId);

      final service = container.read(backupServiceProvider);
      final result = await service.setMagicWordAndRepack('mysecretword');
      expect(result.isRight(), true,
          reason: result.fold((l) => l.message, (r) => ''));

      // Update-in-place on the existing in-folder file.
      expect(fakeDriveRepo.lastUploadExistingFileId, 'folder_backup_id');
      expect(fakeDriveRepo.lastUploadParentFolderId,
          FakeDriveRepository.folderId);
      final repacked = fakeDriveRepo.bytesOf('folder_backup_id')!;
      expect(codec.readHeaderOrNull(repacked)!.encMode,
          BackupCodec.encModeMagicWord);
    });

    test(
        'setMagicWordAndRepack with a root file keeps root until new home reads back',
        () async {
      // When upload of the new-home file fails, the legacy root file MUST NOT
      // be deleted (migrate-then-delete ordering).
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
      fakeDriveRepo.uploadShouldFail = true;

      final service = container.read(backupServiceProvider);
      final result = await service.setMagicWordAndRepack('mysecretword');

      expect(result.isLeft(), true);
      // Root file preserved; nothing deleted.
      expect(fakeDriveRepo.deleted, isEmpty);
      expect(
          fakeDriveRepo.hasFileWithParent('root_backup_id', null), true);
    });

    test(
        'setMagicWordAndRepack writes an initial magicword backup when no cloud file exists',
        () async {
      // No cloud backup is seeded, so searchBackupFile returns null (fileId ==
      // null). The method should still create a magicword-mode cloud file by
      // running an immediate backup.
      when(
        mockContactsRepo.getSavedContacts(),
      ).thenAnswer((_) async => right(<UserProfile>[]));

      final service = container.read(backupServiceProvider);
      final result = await service.setMagicWordAndRepack('mysecretword');
      expect(result.isRight(), true,
          reason: result.fold((l) => l.message, (r) => ''));

      // The word is stored and a brand-new cloud file was written INSIDE the
      // SecBizCard folder (create-in-folder, no pre-existing file anywhere).
      expect(await fakeMagicWord.getMagicWord(), 'mysecretword');
      expect(fakeDriveRepo.lastUploadExistingFileId, isNull);
      expect(fakeDriveRepo.lastUploadParentFolderId,
          FakeDriveRepository.folderId);
      final writtenId = fakeDriveRepo.lastUploadResultId!;
      expect(
          fakeDriveRepo.hasFileWithParent(
              writtenId, FakeDriveRepository.folderId),
          true);

      // The freshly written file is SBCB v2 magicword mode and only the word
      // can decrypt it.
      final codec = BackupCodec();
      final written = fakeDriveRepo.bytesOf(writtenId)!;
      expect(written.sublist(0, 4), BackupCodec.magic);
      final header = codec.readHeaderOrNull(written);
      expect(header!.encMode, BackupCodec.encModeMagicWord);
      final out =
          await codec.decrypt(written, uid: uid, magicWord: 'mysecretword');
      expect(ZipDecoder().decodeBytes(out).findFile('data.json'), isNotNull);
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
