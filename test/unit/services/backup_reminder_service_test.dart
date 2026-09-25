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

  test('has data but nothing ever recorded as modified -> no reminder',
      () async {
    // A fresh account (no lastModified key) must NOT be nagged, even though it
    // has never backed up. Only a real, recorded local change triggers the
    // reminder. This guards the "empty account got nagged" regression.
    prefs = await freshPrefs();
    final s = svc(prefs);
    expect(await s.shouldRemind(hasData: true), isFalse);
  });

  test('modified yesterday, never backed up -> remind', () async {
    final modified = DateTime(2026, 9, 19, 11);
    prefs = await freshPrefs({
      BackupReminderService.keyLastModified: modified.millisecondsSinceEpoch,
    });
    final s = svc(prefs, now: DateTime(2026, 9, 20, 9));
    expect(await s.shouldRemind(hasData: true), isTrue);
  });

  test('modified today -> no reminder yet (next-day rule)', () async {
    // Change made earlier today should NOT nag on the same day.
    final modified = DateTime(2026, 9, 20, 8);
    prefs = await freshPrefs({
      BackupReminderService.keyLastModified: modified.millisecondsSinceEpoch,
    });
    final s = svc(prefs, now: DateTime(2026, 9, 20, 20));
    expect(await s.shouldRemind(hasData: true), isFalse);
  });

  test('backed up and no changes since -> no reminder', () async {
    final t = DateTime(2026, 9, 20);
    prefs = await freshPrefs({
      BackupReminderService.keyLastBackup: t.millisecondsSinceEpoch,
    });
    final s = svc(prefs, now: t);
    expect(await s.shouldRemind(hasData: true), isFalse);
  });

  test('unbacked-up change from an earlier day -> remind', () async {
    final backup = DateTime(2026, 9, 20, 10);
    final modified = DateTime(2026, 9, 20, 11);
    prefs = await freshPrefs({
      BackupReminderService.keyLastBackup: backup.millisecondsSinceEpoch,
      BackupReminderService.keyLastModified: modified.millisecondsSinceEpoch,
    });
    // Next day: the change is now a calendar day old -> remind.
    final s = svc(prefs, now: DateTime(2026, 9, 21));
    expect(await s.shouldRemind(hasData: true), isTrue);
  });

  test('unbacked-up change made today -> no reminder yet', () async {
    final backup = DateTime(2026, 9, 20, 10);
    final modified = DateTime(2026, 9, 20, 11);
    prefs = await freshPrefs({
      BackupReminderService.keyLastBackup: backup.millisecondsSinceEpoch,
      BackupReminderService.keyLastModified: modified.millisecondsSinceEpoch,
    });
    // Same day as the change -> next-day rule suppresses it.
    final s = svc(prefs, now: DateTime(2026, 9, 20, 23, 59));
    expect(await s.shouldRemind(hasData: true), isFalse);
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
    // Has a day-old unbacked change (would normally remind), but snoozed.
    prefs = await freshPrefs({
      BackupReminderService.keyLastModified:
          DateTime(2026, 9, 19).millisecondsSinceEpoch,
      BackupReminderService.keySnoozedMonth: 202609,
    });
    final s = svc(prefs, now: DateTime(2026, 9, 20));
    expect(await s.shouldRemind(hasData: true), isFalse);
  });

  test('snooze auto-resets next calendar month -> remind again', () async {
    prefs = await freshPrefs({
      BackupReminderService.keyLastModified:
          DateTime(2026, 9, 19).millisecondsSinceEpoch,
      BackupReminderService.keySnoozedMonth: 202609,
    });
    // Now it's October -> snooze no longer applies, change is days old.
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
    final modified = DateTime(2026, 9, 19, 10);
    prefs = await freshPrefs({
      BackupReminderService.keyLastModified: modified.millisecondsSinceEpoch,
    });
    // Before backup: has a day-old change, never backed up -> remind.
    final before = svc(prefs, now: DateTime(2026, 9, 20, 10, 30));
    expect(await before.shouldRemind(hasData: true), isTrue);
    // Back up now (later than the modification).
    final after = svc(prefs, now: DateTime(2026, 9, 20, 11));
    await after.markBackedUp();
    expect(await after.shouldRemind(hasData: true), isFalse);
  });

  test('clear() removes all bookkeeping (no cross-account carry-over)',
      () async {
    prefs = await freshPrefs({
      BackupReminderService.keyLastModified:
          DateTime(2026, 9, 18).millisecondsSinceEpoch,
      BackupReminderService.keyLastBackup:
          DateTime(2026, 9, 17).millisecondsSinceEpoch,
      BackupReminderService.keySnoozedMonth: 202609,
    });
    final s = svc(prefs, now: DateTime(2026, 9, 20));
    await s.clear();
    expect(prefs.getInt(BackupReminderService.keyLastModified), isNull);
    expect(prefs.getInt(BackupReminderService.keyLastBackup), isNull);
    expect(prefs.getInt(BackupReminderService.keySnoozedMonth), isNull);
    // A fresh account on this device is not nagged.
    expect(await s.shouldRemind(hasData: true), isFalse);
  });
}
