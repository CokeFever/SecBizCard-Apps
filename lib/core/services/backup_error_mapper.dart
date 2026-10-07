import 'dart:async';
import 'dart:io';

import 'package:googleapis/drive/v3.dart' as drive;

import 'package:secbizcard/core/errors/failure.dart';

/// Classifies a raw error thrown during backup/restore (upload, download,
/// Drive API, encrypt/zip) into a TYPED [Failure] carrying a stable sentinel,
/// so the UI can select a friendly, localized message by failure TYPE and the
/// user NEVER sees a raw `ClientException` / `SocketException` /
/// `DetailedApiRequestError` / `PlatformException` string.
///
/// Pure and side-effect free so it can be unit-tested directly — modeled on
/// `mapGenericError` in `handshake_repository.dart` (lower-cased substring
/// matching). Classification order:
///
///  1. Drive auth / token problem (401/403, insufficient scopes) → [AuthFailure]
///     with the re-auth sentinel [kBackupErrorAuth]. Checked FIRST so an auth
///     error is never mistaken for a transport drop.
///  2. Interrupted mid-transfer: a connection that dropped while bytes were in
///     flight — the `ClientException` contentLength mismatch, a socket reset, a
///     stream closed early, or a timeout → [InterruptedTransferFailure].
///  3. No connectivity at all (failed host lookup / network unreachable /
///     connection refused) → [ConnectionFailure] with the `'offline'` sentinel,
///     matching the existing handshake convention.
///  4. Anything else → [GeneralFailure] with the generic sentinel
///     [kBackupErrorGeneric].
///
/// The returned [Failure.message] is a STABLE SENTINEL (not user-facing text);
/// the screen maps the sentinel/type to a localized string.
Failure mapBackupError(Object e) {
  // Preserve typed failures that already carry their own meaning — never
  // re-wrap a WrongMagicWord/BackupFormat/Conflict/Empty/Auth/etc. as generic.
  if (e is Failure) return e;

  // 1. Drive auth / token issue → re-auth oriented message.
  if (e is drive.DetailedApiRequestError) {
    final status = e.status;
    if (status == 401 || status == 403) {
      return const AuthFailure(kBackupErrorAuth);
    }
  }

  final text = e.toString().toLowerCase();

  if (text.contains('insufficient authentication scopes') ||
      text.contains('invalid_grant') ||
      text.contains('invalid credentials') ||
      text.contains('unauthenticated') ||
      text.contains('permission denied') ||
      text.contains('insufficient permission')) {
    return const AuthFailure(kBackupErrorAuth);
  }

  // 2. Interrupted mid-transfer: bytes were moving and the pipe broke. The
  // googleapis/http stack surfaces a truncated upload as a ClientException
  // whose message mentions the contentLength mismatch; a dropped socket shows
  // up as "connection reset"/"connection closed"/"broken pipe"; a stall shows
  // up as a TimeoutException.
  if (e is TimeoutException ||
      text.contains('contentlength') ||
      text.contains('content size below specified') ||
      text.contains('content size exceeds specified') ||
      text.contains('bytes written but expected') ||
      text.contains('connection reset') ||
      text.contains('connection closed') ||
      text.contains('broken pipe') ||
      text.contains('software caused connection abort') ||
      text.contains('connection terminated') ||
      text.contains('timed out') ||
      text.contains('timeout')) {
    return const InterruptedTransferFailure();
  }

  // 3. No connectivity at all. Mirror handshake's mapGenericError classifiers.
  if (e is SocketException ||
      text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('network is unreachable') ||
      text.contains('no address associated with hostname') ||
      text.contains('connection refused')) {
    return const ConnectionFailure(kBackupErrorOffline);
  }

  // 4. Everything else → generic, retryable.
  return const GeneralFailure(kBackupErrorGeneric);
}

/// Stable sentinel: no connectivity. Shared with the handshake convention
/// (`ConnectionFailure('offline')`).
const String kBackupErrorOffline = 'offline';

/// Stable sentinel: Drive sign-in / token / permission problem (re-auth).
const String kBackupErrorAuth = 'backup_auth';

/// Stable sentinel: generic, retryable backup/restore failure.
const String kBackupErrorGeneric = 'backup_generic';
