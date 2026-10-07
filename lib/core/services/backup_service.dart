import 'dart:convert';
import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:secbizcard/core/errors/failure.dart';
import 'package:secbizcard/core/services/backup_codec.dart';
import 'package:secbizcard/core/services/backup_error_mapper.dart';
import 'package:secbizcard/core/services/backup_phase.dart';
import 'package:secbizcard/core/services/backup_reminder_service.dart';
import 'package:secbizcard/features/auth/data/auth_repository.dart';
import 'package:secbizcard/features/contacts/data/contacts_repository.dart';
import 'package:secbizcard/features/profile/data/profile_repository.dart';
import 'package:secbizcard/features/settings/data/magic_word_service.dart';
import 'package:secbizcard/features/storage/data/drive_repository.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';
import 'package:secbizcard/core/config/theme_controller.dart';
import 'package:fpdart/fpdart.dart';

import 'package:path/path.dart' as p;

part 'backup_service.g.dart';

@riverpod
BackupService backupService(Ref ref) {
  return BackupService(
    ref,
    ref.read(driveRepositoryProvider),
    ref.read(contactsRepositoryProvider),
    ref.read(authRepositoryProvider),
    ref.read(profileRepositoryProvider),
    ref.read(magicWordServiceProvider),
  );
}

class BackupService {
  final Ref _ref;
  final DriveRepository _driveRepo;
  final ContactsRepository _contactsRepo;
  final AuthRepository _authRepo;
  final ProfileRepository _profileRepo;
  final MagicWordService _magicWordService;

  BackupService(
    this._ref,
    this._driveRepo,
    this._contactsRepo,
    this._authRepo,
    this._profileRepo,
    this._magicWordService,
  );

  /// Codec that owns the backup byte layout (SBCB v2 + legacy v1). Shared so a
  /// single instance's secure RNG is reused.
  final BackupCodec _codec = BackupCodec();

  static const String _backupFileName = 'ixo_app_backup.zip';
  static const String _settingsKeyTheme = 'theme_mode'; // Example setting key

  /// SharedPreferences key holding the stable Drive folderId of the
  /// app-created `SecBizCard` folder (see FEAT-001 / plan "Google Drive 固定路徑").
  static const String _prefsKeyFolderId = 'drive_secbizcard_folder_id';

  /// Resolves the stable folderId of the `SecBizCard` Drive folder.
  ///
  /// Reuses a persisted id when it still resolves on Drive; otherwise
  /// (missing/stale) re-finds or creates the folder, persists the id and
  /// returns it. Prefers reuse over recreate so the folder's share
  /// relationships stay stable. Returns null on failure (caller falls back to
  /// the no-parent / root behavior).
  Future<String?> _resolveSecBizCardFolderId() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKeyFolderId);
    if (stored != null && stored.isNotEmpty) {
      final existsResult = await _driveRepo.fileExists(stored);
      final stillExists = existsResult.match((_) => false, (ok) => ok);
      if (stillExists) return stored;
    }

    final ensured = await _driveRepo.ensureSecBizCardFolder();
    final id = ensured.match((_) => null, (id) => id);
    if (id != null) {
      await prefs.setString(_prefsKeyFolderId, id);
    }
    return id;
  }

  /// Creates a backup and uploads to Drive.
  ///
  /// When [force] is false (default), the backup is aborted with a
  /// [BackupConflictFailure] if the existing Drive backup is newer than this
  /// device's local data — this guards against overwriting a more recent
  /// backup made from another device (the classic "old device clobbers new
  /// cloud data" mistake). Pass [force] = true after the user explicitly
  /// confirms they want to overwrite.
  ///
  /// Empty-data guard (defense in depth): if there are no local contacts the
  /// backup aborts with an [EmptyBackupFailure] and performs no upload, so
  /// empty local data can never overwrite the cloud even if the UI gate is
  /// bypassed. The guard is contacts-only and is independent of [force] —
  /// `force: true` does NOT bypass it. Pass [allowEmpty] = true only for a
  /// deliberate empty-state backup.
  Future<Either<Failure, DateTime>> backup({
    bool force = false,
    bool allowEmpty = false,
    void Function(BackupPhase phase)? onPhase,
  }) async {
    try {
      final user = _authRepo.getCurrentUser();
      if (user == null) return left(const AuthFailure('No user logged in'));
      final uid = user.uid;

      // Resolve (and persist) the stable SecBizCard folderId up front so the
      // conflict guard, upload target and migration all operate on the new
      // home. null → folder could not be resolved; we degrade to the legacy
      // root behavior so a backup is never blocked by a transient folder error.
      final folderId = await _resolveSecBizCardFolderId();

      // Guard: don't let an older device silently overwrite a newer cloud
      // backup. Compare the Drive file's server-side modifiedTime against this
      // device's last local change. Uses the Drive server clock, so it is not
      // fooled by device clock differences. Best-effort: if the check itself
      // fails (network/permission), fall through and let the normal upload
      // path surface any real error rather than blocking a legitimate backup.
      //
      // Compare against the NEW-HOME (SecBizCard folder) file's modifiedTime so
      // we never confuse a stale root file for the current backup.
      if (!force) {
        final cloudTimeResult = await _driveRepo.getBackupModifiedTime(
          _backupFileName,
          parentFolderId: folderId,
        );
        final cloudTime = cloudTimeResult.match((_) => null, (t) => t);
        if (cloudTime != null) {
          final localModified = await BackupReminderService().lastModifiedAt();
          // Cloud is "newer" when the local data has never changed on this
          // device, or last changed before the cloud backup was written.
          final cloudIsNewer = localModified == null ||
              cloudTime.toUtc().isAfter(localModified.toUtc());
          if (cloudIsNewer) {
            return left(BackupConflictFailure(
              cloudModifiedTime: cloudTime,
              localModifiedTime: localModified,
            ));
          }
        }
      }

      // 1. Gather Data
      onPhase?.call(BackupPhase.preparing);
      final contactsResult = await _contactsRepo.getSavedContacts();
      final contacts = contactsResult.getOrElse((l) => []);

      // Empty-data guard (D6/D8/D13): never let empty local data overwrite the
      // cloud backup. Contacts-only gate, independent of [force] — a forced
      // backup must NOT be able to clobber the cloud with nothing. Returns
      // before any upload and before markBackedUp(). Opt out only via
      // [allowEmpty] for a deliberate empty-state backup.
      if (contacts.isEmpty && !allowEmpty) {
        return left(const EmptyBackupFailure());
      }

      final prefs = await SharedPreferences.getInstance();
      final settings = {
        _settingsKeyTheme: prefs.getString(_settingsKeyTheme),
        // Add other settings here
      };

      // 2. Prepare Archive
      final archive = Archive();

      // Serialization for contacts
      // Handle local images: if photoUrl is a local file path, add file to zip and update path in JSON
      // We will create a map of "original_path" -> "zip_path"
      final List<Map<String, dynamic>> serializedContacts = [];

      for (final contact in contacts) {
        var contactJson = contact.toJson();

        // Handle Images
        final imageFields = [
          'photoUrl',
          'originalImagePath',
          'flatImagePath',
          'cardFrontPath',
          'cardBackPath'
        ];
        for (final field in imageFields) {
          final path = contactJson[field] as String?;
          if (path != null && !path.startsWith('http')) {
            final file = File(path);
            if (await file.exists()) {
              final filename = 'contacts/${contact.uid}_$field${p.extension(path)}';
              final bytes = await file.readAsBytes();
              archive.addFile(ArchiveFile(filename, bytes.length, bytes));
              contactJson[field] = 'zip://$filename';
            }
          }
        }
        serializedContacts.add(contactJson);
      }

      // 1.5 Gather User Profile
      Map<String, dynamic>? serializedProfile;
      final profileResult = await _profileRepo.getUser(uid);
      
      UserProfile? profile;
      profileResult.fold((l) => null, (p) => profile = p);

      if (profile != null) {
        var pJson = profile!.toJson();
        final imageFields = [
          'photoUrl',
          'cardFrontPath',
          'cardBackPath'
        ];
        for (final field in imageFields) {
          final path = pJson[field] as String?;
          if (path != null && !path.startsWith('http')) {
            final file = File(path);
            if (await file.exists()) {
              final filename = 'profile/$field${p.extension(path)}';
              final bytes = await file.readAsBytes();
              archive.addFile(ArchiveFile(filename, bytes.length, bytes));
              pJson[field] = 'zip://$filename';
            }
          }
        }
        serializedProfile = pJson;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final backupData = {
        'timestamp': DateTime.now().toIso8601String(),
        'appVersion': packageInfo.version, // Real version
        'contacts': serializedContacts,
        'settings': settings,
        'userProfile': serializedProfile,
      };

      // Add data.json
      final jsonBytes = utf8.encode(jsonEncode(backupData));
      archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));

      // 3. Zip
      final zipEncoder = ZipEncoder();
      final encodedZip = zipEncoder.encode(archive);

      // 4. Encrypt — ALWAYS write the new "SBCB" v2 format. The encMode is
      // chosen from the locally stored magic word: `magicword` when the user
      // has set one (then uid can no longer decrypt it), otherwise `uid`.
      onPhase?.call(BackupPhase.encrypting);
      final finalBytes = await _encryptForUpload(encodedZip, uid: uid);

      // 5. Save Temp File
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$_backupFileName');
      await tempFile.writeAsBytes(finalBytes);

      // 6. Upload (into the SecBizCard folder when resolvable)
      // Look for an existing backup INSIDE the new-home folder; update it in
      // place to preserve the folder-share relationship. If none exists in the
      // folder yet, create a new file with parents:[folderId].
      final newHomeSearch = await _driveRepo.searchBackupFile(
        _backupFileName,
        parentFolderId: folderId,
      );
      final existingNewHomeId = newHomeSearch.match((l) => null, (r) => r);

      onPhase?.call(BackupPhase.uploading);
      final uploadResult = await _driveRepo.uploadBackup(
        tempFile,
        _backupFileName,
        existingFileId: existingNewHomeId,
        parentFolderId: folderId,
      );

      // 6.5 Migration: if a legacy root file exists but the new home did not
      // yet have one, delete the root file ONLY AFTER the new-home upload
      // succeeded AND the new-home file reads back as a non-empty, decryptable
      // ZIP. Order must never reverse — a failed write/readback leaves root
      // intact so no data is lost.
      if (folderId != null &&
          existingNewHomeId == null &&
          uploadResult.isRight()) {
        await _migrateDeleteRootIfSafe(uid: uid, folderId: folderId);
      }

      if (uploadResult.isRight()) {
        // Data is now safely backed up — clears the "unbacked-up changes"
        // reminder until the next local change. Best-effort: never let the
        // reminder timestamp turn a successful backup into a failure.
        try {
          await BackupReminderService().markBackedUp();
        } catch (_) {/* non-critical */}
      }
      return uploadResult.fold((l) => left(l), (r) => right(DateTime.now()));
    } catch (e) {
      // Classify into a TYPED failure (offline / interrupted / auth / generic)
      // so the UI shows a friendly, localized message instead of raw
      // ClientException/PlatformException/DetailedApiRequestError text. Typed
      // failures thrown earlier (AuthFailure, EmptyBackupFailure, etc.) are
      // returned via `left(...)` and never reach here; mapBackupError also
      // passes any Failure through unchanged as a safety net.
      return left(mapBackupError(e));
    }
  }

  /// Encrypts [zipBytes] into the new SBCB v2 format, choosing encMode from the
  /// locally stored magic word (magicword if present, else uid).
  Future<List<int>> _encryptForUpload(
    List<int> zipBytes, {
    required String uid,
  }) async {
    final magicWord = await _magicWordService.getMagicWord();
    if (magicWord != null) {
      return _codec.encryptNew(
        zipBytes,
        encMode: BackupCodec.encModeMagicWord,
        keySource: magicWord,
      );
    }
    return _codec.encryptNew(
      zipBytes,
      encMode: BackupCodec.encModeUid,
      keySource: uid,
    );
  }

  /// Deletes the legacy root `ixo_app_backup.zip` ONLY after confirming the
  /// new-home file (inside [folderId]) is present and reads back as a
  /// non-empty, decryptable ZIP. Any failure aborts without deleting root.
  Future<void> _migrateDeleteRootIfSafe({
    required String uid,
    required String folderId,
  }) async {
    try {
      // Is there actually a legacy file in ROOT to migrate? Scope strictly to
      // My Drive root — a plain "search anywhere" would match the file we just
      // created inside the folder and we would then delete it.
      final rootSearch =
          await _driveRepo.searchRootBackupFile(_backupFileName);
      final rootId = rootSearch.match((l) => null, (r) => r);
      if (rootId == null) return; // nothing to migrate

      // Confirm the new-home file is readable before touching root.
      final newHomeSearch = await _driveRepo.searchBackupFile(
        _backupFileName,
        parentFolderId: folderId,
      );
      final newHomeId = newHomeSearch.match((l) => null, (r) => r);
      if (newHomeId == null) return; // new home not written; keep root

      // Hard guard: never delete when the resolved root match IS the in-folder
      // file (same id). This is the self-delete that corrupted brand-new
      // accounts; even if a future search regression resolves the in-folder
      // file as "root", this makes the delete impossible.
      if (rootId == newHomeId) return;

      final downloadResult = await _driveRepo.downloadFile(newHomeId);
      final bytes = downloadResult.match((l) => null, (b) => b);
      if (bytes == null || bytes.isEmpty) return; // unreadable; keep root

      if (!await _isReadableBackup(bytes, uid)) {
        return; // not decryptable; keep root
      }

      // New home confirmed readable → safe to delete the legacy root file.
      await _driveRepo.deleteFile(rootId);
    } catch (_) {
      // Never let a migration cleanup failure break a successful backup.
    }
  }

  /// Verifies [bytes] decrypt (via the codec, routing legacy/uid/magicword)
  /// and unzip into an archive that contains data.json. Uses the locally stored
  /// magic word when the file is in magicword mode. Returns false on any
  /// failure.
  Future<bool> _isReadableBackup(List<int> bytes, String uid) async {
    try {
      if (bytes.isEmpty) return false;
      final magicWord = await _magicWordService.getMagicWord();
      final decryptedBytes =
          await _codec.decrypt(bytes, uid: uid, magicWord: magicWord);
      final archive = ZipDecoder().decodeBytes(decryptedBytes);
      return archive.findFile('data.json') != null;
    } catch (_) {
      return false;
    }
  }

  /// Checks if a backup exists, preferring the SecBizCard folder and falling
  /// back to the legacy root file.
  Future<bool> hasBackup() async {
    final folderId = await _resolveSecBizCardFolderId();
    if (folderId != null) {
      final newHome = await _driveRepo.searchBackupFile(
        _backupFileName,
        parentFolderId: folderId,
      );
      final newHomeId = newHome.match((l) => null, (r) => r);
      if (newHomeId != null) return true;
    }
    final rootResult = await _driveRepo.checkBackupExists(_backupFileName);
    return rootResult.fold((l) => false, (r) => r);
  }

  /// Restores from Drive.
  ///
  /// [overrideMagicWord], when supplied, is used for THIS decrypt only and is
  /// NEVER persisted — it lets the UI retry a decrypt with a user-entered word
  /// without first storing it (so a wrong guess doesn't leave a bad word
  /// stored). When null the locally stored magic word is used. Restore never
  /// writes to the cloud under any path.
  Future<Either<Failure, void>> restore({
    String? overrideMagicWord,
    void Function(BackupPhase phase)? onPhase,
  }) async {
    try {
      final user = _authRepo.getCurrentUser();
      if (user == null) return left(const AuthFailure('No user logged in'));
      final uid = user.uid;

      // 1. Search & Download — prefer SecBizCard/ixo_app_backup.zip (new home),
      // then fall back to the legacy root ixo_app_backup.zip.
      final folderId = await _resolveSecBizCardFolderId();

      String? fileId;
      if (folderId != null) {
        final newHome = await _driveRepo.searchBackupFile(
          _backupFileName,
          parentFolderId: folderId,
        );
        fileId = newHome.match((l) => null, (r) => r);
      }
      if (fileId == null) {
        final rootSearch = await _driveRepo.searchBackupFile(_backupFileName);
        fileId = rootSearch.match((l) => null, (r) => r);
      }

      return Future<Either<Failure, void>>(() async {
        if (fileId == null) {
          return left(const GeneralFailure('No backup found'));
        }

        onPhase?.call(BackupPhase.downloading);
        final downloadResult = await _driveRepo.downloadFile(fileId);
        return downloadResult.fold((l) => left(l), (bytes) async {
          // 2. Decrypt — route by file format via the codec:
          //  - legacy v1 (no SBCB) → uid + AES-CTR;
          //  - v2 encMode=uid → PBKDF2(uid) + GCM;
          //  - v2 encMode=magicword → PBKDF2(magic word) + GCM, NEVER uid.
          // A magicword file with a wrong/absent local word surfaces cleanly as
          // WrongMagicWordFailure (no uid fallback, no garbage).
          final List<int> decryptedBytes;
          try {
            onPhase?.call(BackupPhase.decrypting);
            final magicWord =
                overrideMagicWord ?? await _magicWordService.getMagicWord();
            decryptedBytes =
                await _codec.decrypt(bytes, uid: uid, magicWord: magicWord);
          } on WrongMagicWordFailure catch (e) {
            return left(e);
          } on BackupFormatFailure catch (e) {
            return left(e);
          } catch (e) {
            return left(GeneralFailure('Decryption failed: $e'));
          }

          try {
            // 3. Unzip
            onPhase?.call(BackupPhase.restoring);
            final archive = ZipDecoder().decodeBytes(decryptedBytes);

            // 4. Parse JSON
            final dataFile = archive.findFile('data.json');
            if (dataFile == null) {
              return left(
                const GeneralFailure('Invalid backup: missing data.json'),
              );
            }

            final jsonStr = utf8.decode(dataFile.content);
            final data = jsonDecode(jsonStr) as Map<String, dynamic>;

            // 5. Restore Contacts
            final appDir = await getApplicationDocumentsDirectory();
            // Safe cast
            final contactsList = data['contacts'] as List;
            final contactsJson = contactsList
                .map((e) => e as Map<String, dynamic>)
                .toList();

            for (var cJson in contactsJson) {
              final imageFields = [
                'photoUrl',
                'originalImagePath',
                'flatImagePath',
                'cardFrontPath',
                'cardBackPath'
              ];
              for (final field in imageFields) {
                String? path = cJson[field];
                if (path != null && path.startsWith('zip://')) {
                  final zipPath = path.replaceFirst('zip://', '');
                  final imgFile = archive.findFile(zipPath);
                  if (imgFile != null) {
                    final localPath = '${appDir.path}/$zipPath';
                    final localFile = File(localPath);
                    await localFile.create(recursive: true);
                    await localFile.writeAsBytes(imgFile.content);
                    cJson[field] = localPath;
                  } else {
                    cJson[field] = null;
                  }
                }
              }

              final profile = UserProfile.fromJson(cJson);
              await _contactsRepo.saveContactLocally(profile);
            }

            // 6. Restore Settings
            final settings = data['settings'] as Map<String, dynamic>;
            final prefs = await SharedPreferences.getInstance();
            if (settings.containsKey(_settingsKeyTheme)) {
              final theme = settings[_settingsKeyTheme];
              if (theme != null) {
                await prefs.setString(_settingsKeyTheme, theme);
              }
            }

            // 7. Restore User Profile
            if (data.containsKey('userProfile') && data['userProfile'] != null) {
              final pJson = data['userProfile'] as Map<String, dynamic>;
              final imageFields = [
                'photoUrl',
                'cardFrontPath',
                'cardBackPath'
              ];
              for (final field in imageFields) {
                String? path = pJson[field];
                if (path != null && path.startsWith('zip://')) {
                  final zipPath = path.replaceFirst('zip://', '');
                  final imgFile = archive.findFile(zipPath);
                  if (imgFile != null) {
                    final localPath = '${appDir.path}/$zipPath';
                    final localFile = File(localPath);
                    await localFile.create(recursive: true);
                    await localFile.writeAsBytes(imgFile.content);
                    pJson[field] = localPath;
                  } else {
                    pJson[field] = null;
                  }
                }
              }
              final profile = UserProfile.fromJson(pJson);
              await _profileRepo.createOrUpdateUser(profile);
            }

            // A freshly restored install is "in sync". Stamp this AFTER the
            // per-contact/profile saves above (each of which marks data as
            // modified) so lastBackupAt >= lastModifiedAt and the reminder does
            // not immediately nag a just-restored user. Best-effort.
            try {
              await BackupReminderService().markBackedUp();
            } catch (_) {/* non-critical */}

            // Invalidate providers so UI updates
            _ref.invalidate(savedContactsProvider);
            _ref.invalidate(themeControllerProvider);
            _ref.invalidate(userProfileProvider);

            return right(null);
          } catch (e) {
            return left(GeneralFailure('Decryption/Restore failed: $e'));
          }
        });
      });
    } catch (e) {
      // Friendly, typed classification for restore too (interrupted download,
      // offline, Drive auth, generic) — never surface raw transport text.
      return left(mapBackupError(e));
    }
  }

  /// Sets/changes the backup magic word as a LOCAL preference ONLY.
  ///
  /// This performs NO Drive operation and triggers NO backup (D1): it just
  /// validates and stores [word] via [MagicWordService.setMagicWord]
  /// (which throws [MagicWordValidationFailure] when the normalized length is
  /// not 8-16). The new word takes effect on the NEXT [backup]; it never
  /// repacks or overwrites the existing cloud file, so setting a word can never
  /// clobber a backup the user still needs to restore.
  ///
  /// Returns `right(null)` on success, `left(MagicWordValidationFailure)` for a
  /// bad word, or `left(GeneralFailure)` for any other storage error.
  Future<Either<Failure, void>> setMagicWord(String word) async {
    try {
      await _magicWordService.setMagicWord(word);
      return right(null);
    } on MagicWordValidationFailure catch (e) {
      return left(e);
    } catch (e) {
      return left(GeneralFailure('Could not store magic word: $e'));
    }
  }

  /// Read-only: the server-side modifiedTime of the current cloud backup, or
  /// null when there is none (or it cannot be determined). Resolves the
  /// SecBizCard folder and asks Drive directly — no download, no decrypt, no
  /// write. Used by the D12 stale-restore warning.
  Future<DateTime?> cloudBackupModifiedTime() async {
    final folderId = await _resolveSecBizCardFolderId();
    final result = await _driveRepo.getBackupModifiedTime(
      _backupFileName,
      parentFolderId: folderId,
    );
    return result.match((_) => null, (t) => t);
  }

  /// Read-only: whether the current cloud backup is magic-word protected.
  ///
  /// Locates the cloud file (prefer the in-folder file, then the legacy root
  /// file — mirroring [restore]'s lookup), downloads the bytes and parses ONLY
  /// the header via [BackupCodec.readHeaderOrNull] (no payload decrypt). Used
  /// by the D11 downgrade warning. Fails open: any error (no file, network,
  /// legacy/unparseable file) returns false so a transient problem never
  /// blocks a backup — the empty-data guard in [backup] remains the hard
  /// safety net. Never writes anything.
  Future<bool> cloudIsMagicWordProtected() async {
    try {
      final folderId = await _resolveSecBizCardFolderId();

      String? fileId;
      if (folderId != null) {
        final newHome = await _driveRepo.searchBackupFile(
          _backupFileName,
          parentFolderId: folderId,
        );
        fileId = newHome.match((l) => null, (r) => r);
      }
      if (fileId == null) {
        final rootSearch = await _driveRepo.searchBackupFile(_backupFileName);
        fileId = rootSearch.match((l) => null, (r) => r);
      }
      if (fileId == null) return false;

      final downloadResult = await _driveRepo.downloadFile(fileId);
      final bytes = downloadResult.match((_) => null, (b) => b);
      if (bytes == null || bytes.isEmpty) return false;

      final header = _codec.readHeaderOrNull(bytes);
      return header?.isMagicWord == true;
    } catch (_) {
      return false;
    }
  }
}
