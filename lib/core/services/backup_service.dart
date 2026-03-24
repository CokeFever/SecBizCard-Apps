import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:archive/archive_io.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:secbizcard/core/errors/failure.dart';
import 'package:secbizcard/features/auth/data/auth_repository.dart';
import 'package:secbizcard/features/contacts/data/contacts_repository.dart';
import 'package:secbizcard/features/profile/data/profile_repository.dart';
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
  );
}

class BackupService {
  final Ref _ref;
  final DriveRepository _driveRepo;
  final ContactsRepository _contactsRepo;
  final AuthRepository _authRepo;
  final ProfileRepository _profileRepo;

  BackupService(this._ref, this._driveRepo, this._contactsRepo, this._authRepo, this._profileRepo);

  static const String _backupFileName = 'ixo_app_backup.zip';
  static const String _settingsKeyTheme = 'theme_mode'; // Example setting key

  /// Creates a backup and uploads to Drive
  Future<Either<Failure, DateTime>> backup() async {
    try {
      final user = _authRepo.getCurrentUser();
      if (user == null) return left(const AuthFailure('No user logged in'));
      final uid = user.uid;

      // 1. Gather Data
      final contactsResult = await _contactsRepo.getSavedContacts();
      final contacts = contactsResult.getOrElse((l) => []);

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

      // 4. Encrypt
      // Use UID padded to 32 chars as key
      final keyString = uid.padRight(32, '*').substring(0, 32);
      final key = encrypt.Key.fromUtf8(keyString);
      final iv = encrypt.IV.fromLength(16); // Random IV
      final encrypter = encrypt.Encrypter(encrypt.AES(key));

      final encrypted = encrypter.encryptBytes(encodedZip, iv: iv);

      // Combine IV + Encrypted Data
      final finalBytes = iv.bytes + encrypted.bytes;

      // 5. Save Temp File
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$_backupFileName');
      await tempFile.writeAsBytes(finalBytes);

      // 6. Upload
      // Check existing
      final searchResult = await _driveRepo.searchBackupFile(_backupFileName);
      final existingId = searchResult.match((l) => null, (r) => r);

      final uploadResult = await _driveRepo.uploadBackup(
        tempFile,
        _backupFileName,
        existingFileId: existingId,
      );

      return uploadResult.fold((l) => left(l), (r) => right(DateTime.now()));
    } catch (e) {
      return left(GeneralFailure('Backup failed: $e'));
    }
  }

  /// Checks if a backup exists
  Future<bool> hasBackup() async {
    final result = await _driveRepo.checkBackupExists(_backupFileName);
    return result.fold((l) => false, (r) => r);
  }

  /// Restores from Drive
  Future<Either<Failure, void>> restore() async {
    try {
      final user = _authRepo.getCurrentUser();
      if (user == null) return left(const AuthFailure('No user logged in'));
      final uid = user.uid;

      // 1. Search & Download
      final searchResult = await _driveRepo.searchBackupFile(_backupFileName);
      return searchResult.fold((l) => left(l), (fileId) async {
        if (fileId == null) {
          return left(const GeneralFailure('No backup found'));
        }

        final downloadResult = await _driveRepo.downloadFile(fileId);
        return downloadResult.fold((l) => left(l), (bytes) async {
          // 2. Decrypt
          try {
            final ivBytes = bytes.sublist(0, 16);
            final contentBytes = bytes.sublist(16);

            final keyString = uid.padRight(32, '*').substring(0, 32);
            final key = encrypt.Key.fromUtf8(keyString);
            final iv = encrypt.IV(Uint8List.fromList(ivBytes));
            final encrypter = encrypt.Encrypter(encrypt.AES(key));

            final decryptedBytes = encrypter.decryptBytes(
              encrypt.Encrypted(Uint8List.fromList(contentBytes)),
              iv: iv,
            );

            // 3. Unzip
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
      return left(GeneralFailure('Restore failed: $e'));
    }
  }
}
