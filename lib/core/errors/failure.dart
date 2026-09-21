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
