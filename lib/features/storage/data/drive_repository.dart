import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:secbizcard/core/errors/failure.dart';
import 'package:secbizcard/features/auth/data/auth_repository.dart';

part 'drive_repository.g.dart';

@riverpod
DriveRepository driveRepository(Ref ref) {
  // Dedicated drive.file-only GoogleSignIn instance. Kept independent from the
  // contacts instance so requesting the pending-verification contacts scope can
  // never poison this instance's drive.file token request.
  return DriveRepository(ref.watch(driveGoogleSignInProvider));
}

class DriveRepository {
  final GoogleSignIn _googleSignIn;

  DriveRepository(this._googleSignIn);

  /// Helper to get authenticated client, handling silent login and permissions
  Future<Either<Failure, drive.DriveApi>> _getDriveApi() async {
    try {
      var account = _googleSignIn.currentUser;

      // Try silent sign in if not current
      account ??= await _googleSignIn.signInSilently();

      // If still null, we are not logged in.
      // We should avoid prompting here if possible, but if not, fail.
      account ??= await _googleSignIn.signIn();

      if (account == null) {
        return left(const AuthFailure('User not signed in'));
      }

      // Check permissions
      // Note: canAccessScopes is cleaner but requestScopes handles both check and request
      final authorized = await _googleSignIn.requestScopes([
        drive.DriveApi.driveFileScope,
      ]);
      if (!authorized) {
        return left(const AuthFailure('Drive permission denied'));
      }

      final authHeaders = await account.authHeaders;
      final authenticatedClient = _GoogleAuthClient(authHeaders);
      return right(drive.DriveApi(authenticatedClient));
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, String>> uploadImage(
    File imageFile,
    String fileName,
  ) async {
    try {
      final apiResult = await _getDriveApi();
      return apiResult.fold((l) => left(l), (driveApi) async {
        // Create file metadata
        final driveFile = drive.File()
          ..name = fileName
          ..mimeType = 'image/jpeg';

        // Upload file
        final media = drive.Media(imageFile.openRead(), imageFile.lengthSync());
        final uploadedFile = await driveApi.files.create(
          driveFile,
          uploadMedia: media,
        );

        if (uploadedFile.id == null) {
          return left(const ServerFailure('Failed to upload file'));
        }

        // Public logic omitted for backup simplicity, assume kept private or shared logic same
        await driveApi.permissions.create(
          drive.Permission()
            ..type = 'anyone'
            ..role = 'reader',
          uploadedFile.id!,
        );

        return right(uploadedFile.id!);
      });
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }

  String getFileUrl(String fileId) {
    return 'https://drive.google.com/uc?export=view&id=$fileId';
  }

  Future<Either<Failure, void>> deleteFile(String fileId) async {
    try {
      final apiResult = await _getDriveApi();
      return apiResult.fold((l) => left(l), (driveApi) async {
        await driveApi.files.delete(fileId);
        return right(null);
      });
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }

  /// Finds the app-created, non-trashed `SecBizCard` folder directly under
  /// My Drive root, creating it if it does not exist, and returns its id.
  ///
  /// Uses the `drive.file` scope only: the folder is created by the app, so the
  /// scope is sufficient and does NOT need widening. The returned id should be
  /// persisted and reused so the folder's share relationships stay stable
  /// (sharing lives on the folder, not the backup file inside it).
  Future<Either<Failure, String>> ensureSecBizCardFolder() async {
    try {
      final apiResult = await _getDriveApi();
      return apiResult.fold((l) => left(l), (driveApi) async {
        final fileList = await driveApi.files.list(
          q: "name = 'SecBizCard' and "
              "mimeType = 'application/vnd.google-apps.folder' and "
              "'root' in parents and trashed = false",
          $fields: 'files(id, name)',
        );

        final files = fileList.files;
        if (files != null && files.isNotEmpty && files.first.id != null) {
          return right(files.first.id!);
        }

        final folder = drive.File()
          ..name = 'SecBizCard'
          ..mimeType = 'application/vnd.google-apps.folder'
          ..parents = ['root'];
        final created = await driveApi.files.create(folder);
        if (created.id == null) {
          return left(const ServerFailure('Failed to create SecBizCard folder'));
        }
        return right(created.id!);
      });
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }

  /// Returns true if a non-trashed file/folder with [fileId] still exists.
  Future<Either<Failure, bool>> fileExists(String fileId) async {
    try {
      final apiResult = await _getDriveApi();
      return apiResult.fold((l) => left(l), (driveApi) async {
        try {
          final file = await driveApi.files.get(
            fileId,
            $fields: 'id, trashed',
          ) as drive.File;
          return right(file.trashed != true);
        } catch (_) {
          // 404 / not found → treat as "does not exist" rather than an error.
          return right(false);
        }
      });
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }

  /// Finds a non-trashed backup file named [fileName].
  ///
  /// Parent scoping:
  ///  - [parentFolderId] != null → constrain to that folder.
  ///  - [parentFolderId] == null && [rootOnly] == true → constrain to My Drive
  ///    root (`'root' in parents`). Use this for legacy-root lookups so a
  ///    just-created in-folder file is NEVER matched as the "root" file (that
  ///    bug caused the migrate step to delete the file it had just created).
  ///  - [parentFolderId] == null && [rootOnly] == false → no parent constraint
  ///    ("search anywhere"), matching a file in ANY folder. Used by callers
  ///    like [checkBackupExists] that only care whether a backup exists at all.
  Future<Either<Failure, String?>> searchBackupFile(
    String fileName, {
    String? parentFolderId,
    bool rootOnly = false,
  }) async {
    try {
      final apiResult = await _getDriveApi();
      return apiResult.fold((l) => left(l), (driveApi) async {
        var q = "name = '$fileName' and trashed = false";
        if (parentFolderId != null) {
          q += " and '$parentFolderId' in parents";
        } else if (rootOnly) {
          q += " and 'root' in parents";
        }
        final fileList = await driveApi.files.list(
          q: q,
          $fields: 'files(id, name, createdTime, modifiedTime, size)',
        );

        if (fileList.files != null && fileList.files!.isNotEmpty) {
          return right(fileList.files!.first.id);
        }
        return right(null);
      });
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }

  /// Finds a non-trashed backup named [fileName] that lives directly in My
  /// Drive root. Thin wrapper over [searchBackupFile] with `rootOnly: true`.
  Future<Either<Failure, String?>> searchRootBackupFile(String fileName) =>
      searchBackupFile(fileName, rootOnly: true);

  /// Helper for UI to check if backup exists
  Future<Either<Failure, bool>> checkBackupExists(String fileName) async {
    final result = await searchBackupFile(fileName);
    return result.map((id) => id != null);
  }

  /// Returns the server-side [modifiedTime] of the existing backup file, or
  /// null if no backup exists yet. Uses Google Drive's server clock (not any
  /// device clock), so it is reliable for "is the cloud copy newer than this
  /// device?" checks across multiple devices.
  Future<Either<Failure, DateTime?>> getBackupModifiedTime(
    String fileName, {
    String? parentFolderId,
  }) async {
    try {
      final apiResult = await _getDriveApi();
      return apiResult.fold((l) => left(l), (driveApi) async {
        var q = "name = '$fileName' and trashed = false";
        if (parentFolderId != null) {
          q += " and '$parentFolderId' in parents";
        }
        final fileList = await driveApi.files.list(
          q: q,
          $fields: 'files(id, name, modifiedTime)',
        );

        final files = fileList.files;
        if (files == null || files.isEmpty) {
          return right(null);
        }
        // modifiedTime is a UTC DateTime from the Drive API.
        return right(files.first.modifiedTime);
      });
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, List<int>>> downloadFile(String fileId) async {
    try {
      final apiResult = await _getDriveApi();
      return apiResult.fold((l) => left(l), (driveApi) async {
        final media =
            await driveApi.files.get(
                  fileId,
                  downloadOptions: drive.DownloadOptions.fullMedia,
                )
                as drive.Media;

        final List<int> dataStore = [];
        await for (final data in media.stream) {
          dataStore.addAll(data);
        }
        return right(dataStore);
      });
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, String>> uploadBackup(
    File file,
    String fileName, {
    String? existingFileId,
    String? parentFolderId,
  }) async {
    try {
      final apiResult = await _getDriveApi();
      return apiResult.fold((l) => left(l), (driveApi) async {
        final media = drive.Media(file.openRead(), await file.length());

        if (existingFileId != null) {
          // Update in place. Normally we do NOT change parents, so the file
          // keeps living in the SecBizCard folder and preserves its share
          // relationships. Defense-in-depth: if a parentFolderId is supplied
          // AND the file is not already under it, add it to the folder (and
          // detach any other parents) so an update can never leave a stray
          // backup in Drive root. googleapis files.update supports
          // addParents/removeParents for exactly this relocation.
          final driveFile = drive.File()..name = fileName;
          String? addParents;
          String? removeParents;
          if (parentFolderId != null) {
            final existing = await driveApi.files.get(
              existingFileId,
              $fields: 'parents',
            ) as drive.File;
            final currentParents = existing.parents ?? const <String>[];
            if (!currentParents.contains(parentFolderId)) {
              addParents = parentFolderId;
              if (currentParents.isNotEmpty) {
                removeParents = currentParents.join(',');
              }
            }
          }
          final updated = await driveApi.files.update(
            driveFile,
            existingFileId,
            uploadMedia: media,
            addParents: addParents,
            removeParents: removeParents,
          );
          return right(updated.id!);
        } else {
          // Create. When a parentFolderId is given, create inside that folder.
          final driveFile = drive.File()..name = fileName;
          if (parentFolderId != null) {
            driveFile.parents = [parentFolderId];
          }
          final created = await driveApi.files.create(
            driveFile,
            uploadMedia: media,
          );
          return right(created.id!);
        }
      });
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }
}

/// HTTP client that adds authentication headers
class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}
