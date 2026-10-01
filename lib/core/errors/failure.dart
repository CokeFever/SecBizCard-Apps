abstract class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => message;
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class ConnectionFailure extends Failure {
  const ConnectionFailure(super.message);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class GeneralFailure extends Failure {
  const GeneralFailure(super.message);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// A backup file declares `encMode = "magicword"` in its header but the magic
/// word supplied (or the locally-stored one) does not decrypt it — the AES-GCM
/// authentication tag failed to verify.
///
/// PRIVACY RULE: a magicword file is NEVER retried with the uid key, so this is
/// surfaced as a clean, explicit failure (not silent garbage, not a uid
/// fallback). The owner must supply the correct magic word.
class WrongMagicWordFailure extends Failure {
  const WrongMagicWordFailure([
    super.message = 'Wrong magic word for this backup',
  ]);
}

/// A backup file is structurally invalid or corrupt — bad magic/header,
/// truncated bytes, or a non-magicword decryption that failed authentication.
/// (A wrong magic word has its own [WrongMagicWordFailure].)
class BackupFormatFailure extends Failure {
  const BackupFormatFailure([super.message = 'Invalid or corrupt backup file']);
}

/// The user-entered magic word fails the format rules (length 8-16 after
/// trim + Unicode NFC normalization). Symbols, spaces and mixed case are all
/// allowed — only the normalized length is enforced.
class MagicWordValidationFailure extends Failure {
  const MagicWordValidationFailure([
    super.message = 'Magic word must be 8 to 16 characters',
  ]);
}

/// Signals that a backup was blocked because the existing Google Drive backup
/// is newer than this device's local data — backing up now would overwrite a
/// more recent backup (e.g. one made from another device). Carries both
/// timestamps so the UI can warn the user and offer to force-overwrite.
class BackupConflictFailure extends Failure {
  /// Server-side modified time of the existing Drive backup (UTC).
  final DateTime cloudModifiedTime;

  /// This device's last recorded local data change, if any.
  final DateTime? localModifiedTime;

  const BackupConflictFailure({
    required this.cloudModifiedTime,
    this.localModifiedTime,
  }) : super('Cloud backup is newer than this device');
}
