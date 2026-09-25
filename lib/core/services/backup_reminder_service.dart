import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provides the app-wide [BackupReminderService]. Plain [Provider] (not
/// code-gen) so it needs no build_runner step.
final backupReminderServiceProvider = Provider<BackupReminderService>(
  (ref) => BackupReminderService(),
);

/// Local-only bookkeeping for the "you have unbacked-up changes" reminder.
///
/// Design constraints (deliberate):
///  - **No Google Drive / network calls.** Deciding whether to remind must not
///    require Drive auth or trigger a permission prompt. We rely purely on two
///    local timestamps: when data last changed vs. when it was last backed up
///    (a successful backup OR a successful restore both count as "in sync").
///  - **Non-intrusive.** The reminder only surfaces on a later cold start, and
///    the user can snooze it for the rest of the calendar month.
///
/// Timestamps are stored as epoch-ms ints in shared_preferences, matching the
/// app's existing ad-hoc pattern. The backup timestamp reuses the same key the
/// Backup screen already writes (`last_backup_timestamp`) so the two agree.
class BackupReminderService {
  BackupReminderService({SharedPreferences? prefs, DateTime Function()? now})
      : _injectedPrefs = prefs,
        _now = now ?? DateTime.now;

  final SharedPreferences? _injectedPrefs;
  final DateTime Function() _now;

  // Reuses the key the Backup screen already persists on a successful backup.
  static const String keyLastBackup = 'last_backup_timestamp';
  static const String keyLastModified = 'last_modified_timestamp';
  // Stored as year*100 + month (e.g. 202609 for Sep 2026).
  static const String keySnoozedMonth = 'backup_reminder_snoozed_month';

  Future<SharedPreferences> get _prefs async =>
      _injectedPrefs ?? await SharedPreferences.getInstance();

  int get _monthKey {
    final n = _now();
    return n.year * 100 + n.month;
  }

  /// Record that local contact/profile data changed just now.
  Future<void> markDataModified() async {
    final prefs = await _prefs;
    await prefs.setInt(keyLastModified, _now().millisecondsSinceEpoch);
  }

  /// Record that data is now safely backed up (successful backup OR restore).
  Future<void> markBackedUp() async {
    final prefs = await _prefs;
    await prefs.setInt(keyLastBackup, _now().millisecondsSinceEpoch);
  }

  /// The local timestamp of the last recorded data change, or null if nothing
  /// has ever been marked modified on this device. Used by the backup flow to
  /// detect when the cloud backup is newer than this device's data.
  Future<DateTime?> lastModifiedAt() async {
    final prefs = await _prefs;
    final ms = prefs.getInt(keyLastModified);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Snooze the reminder for the remainder of the current calendar month.
  Future<void> snoozeThisMonth() async {
    final prefs = await _prefs;
    await prefs.setInt(keySnoozedMonth, _monthKey);
  }

  /// Clear all reminder bookkeeping. Called on sign-out so a different account
  /// signing in on this device does not inherit the previous account's
  /// "unbacked-up changes" / snooze state. (The contacts DB itself is wiped
  /// separately by the auth layer.)
  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(keyLastModified);
    await prefs.remove(keyLastBackup);
    await prefs.remove(keySnoozedMonth);
  }

  /// Whether to show the backup reminder now.
  ///
  /// [hasData] must be true only when the user actually has contacts/profile
  /// worth backing up — an empty install is never nagged.
  ///
  /// Returns true when: there is data, the reminder has not been snoozed for
  /// the current calendar month, AND there are unbacked-up changes whose last
  /// change was on an earlier calendar day than today. The day-boundary rule
  /// means a contact added/edited *today* is only surfaced from the NEXT day's
  /// cold start onward — we never nag about a change the user just made.
  Future<bool> shouldRemind({required bool hasData}) async {
    if (!hasData) return false;

    final prefs = await _prefs;

    // Snoozed for this calendar month? (auto-resets next month)
    final snoozedMonth = prefs.getInt(keySnoozedMonth);
    if (snoozedMonth != null && snoozedMonth == _monthKey) return false;

    final lastModified = prefs.getInt(keyLastModified);
    // Nothing was ever recorded as changed on this device -> nothing to nag
    // about. (A fresh account, or one whose changes are all already backed up.)
    if (lastModified == null) return false;

    final lastBackup = prefs.getInt(keyLastBackup);
    final hasUnbackedChanges = lastBackup == null || lastModified > lastBackup;
    if (!hasUnbackedChanges) return false;

    // Next-day rule: only remind once the change is at least one calendar day
    // old. A change made today waits until tomorrow.
    final modified = DateTime.fromMillisecondsSinceEpoch(lastModified);
    final now = _now();
    final modifiedDay = DateTime(modified.year, modified.month, modified.day);
    final today = DateTime(now.year, now.month, now.day);
    return today.isAfter(modifiedDay);
  }
}
