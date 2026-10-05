# Implementation Plan — Magic Word Model Redesign

All paths are under the worktree `/Users/jack/_Projects/SecBizCard-Apps/.worktrees/magic-word-redesign`.
Use `git -C /Users/jack/_Projects/SecBizCard-Apps/.worktrees/magic-word-redesign` for git.

## Core model (3 fully-decoupled actions)
1. **Set magic word** = store a LOCAL preference ONLY. No Drive op, no backup, no decrypt.
2. **Back Up Now** = pack LOCAL data + current word (magicword if set, else uid) and overwrite cloud. Never decrypts the old cloud file.
3. **Restore** = download → decrypt → write LOCAL only. Never writes cloud.

Invariants: empty local data can NEVER overwrite the cloud; restore NEVER writes to cloud; setting a magic word NEVER touches Drive.

## Build / verify tooling (fvm — Flutter pinned 3.38.9; NEVER plain `flutter`)
- `fvm flutter gen-l10n` — regenerate localizations after ARB edits.
- `fvm flutter analyze` — DOCUMENTED baseline is 5 pre-existing issues (gitignored `firebase_options.dart` + 3 unrelated test warnings). "Clean" = NO NEW issues beyond that baseline.
- `fvm flutter test` — run the unit suite.
- `fvm flutter test test/unit/services/backup_service_test.dart` — run just the backup service tests.
- `fvm dart run build_runner build --delete-conflicting-outputs` — ONLY if `@riverpod` providers change (this task does NOT change providers, so skip unless a new provider is introduced).

Full verification sequence after all edits: `fvm flutter gen-l10n` → `fvm flutter analyze` → `fvm flutter test`.

---

## Items

- [ ] 1. (D1) Replace `setMagicWordAndRepack(word)` with a pure `setMagicWord(word)` in `BackupService`.
      Remove ALL Drive logic: the `oldWord` capture, the folderId/inFolderId/rootId/sourceId lookups, the download+`_codec.decrypt`+`_codec.encryptNew`+`uploadBackup` repack block, the `_migrateDeleteRootIfSafe` call, the `sourceId == null → backup(force:true)` branch, and the `_rollbackMagicWord` helper (now unused — delete it). New body: validate+store via `_magicWordService.setMagicWord(word)`, mapping `MagicWordValidationFailure` to `left(e)` and other errors to `left(GeneralFailure(...))`; return `right(null)` on success. No `BackupReminderService.markBackedUp()` call. Keep docstring describing the pure-store semantics.
      Verify `_migrateDeleteRootIfSafe` and `_isReadableBackup` are STILL used by `backup()` (they are — in the migrate-then-delete block ~line 240 and inside `_migrateDeleteRootIfSafe`); keep both.
      Files: lib/core/services/backup_service.dart
      Verify: `fvm flutter analyze` reports no new issues in this file (unused-element warning would appear if a helper became dead).

- [ ] 2. (D6/D8/D13) Harden `backup()` with an empty-data guard (defense in depth).
      Add an optional `bool allowEmpty = false` param to `backup({bool force = false, bool allowEmpty = false})`. After gathering `contacts` (and before building the archive), if `contacts.isEmpty && !allowEmpty` return `left(const EmptyBackupFailure())`. Per D13 the gate is contacts-only (do NOT also require profile==null for the abort — contacts empty alone aborts). Ensure the aborted path returns BEFORE any `uploadBackup` and does NOT call `BackupReminderService().markBackedUp()`. Place the guard so `force:true` cannot bypass it (the guard is independent of the `force` conflict check).
      Add `class EmptyBackupFailure extends Failure` to the errors file with a sensible default message.
      Files: lib/core/errors/failure.dart, lib/core/services/backup_service.dart
      Verify: `fvm flutter test test/unit/services/backup_service_test.dart` — new empty-guard tests from item 9 pass.

- [ ] 3. (D5/copy) Reword `magicWordSaved` and prune obsolete repack strings; add ALL new l10n keys across 5 ARB files.
      In `lib/l10n/app_en.arb` (template, keep `@`-metadata) and `app_zh_TW.arb`, `app_zh.arb`, `app_ja.arb`, `app_ko.arb`:
      - REWORD `magicWordSaved` away from "uploaded to Google Drive" → "magic word set — takes effect on your next backup" semantics (5 locales).
      - `magicWordSavedRepacking` and `magicWordRepackFailed` are now obsolete (no repack flow). Remove them from all 5 ARB files (and remove their `@`-metadata in the template) since item 7 drops their only call sites. If anything still references them at analyze time, keep the key but it should be unreferenced — prefer removal.
      - ADD new keys (en template values shown; translate for zh_TW/zh/ja/ko):
        - `magicWordRestoreEnterTitle` / already-have `magicWordRestorePromptTitle` reuse — see below.
        - `magicWordRestorePromptBodyNoWord` = "This backup is locked with a magic word. Enter it to restore. (Case-sensitive.)" (state i — no local word).
        - `magicWordRestorePromptBodyWrongWord` = "The magic word saved on this device can't unlock this backup. Enter the correct one. (Case-sensitive.)" (state ii — local word present but cannot decrypt).
        - `magicWordRememberTitle` = "Remember magic word?"
        - `magicWordRememberBody` = "Remember this magic word on this device so future backups and restores use it automatically?"
        - `magicWordRememberYes` = "Remember"
        - `magicWordRememberNo` = "Not now"
        - `backupDowngradeTitle` = "Remove magic-word protection?"
        - `backupDowngradeBody` = "Your Google Drive backup is currently protected with a magic word. This backup will switch to default encryption and remove that protection. Continue?"
        - `backupEmptyDisabledHint` = "Add at least one contact before backing up." (steer/empty-data disabled hint)
        - `backupRestoreFirstHint` = "You have a cloud backup but no local data. Restore it before backing up or setting a magic word." (steer-to-restore)
        - `backupSetWordNextBackupHint` = "Cloud backup not yet updated with the new magic word — tap Back Up Now to apply it." (D1 next-backup status; may reuse `magicWordSaved` text or be a distinct persistent hint — use this key for the inline status line).
        - `backupRestoreStaleTitle` = "Backup is older than your data"
        - `backupRestoreStaleBody` = "The cloud backup was made {cloudTime} — older than your latest local change {localTime}. Restoring will overwrite your newer local data with this older backup. Continue?" (placeholders cloudTime, localTime: String).
        - REWORD `backupRestoreConfirmBody` to explicitly say it OVERWRITES local data with the cloud backup (D12): e.g. "This downloads your Google Drive backup and OVERWRITES the contacts and settings on this device. Continue?" (5 locales).
      Keep JSON valid; keep key ordering/style consistent with the file. Preserve existing `@`-metadata blocks.
      Files: lib/l10n/app_en.arb, lib/l10n/app_zh_TW.arb, lib/l10n/app_zh.arb, lib/l10n/app_ja.arb, lib/l10n/app_ko.arb
      Verify: `fvm flutter gen-l10n` succeeds with no missing-translation errors; generated `app_localizations.dart` contains the new getters.

- [ ] 4. (D1) Rework the Set Magic Word UI path in `backup_screen.dart` so setting a word never backs up.
      Replace `_applyMagicWord`'s call to `service.setMagicWordAndRepack(word)` with `service.setMagicWord(word)`. On success: show the persistent status `l10n.backupSetWordNextBackupHint` (NOT a backup), set `_statusIsError=false`, refresh `_loadMagicWordState()`; do NOT touch `_hasRemoteBackup` or `_lastBackupTime`. On `MagicWordValidationFailure` show `l10n.magicWordLengthError`; other failures show a generic message. Remove the `l10n.magicWordSavedRepacking` "repacking" status (use a plain "saving" or no spinner text) and the `magicWordRepackFailed` branch.
      Files: lib/features/settings/presentation/screens/backup_screen.dart
      Verify: `fvm flutter analyze` — no new issues; no remaining references to `setMagicWordAndRepack`, `magicWordSavedRepacking`, or `magicWordRepackFailed`.

- [ ] 5. (D4a/D4b) Rework restore magic-word prompting in `backup_screen.dart`.
      - D4a (3-state prompt): capture whether a local word was present at failure time. In `_performRestore`, before calling `service.restore()`, read `final hadLocalWord = await ref.read(magicWordServiceProvider).hasMagicWord();` (or read inside the WrongMagicWordFailure branch). Pass this into `_promptMagicWordAndRetryRestore(hadLocalWord)`. In `_askForMagicWord`, choose the body string: `hadLocalWord ? l10n.magicWordRestorePromptBodyWrongWord : l10n.magicWordRestorePromptBodyNoWord`. (State iii — local word present and decrypts — never reaches this prompt because restore succeeds.)
      - D4b (do NOT auto-store before retry): change `_promptMagicWordAndRetryRestore` so the entered word is used for THIS decrypt only, NOT stored first. Since `BackupService.restore()` reads the stored word internally, add an optional override param to restore (item 6) OR temporarily use the entered word without persisting. Implement via item 6's `restore({String? overrideMagicWord})`: call `service.restore(overrideMagicWord: word)`. Do NOT call `setMagicWord` before the retry. On SUCCESS, show a "Remember this magic word on this device?" dialog (`magicWordRememberTitle`/`magicWordRememberBody`/`magicWordRememberYes`/`magicWordRememberNo`); only if the user chooses Remember call `ref.read(magicWordServiceProvider).setMagicWord(word)` then `_loadMagicWordState()`. On wrong word again, show `l10n.magicWordRestoreWrong` and do NOT store anything (remove the current `clearMagicWord()` logic that assumed auto-store).
      Files: lib/features/settings/presentation/screens/backup_screen.dart
      Verify: `fvm flutter analyze` — no new issues. Behavioral paths covered by item 10 where testable; UI dialog flow marked for runtime verification during implementation.

- [ ] 6. (D4b support) Add an `overrideMagicWord` parameter to `BackupService.restore()`.
      Change signature to `Future<Either<Failure, void>> restore({String? overrideMagicWord})`. Where it currently does `final magicWord = await _magicWordService.getMagicWord();` for decrypt, use `final magicWord = overrideMagicWord ?? await _magicWordService.getMagicWord();`. This lets the UI retry a decrypt with a user-entered word WITHOUT persisting it. Do not change any cloud write behavior (restore still never writes cloud).
      Files: lib/core/services/backup_service.dart
      Verify: `fvm flutter test test/unit/services/backup_service_test.dart` — item 10's override test passes.

- [ ] 7. (D8/D13/D7) Gate backup actions in `backup_screen.dart` on local contacts being non-empty, and steer to Restore.
      Add state `bool _hasLocalContacts = false;` loaded in `initState` via a new `_loadLocalDataState()` that calls `ref.read(contactsRepositoryProvider).getSavedContacts()` and sets `_hasLocalContacts = list.isNotEmpty` (import `contacts_repository.dart`). Refresh it after a successful restore.
      - "Back Up Now" button `onPressed`: disabled when `_isLoading || !_hasLocalContacts`. When disabled due to empty contacts, show `l10n.backupEmptyDisabledHint` (and, when `_hasRemoteBackup`, `l10n.backupRestoreFirstHint`) beneath/near the button.
      - "Set / Change Magic Word" button stays ENABLED when contacts are empty (setting a word no longer backs up), per D1/D8.
      - When `_hasRemoteBackup && !_hasLocalContacts`, visually prioritize Restore (it is already enabled on `_hasRemoteBackup`) and show the steer hint.
      There must be NO path from an empty-local state to a cloud overwrite from this screen.
      Files: lib/features/settings/presentation/screens/backup_screen.dart
      Verify: `fvm flutter analyze` — no new issues. Empty-state disabled behavior marked for runtime verification; the service-level guarantee is covered by item 2 + item 9.

- [ ] 8. (D11/D12) Pre-backup downgrade warning + restore stale/overwrite warnings in `backup_screen.dart`.
      - D11 (downgrade): before performing a backup (in `_performBackup`, before calling `service.backup`), when the cloud file header `encMode == magicword` AND local `hasMagicWord() == false`, warn with `backupDowngradeTitle`/`backupDowngradeBody` and require confirmation. Detect via a new `BackupService` helper `Future<bool> cloudIsMagicWordProtected()` (item 8a) that uses `readHeaderOrNull` with NO decrypt. If the user cancels, abort the backup.
      - D12 (restore overwrites local + reverse-staleness): the restore confirm dialog already warns about overwrite via the reworded `backupRestoreConfirmBody` (item 3). ADD a reverse-staleness check: before/within `_performRestore` confirm, compare the cloud backup `modifiedTime` against local `BackupReminderService().lastModifiedAt()`; if cloud is OLDER than local, additionally show `backupRestoreStaleTitle`/`backupRestoreStaleBody` (with formatted times) and require confirmation. Obtain cloud modifiedTime via a new `BackupService` helper `Future<DateTime?> cloudBackupModifiedTime()` (item 8a).
      Files: lib/features/settings/presentation/screens/backup_screen.dart
      Verify: `fvm flutter analyze` — no new issues. Dialog flows marked for runtime verification; helper logic covered by item 8a tests.

- [ ] 8a. (D11/D12 support) Add read-only cloud-inspection helpers to `BackupService`.
      - `Future<DateTime?> cloudBackupModifiedTime()`: resolve folderId (reuse `_resolveSecBizCardFolderId`) and call `_driveRepo.getBackupModifiedTime(_backupFileName, parentFolderId: folderId)`, returning the time or null. No decrypt, no write.
      - `Future<bool> cloudIsMagicWordProtected()`: locate the cloud file (prefer in-folder then root, mirroring `restore()`'s lookup), download bytes, call `_codec.readHeaderOrNull(bytes)`, return `header?.isMagicWord == true`. On any error return false (fail-open so a transient error never blocks backup; the UI still has the item-2 service guard for safety). No decrypt beyond header parse, no write.
      Files: lib/core/services/backup_service.dart
      Verify: `fvm flutter test test/unit/services/backup_service_test.dart` — item 10's helper tests pass.

- [ ] 9. Rewrite the obsolete `setMagicWordAndRepack` tests and add empty-guard tests in `backup_service_test.dart`.
      REMOVE/REPLACE the 4 tests that call `service.setMagicWordAndRepack(...)` (repack-uid, update-in-place, keep-root-on-fail, initial-backup) — the repack flow no longer exists. Replace with:
      - `setMagicWord stores the word and performs NO Drive operation` — seed a cloud file, call `service.setMagicWord('mysecretword')`, assert `result.isRight()`, `await fakeMagicWord.getMagicWord() == 'mysecretword'`, and `fakeDriveRepo.uploadCount == 0` and `fakeDriveRepo.deleted` is empty (no download/upload/delete).
      - `setMagicWord rejects an invalid word` — call with a too-short word, assert `isLeft()` and `MagicWordValidationFailure`, and the stored word is unchanged.
      - `backup() aborts with EmptyBackupFailure when contacts are empty` — `getSavedContacts` returns `right([])`, call `service.backup()`, assert `isLeft()` + `EmptyBackupFailure`, and `fakeDriveRepo.uploadCount == 0`.
      - `backup(force: true) still aborts on empty contacts (force cannot bypass)` — same seeding, call `backup(force: true)`, assert `EmptyBackupFailure` and no upload.
      - `backup(allowEmpty: true) uploads even when contacts are empty` — assert `isRight()` and an upload happened.
      Note: the existing `backup() with a magic word set writes magicword mode` test currently passes empty contacts — update it to seed one contact (so it is not caught by the new empty guard) while still asserting magicword encMode.
      Files: test/unit/services/backup_service_test.dart
      Verify: `fvm flutter test test/unit/services/backup_service_test.dart` — all tests pass.

- [ ] 10. Add restore-override and cloud-helper tests in `backup_service_test.dart`.
      - `restore(overrideMagicWord:) decrypts without persisting` — seed a magicword cloud file (keySource 'correcthorse'), ensure `fakeMagicWord` has NO stored word, call `service.restore(overrideMagicWord: 'correcthorse')`, assert `isRight()`, and assert `await fakeMagicWord.getMagicWord()` is still null (the override was NOT persisted).
      - `restore(overrideMagicWord: wrong) surfaces WrongMagicWordFailure` — assert `isLeft()` + `WrongMagicWordFailure`.
      - `cloudBackupModifiedTime returns the drive modifiedTime` — extend `FakeDriveRepository.getBackupModifiedTime` to return a seeded time (add a settable field, defaulting to null to preserve existing tests), assert the helper surfaces it.
      - `cloudIsMagicWordProtected true for a magicword file, false for a uid file / no file` — seed each case and assert.
      Files: test/unit/services/backup_service_test.dart
      Verify: `fvm flutter test test/unit/services/backup_service_test.dart` — all tests pass.

- [ ] 11. (copy) Sync `docs/release_1.6.2_store_copy.md` app-facing wording to the new `magicWordSaved` semantics.
      Update any app-facing description that implies setting a magic word uploads/encrypts the cloud backup immediately, to match "magic word set — takes effect on your next backup". The What's New blurbs describe the FEATURE (optional secret phrase to lock the Drive backup) and remain accurate; the "App Review Notes" reviewer-notes section describing magic word as optional encryption STAYS AS-IS per the task. Only adjust wording that conflicts with the decoupled "set does not upload" semantics, if present.
      Files: docs/release_1.6.2_store_copy.md
      Verify: manual read — no app-facing claim that setting a magic word immediately uploads/re-encrypts the Drive backup; reviewer-notes section unchanged.

- [ ] 12. (confirm) Verify the logout magic-word warning in `app_drawer.dart` still warns the word is cleared on sign-out and needed to restore a magicword backup.
      Confirm `drawerLogoutMagicWordNote` / `drawerLogoutMagicWordNoteStrong` are still shown (they are, via the `hasMagicWord` branch ~line 200). Keep them. Strengthen copy only if missing/weak — current `...NoteStrong` already states a magicword backup can ONLY be restored with it, which is adequate; no change required unless review finds it weak.
      Files: lib/core/widgets/app_drawer.dart (likely no change)
      Verify: `fvm flutter analyze` — no new issues.

- [ ] 13. Full verification pass.
      Run the complete sequence and confirm clean against the documented baseline.
      Files: (none — verification only)
      Verify: `fvm flutter gen-l10n` succeeds; `fvm flutter analyze` shows NO new issues beyond the documented 5-issue baseline; `fvm flutter test` passes all tests.

## Scenario coverage map (from design.md simulation; nothing dropped)
- Blind spot 1 (A2 — set word, cloud not yet synced): item 4 persistent "takes effect next backup" status.
- Blind spot 2 (D11 — cloud magicword but no local word → silent downgrade): items 8 + 8a.
- Blind spot 3 (C4/D12 — restore overwrites local; cloud older than local): items 3 (overwrite copy) + 8 (stale warning) + 8a.
- Blind spot 4 (D2 — forgotten word = permanent): item 12 logout warning + existing set-word irreversibility warning (kept).
- Blind spot 5 (E1 — set/backup decoupled, state refresh): items 4/7 refresh `_loadMagicWordState`/`_loadLocalDataState`; item 9 covers the pure-store behavior.
- Blind spot 6 (D13 — empty = contacts empty): items 2/7/9 use contacts-only gate.
- Reinstall data-loss (problem 2): removal of `sourceId==null→backup(force:true)` (item 1) + empty guard (item 2) = two independent defenses.

## Needs runtime/behavioral verification during implementation (cannot be fully proven by unit tests)
- The original reported failure ("Set Magic Word → Continue → auto repack & backup → fails"): fixed by item 1 (no backup on set). Confirm on-device that setting a word shows the next-backup status and performs no Drive call.
- Empty-local disable of Back Up Now and steer-to-Restore UI (item 7).
- 3-state restore prompt wording and the post-restore "remember?" dialog (items 5/6).
- D11 downgrade confirmation and D12 stale-restore confirmation dialogs (item 8).
