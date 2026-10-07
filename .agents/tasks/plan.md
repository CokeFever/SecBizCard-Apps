# Implementation Plan — 1.6.3+188 (backup conflict-guard + Save-to-Google lag)

All paths below are inside the worktree
`/Users/jack/_Projects/SecBizCard-Apps/.worktrees/backup-conflict-contacts-ux`
(branch `fix/backup-conflict-contacts-ux`). Flutter is pinned to 3.38.9 via fvm —
ALWAYS use `fvm flutter`, never bare `flutter`.

## Hard constraints (do NOT touch)
- The Google Sign-In split (`driveGoogleSignIn` / `contactsGoogleSignIn` in the auth repo) — verified P0.
- The backup byte format (`BackupCodec` / `SBCB`).
- The magic-word model.
- Do NOT bump the pubspec version, tag, or deploy.

## Environment note for ALL build/analyze/test commands
The worktree has a path dependency on the private `SecBizCard_OCR` package. If
`fvm flutter pub get` / `analyze` / `test` cannot resolve that path dep from the
worktree, run the SAME commands from the MAIN workspace
`/Users/jack/_Projects/SecBizCard-Apps` instead (the source edits live in the
worktree; only command execution moves). Try the worktree first; fall back to
the main workspace if pub-get fails on the OCR path dep. Record which location
was used in the FEAT findings.

Baseline for `fvm flutter analyze`: 3–5 PRE-EXISTING issues are expected
(`unnecessary_non_null_assertion` in `zip_import_service_test` and
`firebase_options`). The gate is NO NEW issues, not zero issues.
Baseline for `fvm flutter test test/unit`: ~154 tests green before changes.

---

## Design decisions (made here, grounded in the code I read)

- **FIX 1 signal source.** `BackupReminderService` already persists this
  device's last successful backup time under `keyLastBackup` via `markBackedUp()`
  (`lib/core/services/backup_reminder_service.dart`), but exposes NO getter for
  it (only `lastModifiedAt()` for `keyLastModified`). I will add a
  `lastBackupAt()` getter mirroring `lastModifiedAt()` and compare the cloud
  modifiedTime against THAT, with a skew tolerance, instead of against the local
  data-change time. This is the minimal correct change and reuses the existing
  storage key.
- **Skew tolerance = 120 seconds.** The device's own just-written cloud file has
  `cloudTime ≈ its own lastBackup` but the two clocks differ (Drive server vs.
  device) and `markBackedUp()` is stamped a moment AFTER the upload. A 2-minute
  margin comfortably absorbs normal clock skew + upload latency while still
  catching a genuine other-device write (which is realistically minutes/hours
  later). Defined as a named `const` so it is reviewable and testable.
- **FIX 2 progress UX = modal progress dialog with a live `ValueNotifier`
  counter.** `exportToGoogle` already loops per-contact
  (`contact_export_service.dart`), so threading an `onProgress(done, total)`
  callback is clean and low-risk. I will show a non-dismissible `AlertDialog`
  ("Exporting n/total…") driven by a `ValueListenableBuilder`, popped in
  `finally`. This satisfies both "persistent indicator" and "show progress"
  without inventing new overlay infrastructure.
- **FIX 2 single-contact path.** `saveToGoogleContacts` in the repo saves ONE
  contact (no loop), so there is no per-item progress to show; the single-card
  screen (`contact_detail_screen.dart`) only needs the persistent in-progress
  indicator + a leak-proof guard. It already has `_isExporting` + a disabled
  menu item but (a) no try/finally so the guard leaks on exception and (b) no
  persistent on-screen indicator while the async work runs. I will fix both.

---

# Implementation Plan

- [ ] 1. Add a `lastBackupAt()` getter to `BackupReminderService`.
      Mirror the existing `lastModifiedAt()` getter but read `keyLastBackup`
      instead of `keyLastModified`; return `null` when the key is absent, else
      `DateTime.fromMillisecondsSinceEpoch(ms)`. Add a short doc comment stating
      it is "this device's last successful backup time, used by the backup
      conflict guard".
      Files: `lib/core/services/backup_reminder_service.dart`
      Verify: `fvm flutter test test/unit/services/backup_reminder_service_test.dart`
      still passes (no behavior change to existing methods).

- [ ] 2. Rewrite the FIX 1 conflict guard in `BackupService.backup()` to compare
      cloud modifiedTime against this device's LAST SUCCESSFUL BACKUP (not last
      local data change). In the `if (!force) { … }` block (around lines
      120–150), after fetching `cloudTime`:
        - Add a module-level/private `const Duration _conflictSkew = Duration(seconds: 120);`
          (place near the other static consts in the class).
        - Replace `final localModified = await BackupReminderService().lastModifiedAt();`
          and the `cloudIsNewer` computation with:
          `final lastBackup = await BackupReminderService().lastBackupAt();`
        - New conflict rule:
          * If `lastBackup == null` (this device never successfully backed up)
            AND `cloudTime != null` (a cloud file exists this device didn't
            write) → genuine first-run-on-new-device conflict → keep returning
            `left(BackupConflictFailure(...))`.
          * If `lastBackup != null` → conflict ONLY when
            `cloudTime.toUtc().isAfter(lastBackup.toUtc().add(_conflictSkew))`
            (another device wrote the cloud meaningfully AFTER our last backup).
            Otherwise NO conflict (this covers the regression: same device
            re-backup where `cloudTime ≈ lastBackup`).
        - Keep `force: true` bypassing the whole block (unchanged).
        - Keep best-effort behavior: if `cloudTime == null` (fetch failed or no
          file), fall through and do NOT block (unchanged).
        - Update the `BackupConflictFailure` payload: pass `lastBackup` as the
          "local" side of the comparison. Check `BackupConflictFailure`'s
          constructor in `lib/core/errors/failure.dart`; if its field is named
          `localModifiedTime`, pass `localModifiedTime: lastBackup` (rename of
          the value's meaning only — do NOT change the failure class's public
          shape unless a field rename is trivially safe and all call sites are
          updated).
      Also update the `backup()` doc comment that currently says the guard
      compares against "this device's local data" to say it compares against
      "this device's last successful backup".
      Files: `lib/core/services/backup_service.dart`
      Verify: builds via `fvm flutter analyze` (no new issues); unit suite still
      green after step 3's tests are added.

- [ ] 3. Add FIX 1 conflict-guard unit tests to
      `test/unit/services/backup_service_test.dart`. The `FakeDriveRepository`
      already exposes a settable `backupModifiedTime` and
      `getBackupModifiedTime` returns it — use that to drive `cloudTime`. Seed
      the device's last-backup time via `SharedPreferences.setMockInitialValues`
      using `BackupReminderService.keyLastBackup` (epoch-ms). Seed one contact
      so the empty-data guard doesn't short-circuit. Add these cases inside the
      `BackupService Test` group:
        (a) **same-device re-backup, no data change** — set `keyLastBackup` to
            T, set `fakeDriveRepo.backupModifiedTime = T` (or T + a few seconds,
            within skew) → `backup()` returns `right` and upload happens (the
            regression we fix: NO `BackupConflictFailure`).
        (b) **another device wrote cloud after our last backup** — set
            `keyLastBackup = T`, `backupModifiedTime = T + 10 minutes` →
            `backup()` returns `left(BackupConflictFailure)`, `uploadCount == 0`.
        (c) **fresh device, never backed up, cloud exists** — no `keyLastBackup`
            seeded, `backupModifiedTime = someTime` → `left(BackupConflictFailure)`
            (first-run safety preserved).
        (d) **force bypass** — same setup as (b) but call `backup(force: true)`
            → `right`, upload happens, no conflict.
      Note: existing tests leave `backupModifiedTime` null, so they are
      unaffected. Keep `mockContactsRepo.getSavedContacts()` returning a
      non-empty list in these new tests.
      Files: `test/unit/services/backup_service_test.dart`
      Verify: `fvm flutter test test/unit/services/backup_service_test.dart`
      passes including the 4 new cases.

- [ ] 4. (FIX 2 — service) Thread an optional per-contact progress callback
      through `ContactExportService.exportToGoogle`. Add a named param
      `void Function(int done, int total)? onProgress`. After each
      `saveToGoogleContacts` result is folded (success OR failure), call
      `onProgress?.call(i + 1, profiles.length)`. Do NOT change the existing
      return type (`GoogleExportResult`) or the success/failure tally logic.
      Files: `lib/features/contacts/data/services/contact_export_service.dart`
      Verify: `fvm flutter analyze` (no new issues). Existing export tests, if
      any, still pass under `fvm flutter test test/unit`.

- [ ] 5. (FIX 2 — batch path) Rework `_batchExportToGoogle` in `main_screen.dart`
      to add an in-progress guard, a persistent modal progress dialog, and live
      progress, keeping existing error handling intact.
        - Add `bool _isExportingToGoogle = false;` to `_MainScreenState`.
        - At the TOP of `_batchExportToGoogle` (before any await): if
          `_isExportingToGoogle` is true, `return`; else set it true. Wrap the
          async work in `try { … } finally { if (mounted) setState(() => _isExportingToGoogle = false); }`.
          (The guard is set BEFORE the first await and released in `finally` on
          both success and failure.)
        - Replace the transient `messenger.showSnackBar(mainExporting(...))`
          with a non-dismissible progress dialog: a `ValueNotifier<int>`
          `progress` (starts 0) shown via `showDialog(barrierDismissible: false,
          builder: … ValueListenableBuilder …)` rendering a text like
          `l10n.mainExportingProgress(progress, total)` beside a
          `CircularProgressIndicator`. Call
          `service.exportToGoogle(profiles, onProgress: (done, _) => progress.value = done)`.
        - In `finally`: dismiss the dialog (e.g. pop the dialog route /
          `Navigator.of(context, rootNavigator: true).pop()` guarded by
          `mounted`) and dispose the `ValueNotifier`.
        - Keep the EXISTING result handling verbatim: `result.allOk` →
          `mainExportedToGoogle`; `succeeded == 0` with
          `firstError == kContactsPermissionDenied` →
          `contactDetailExportPermissionDenied` else `mainExportFailed`;
          partial → `mainExportedPartial`. Show that final message as the
          SnackBar AFTER the dialog is dismissed. Keep `_exitSelection()`.
      Files: `lib/features/home/presentation/screens/main_screen.dart`
      Verify: `fvm flutter analyze` (no new issues).

- [ ] 6. (FIX 2 — single-contact path) Harden `_exportToGoogle` in
      `contact_detail_screen.dart` so the in-progress guard is leak-proof and a
      persistent indicator shows during the await.
        - Guard against re-entry: at the top of the method (after the choice
          dialog returns non-null), if `_isExporting` is already true, return.
        - Wrap the `repo.saveToGoogleContacts(...)` await and result handling in
          `try { setState(()=>_isExporting=true); … } finally { if (mounted) setState(()=>_isExporting=false); }`
          so the guard is released even if an exception is thrown (current code
          only resets it on the normal path).
        - Show a persistent indicator while in progress. Reuse the pattern
          already in this screen for `_isSavingPhoto` (a visible overlay/spinner
          driven by the `_isExporting` flag in `build`), OR show a
          non-dismissible progress dialog popped in `finally`. Pick ONE and keep
          it consistent with the screen's existing style; the `enabled:
          !_isExporting` on the popup menu item stays.
        - Keep the existing friendly error handling
          (`kContactsPermissionDenied` → `contactDetailExportPermissionDenied`,
          else `contactDetailExportFailed`) and the success SnackBar unchanged.
      Files: `lib/features/contacts/presentation/screens/contact_detail_screen.dart`
      Verify: `fvm flutter analyze` (no new issues).

- [ ] 7. (FIX 2 — localization) Add the one NEW user-facing string
      `mainExportingProgress` (e.g. "Exporting {done}/{total}…") to ALL FIVE ARB
      files, with the `@mainExportingProgress` metadata block (two int
      placeholders `done`, `total`) in `app_en.arb` only, following the exact
      pattern of the adjacent `mainExporting` / `mainExportedPartial` entries.
      Place it next to `mainExporting` in each file. If step 6 chose a
      dialog needing its own string, add that too (same 5-locale rule).
        - `lib/l10n/app_en.arb` (with `@` metadata)
        - `lib/l10n/app_zh.arb`
        - `lib/l10n/app_zh_TW.arb`
        - `lib/l10n/app_ja.arb`
        - `lib/l10n/app_ko.arb`
      Translations: en "Exporting {done}/{total}…"; zh-TW "正在匯出 {done}/{total}…";
      zh "正在导出 {done}/{total}…"; ja "{done}/{total} 件をエクスポート中…";
      ko "{done}/{total}개 내보내는 중…".
      Files: the five ARB files above.
      Verify: `fvm flutter gen-l10n` regenerates
      `lib/generated/l10n/app_localizations*.dart` with no errors and
      `l10n.mainExportingProgress(...)` resolves in `main_screen.dart`.

- [ ] 8. Full verification pass (run in the worktree; fall back to the main
      workspace per the environment note if pub-get fails on the OCR path dep).
        - `fvm flutter gen-l10n` — clean, no errors.
        - `fvm flutter analyze` — only the known pre-existing baseline issues,
          NO new issues introduced by steps 1–7.
        - `fvm flutter test test/unit` — green, ~154 prior tests PLUS the 4 new
          conflict-guard tests from step 3.
      Clean up any scratch files created during verification.
      Files: none (verification only).
      Verify: all three commands succeed with the outcomes above.

---

## Needs verification during implementation (do NOT assume already-fixed)

- **Report #9 "backup is newer" false positive** — fixed structurally by steps
  1–3. The coder MUST confirm via test case (a) that a same-device re-backup
  with `cloudTime ≈ lastBackup` no longer returns `BackupConflictFailure`.
- **Report #11 "save to Google contacts" lag/double-tap** — the batch path
  (`_batchExportToGoogle`) genuinely has NO guard today; the single-card path
  has a partial guard that leaks on exception. Both are addressed by steps 4–6.
  The coder should, if a device/emulator is available, sanity-check that the
  progress dialog appears immediately and repeated taps cannot start a second
  export; if runtime testing is not possible, rely on the analyze/test pass and
  note that manual device QA is pending.
- **`BackupConflictFailure` field naming** — step 2 assumes a `localModifiedTime`
  field. Open `lib/core/errors/failure.dart` and confirm the exact constructor
  before editing; adjust the passed argument name accordingly and keep the
  failure class's public shape stable unless a rename is trivially safe across
  all call sites (grep for `BackupConflictFailure(` and its field reads).
