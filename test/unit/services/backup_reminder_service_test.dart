import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secbizcard/core/services/backup_reminder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  Future<SharedPreferences> freshPrefs([Map<String, Object>? seed]) async {
    SharedPreferences.setMockInitialValues(seed ?? {});
    return SharedPreferences.getInstance();
  }

  BackupReminderService svc(
    SharedPreferences p, {
    DateTime? now,
  }) =>
      BackupReminderService(prefs: p, now: () => now ?? DateTime(2026, 9, 20));

  test('empty install (no data) is never reminded', () async {
    prefs = await freshPrefs();
    final s = svc(prefs);
    expect(await s.shouldRemind(hasData: false), isFalse);
  });

  test('has data but never backed up -> remind', () async {
    prefs = await freshPrefs(); // no lastBackup key
    final s = svc(prefs);
    expect(await s.shouldRemind(hasData: true), isTrue);
  });

  test('backed up and no changes since -> no reminder', () async {
    final t = DateTime(2026, 9, 20);
    prefs = await freshPrefs({
      BackupReminderService.keyLastBackup: t.millisecondsSinceEpoch,
    });
    final s = svc(prefs, now: t);
    expect(await s.shouldRemind(hasData: true), isFalse);
  });

  test('unbacked-up change (lastModified > lastBackup) -> remind', () async {
    final backup = DateTime(2026, 9, 20, 10);
    final modified = DateTime(2026, 9, 20, 11);
    prefs = await freshPrefs({
      BackupReminderService.keyLastBackup: backup.millisecondsSinceEpoch,
      BackupReminderService.keyLastModified: modified.millisecondsSinceEpoch,
    });
    final s = svc(prefs, now: DateTime(2026, 9, 21));
    expect(await s.shouldRemind(hasData: true), isTrue);
  });

  test('change older than last backup -> no reminder', () async {
    final modified = DateTime(2026, 9, 20, 10);
    final backup = DateTime(2026, 9, 20, 11);
    prefs = await freshPrefs({
      BackupReminderService.keyLastModified: modified.millisecondsSinceEpoch,
      BackupReminderService.keyLastBackup: backup.millisecondsSinceEpoch,
    });
    final s = svc(prefs, now: DateTime(2026, 9, 21));
    expect(await s.shouldRemind(hasData: true), isFalse);
  });

  test('snoozed this calendar month -> no reminder', () async {
    // Never backed up (would normally remind), but snoozed for Sep 2026.
    prefs = await freshPrefs({
      BackupReminderService.keySnoozedMonth: 202609,
    });
    final s = svc(prefs, now: DateTime(2026, 9, 20));
    expect(await s.shouldRemind(hasData: true), isFalse);
  });

  test('snooze auto-resets next calendar month -> remind again', () async {
    prefs = await freshPrefs({
      BackupReminderService.keySnoozedMonth: 202609,
    });
    // Now it's October -> snooze no longer applies.
    final s = svc(prefs, now: DateTime(2026, 10, 1));
    expect(await s.shouldRemind(hasData: true), isTrue);
  });

  test('snoozeThisMonth writes the current month key', () async {
    prefs = await freshPrefs();
    final s = svc(prefs, now: DateTime(2026, 9, 20));
    await s.snoozeThisMonth();
    expect(prefs.getInt(BackupReminderService.keySnoozedMonth), 202609);
    // And it now suppresses the reminder.
    expect(await s.shouldRemind(hasData: true), isFalse);
  });

  test('markBackedUp clears an unbacked-up-change reminder', () async {
    final modified = DateTime(2026, 9, 20, 10);
    prefs = await freshPrefs({
      BackupReminderService.keyLastModified: modified.millisecondsSinceEpoch,
    });
    // Before backup: has data, never backed up -> remind.
    final before = svc(prefs, now: DateTime(2026, 9, 20, 10, 30));
    expect(await before.shouldRemind(hasData: true), isTrue);
    // Back up now (later than the modification).
    final after = svc(prefs, now: DateTime(2026, 9, 20, 11));
    await after.markBackedUp();
    expect(await after.shouldRemind(hasData: true), isFalse);
  });
}
