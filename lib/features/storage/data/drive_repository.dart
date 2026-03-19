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
  // Use the shared provider from AuthRepo
  return DriveRepository(ref.watch(googleSignInProvider));
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

  Future<Either<Failure, String?>> searchBackupFile(String fileName) async {
    try {
      final apiResult = await _getDriveApi();
      return apiResult.fold((l) => left(l), (driveApi) async {
        final fileList = await driveApi.files.list(
          q: "name = '$fileName' and trashed = false",
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

  /// Helper for UI to check if backup exists
  Future<Either<Failure, bool>> checkBackupExists(String fileName) async {
    final result = await searchBackupFile(fileName);
    return result.map((id) => id != null);
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
  }) async {
    try {
      final apiResult = await _getDriveApi();
      return apiResult.fold((l) => left(l), (driveApi) async {
        final driveFile = drive.File()..name = fileName;
        final media = drive.Media(file.openRead(), await file.length());

        if (existingFileId != null) {
          // Update
          final updated = await driveApi.files.update(
            driveFile,
            existingFileId,
            uploadMedia: media,
          );
          return right(updated.id!);
        } else {
          // Create
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
