import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mockito/mockito.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:secbizcard/core/errors/failure.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:secbizcard/core/services/backup_service.dart';
import 'package:secbizcard/features/auth/data/auth_repository.dart';
import 'package:secbizcard/features/contacts/data/contacts_repository.dart';
import 'package:secbizcard/features/profile/data/profile_repository.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';
import 'package:secbizcard/features/settings/data/magic_word_service.dart';
import 'package:secbizcard/features/storage/data/drive_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_mocks.mocks.dart';

/// In-memory MagicWordService so these migration tests never touch
/// flutter_secure_storage. Defaults to "no magic word" (uid mode), matching the
/// legacy backups these tests fabricate.
class _NoMagicWordService extends MagicWordService {
  _NoMagicWordService() : super(const FlutterSecureStorage());
  @override
  Future<String?> getMagicWord() async => null;
  @override
  Future<bool> hasMagicWord() async => false;
  @override
  Future<void> clearMagicWord() async {}
}

const String _uid = 'test_uid_12345';
const String _backupFileName = 'ixo_app_backup.zip';
const String _folderId = 'secbizcard_folder_id';

// Build a valid IV+AES(uid)+ZIP(data.json) backup payload so readback
// verification during migration succeeds.
List<int> buildValidBackupBytes() {
  final archive = Archive();
  final data = utf8.encode(jsonEncode({'contacts': <dynamic>[], 'settings': {}}));
  archive.addFile(ArchiveFile('data.json', data.length, data));
  final zip = ZipEncoder().encode(archive);

  final keyString = _uid.padRight(32, '*').substring(0, 32);
  final key = encrypt.Key.fromUtf8(keyString);
  final iv = encrypt.IV.fromLength(16);
  final encrypter = encrypt.Encrypter(encrypt.AES(key));
  final encrypted = encrypter.encryptBytes(zip, iv: iv);
  return iv.bytes + encrypted.bytes;
}

class FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;

  @override
  Future<String?> getApplicationDocumentsPath() async =>
      Directory.systemTemp.path;
}

/// A Drive fake that distinguishes root files from SecBizCard-folder files and
/// tracks modifiedTime + deletions, so migration ordering can be asserted.
class MigrationFakeDrive implements DriveRepository {
  // key = fileId -> bytes. The folder file id and root file id are distinct.
  final Map<String, List<int>> files = {};
  final Map<String, DateTime> modifiedTimes = {};
  final List<String> deleted = [];

  static const String rootFileId = 'root_backup_id';
  static const String folderFileId = 'folder_backup_id';

  bool uploadShouldFail = false;
  bool folderResolves = true;

  @override
  Future<Either<Failure, String>> ensureSecBizCardFolder() async =>
      right(_folderId);

  @override
  Future<Either<Failure, bool>> fileExists(String fileId) async =>
      right(folderResolves && fileId == _folderId);

  @override
  Future<Either<Failure, String?>> searchBackupFile(
    String fileName, {
    String? parentFolderId,
  }) async {
    if (fileName != _backupFileName) return right(null);
    if (parentFolderId == _folderId) {
      return right(files.containsKey(folderFileId) ? folderFileId : null);
    }
    // No parent → look in root.
    return right(files.containsKey(rootFileId) ? rootFileId : null);
  }

  @override
  Future<Either<Failure, bool>> checkBackupExists(String fileName) async {
    return right(files.containsKey(rootFileId));
  }

  @override
  Future<Either<Failure, List<int>>> downloadFile(String fileId) async {
    final bytes = files[fileId];
    if (bytes == null) return left(const GeneralFailure('not found'));
    return right(bytes);
  }

  @override
  Future<Either<Failure, DateTime?>> getBackupModifiedTime(
    String fileName, {
    String? parentFolderId,
  }) async {
    if (parentFolderId == _folderId) {
      return right(modifiedTimes[folderFileId]);
    }
    return right(modifiedTimes[rootFileId]);
  }

  @override
  Future<Either<Failure, String>> uploadBackup(
    File file,
    String fileName, {
    String? existingFileId,
    String? parentFolderId,
  }) async {
    if (uploadShouldFail) {
      return left(const ServerFailure('upload failed'));
    }
    final bytes = await file.readAsBytes();
    // Writes to the SecBizCard folder regardless of create/update in this fake.
    files[folderFileId] = bytes;
    modifiedTimes[folderFileId] = DateTime.now().toUtc();
    return right(folderFileId);
  }

  @override
  Future<Either<Failure, void>> deleteFile(String fileId) async {
    deleted.add(fileId);
    files.remove(fileId);
    modifiedTimes.remove(fileId);
    return right(null);
  }

  @override
  String getFileUrl(String fileId) => 'http://fake/$fileId';

  @override
  Future<Either<Failure, String>> uploadImage(
    File imageFile,
    String fileName,
  ) async =>
      right('img_id');
}

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockContactsRepository mockContactsRepo;
  late MockProfileRepository mockProfileRepo;
  late MigrationFakeDrive fakeDrive;
  late ProviderContainer container;

  setUp(() {
    provideDummy<Either<Failure, String?>>(right(null));
    provideDummy<Either<Failure, String>>(right('id'));
    provideDummy<Either<Failure, void>>(right(null));
    provideDummy<Either<Failure, UserProfile>>(
      left(const GeneralFailure('no profile')),
    );
    provideDummy<Either<Failure, List<UserProfile>>>(right([]));

    PathProviderPlatform.instance = FakePathProviderPlatform();
    PackageInfo.setMockInitialValues(
      appName: 'SecBizCard',
      packageName: 'com.secbizcard.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    SharedPreferences.setMockInitialValues({});

    mockAuthRepo = MockAuthRepository();
    mockContactsRepo = MockContactsRepository();
    mockProfileRepo = MockProfileRepository();
    fakeDrive = MigrationFakeDrive();

    final testUser = MockUser();
    when(testUser.uid).thenReturn(_uid);
    when(testUser.email).thenReturn('test@example.com');
    when(mockAuthRepo.getCurrentUser()).thenReturn(testUser);
    when(mockContactsRepo.getSavedContacts()).thenAnswer((_) async => right([]));
    when(mockContactsRepo.saveContactLocally(any))
        .thenAnswer((_) async => right(null));
    when(mockProfileRepo.getUser(any))
        .thenAnswer((_) async => left(const GeneralFailure('no profile')));

    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        contactsRepositoryProvider.overrideWithValue(mockContactsRepo),
        profileRepositoryProvider.overrideWithValue(mockProfileRepo),
        driveRepositoryProvider.overrideWithValue(fakeDrive),
        magicWordServiceProvider.overrideWithValue(_NoMagicWordService()),
      ],
    );
  });

  BackupService service() => container.read(backupServiceProvider);

  test('(a) new-home present → no migration, root not deleted', () async {
    // Seed BOTH a root legacy file and a new-home file.
    fakeDrive.files[MigrationFakeDrive.rootFileId] = buildValidBackupBytes();
    fakeDrive.files[MigrationFakeDrive.folderFileId] = buildValidBackupBytes();

    final result = await service().backup(force: true);

    expect(result.isRight(), true, reason: result.fold((l) => l.message, (_) => ''));
    expect(fakeDrive.deleted, isEmpty);
    expect(fakeDrive.files.containsKey(MigrationFakeDrive.rootFileId), true);
  });

  test('(b) root-only → writes new home then deletes root after readback',
      () async {
    // Only a legacy root file exists.
    fakeDrive.files[MigrationFakeDrive.rootFileId] = buildValidBackupBytes();

    final result = await service().backup(force: true);

    expect(result.isRight(), true, reason: result.fold((l) => l.message, (_) => ''));
    // New home was written.
    expect(fakeDrive.files.containsKey(MigrationFakeDrive.folderFileId), true);
    // Root was deleted ONLY after new home confirmed readable.
    expect(fakeDrive.deleted, contains(MigrationFakeDrive.rootFileId));
    expect(fakeDrive.files.containsKey(MigrationFakeDrive.rootFileId), false);
  });

  test('(c) new-home write fails → root NOT deleted', () async {
    fakeDrive.files[MigrationFakeDrive.rootFileId] = buildValidBackupBytes();
    fakeDrive.uploadShouldFail = true;

    final result = await service().backup(force: true);

    expect(result.isLeft(), true);
    expect(fakeDrive.deleted, isEmpty);
    expect(fakeDrive.files.containsKey(MigrationFakeDrive.rootFileId), true);
  });

  test('(d) restore prefers new-home, falls back to root', () async {
    // New-home only.
    fakeDrive.files[MigrationFakeDrive.folderFileId] = buildValidBackupBytes();
    final r1 = await service().restore();
    expect(r1.isRight(), true, reason: r1.fold((l) => l.message, (_) => ''));

    // Root only (fallback).
    fakeDrive.files.clear();
    fakeDrive.files[MigrationFakeDrive.rootFileId] = buildValidBackupBytes();
    final r2 = await service().restore();
    expect(r2.isRight(), true, reason: r2.fold((l) => l.message, (_) => ''));
  });

  test('(e) cloud-newer guard compares the new-home modifiedTime', () async {
    // A new-home file exists with a modifiedTime in the future and the device
    // has never recorded a local change → backup must be blocked as conflict.
    fakeDrive.files[MigrationFakeDrive.folderFileId] = buildValidBackupBytes();
    fakeDrive.modifiedTimes[MigrationFakeDrive.folderFileId] =
        DateTime.now().toUtc().add(const Duration(days: 1));
    // Root has an OLD time that must be ignored by the guard.
    fakeDrive.modifiedTimes[MigrationFakeDrive.rootFileId] =
        DateTime.fromMillisecondsSinceEpoch(0).toUtc();

    final result = await service().backup();

    expect(result.isLeft(), true);
    result.fold(
      (l) => expect(l, isA<BackupConflictFailure>()),
      (_) => fail('expected a BackupConflictFailure'),
    );
  });
}
