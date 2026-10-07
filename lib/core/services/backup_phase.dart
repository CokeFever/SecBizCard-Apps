/// The staged phases a backup or restore passes through, reported to the UI via
/// the optional `onPhase` callback on [BackupService.backup]/[BackupService.restore]
/// so it can show "Preparing… → Encrypting… → Uploading…" (and the restore
/// equivalents) wired to the REAL work boundaries, not a fake timer.
///
/// This is a pure UI-progress signal — it carries no bytes and does NOT touch
/// the backup byte format. Adding/removing a phase only changes what text the
/// user sees.
enum BackupPhase {
  /// Backup: gathering contacts/profile/settings and zipping them.
  preparing,

  /// Backup: encrypting the zip via BackupCodec (SBCB v2).
  encrypting,

  /// Backup: uploading the encrypted bytes to Drive.
  uploading,

  /// Restore: downloading the encrypted backup from Drive.
  downloading,

  /// Restore: decrypting the downloaded bytes.
  decrypting,

  /// Restore: unzipping and writing contacts/profile/settings locally.
  restoring,
}
