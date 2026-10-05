# Implementation Plan — Fix repack overwrite bug (`setMagicWordAndRepack`)

All paths are absolute inside the worktree
`/Users/jack/_Projects/SecBizCard-Apps/.worktrees/fix-repack-overwrite`.
Use `git -C /Users/jack/_Projects/SecBizCard-Apps/.worktrees/fix-repack-overwrite`
for any git operation. Build/test ONLY with `fvm flutter ...` (Flutter pinned
3.38.9 via `.fvmrc`), never plain `flutter`.

## Design decisions (grounded in the code read)

- **Root cause confirmed.** `setMagicWordAndRepack` downloads the existing cloud
  file and calls `_codec.decrypt(bytes, uid: uid, magicWord: oldWord)` to obtain
  the source ZIP. When the cloud file is magicword-mode and `oldWord` does not
  match (set on another device / earlier), `BackupCodec.decrypt` throws
  `WrongMagicWordFailure('Magic word required for this backup')`
  (`backup_codec.dart`, magicword branch — null/empty/wrong word never falls
  back to uid). The outer `catch` returns `GeneralFailure('Repack failed: $e')`
  and `_rollbackMagicWord(oldWord)` clears the just-set word → user sees the red
  error and the word appears unsaved. This is exactly the user's repro.

- **Correct behavior.** Setting a magic word is NOT a restore. The intent is to
  encrypt the user's CURRENT LOCAL data under the new word and overwrite the
  cloud copy. `backup({bool force})` in the same file already does precisely
  this: gathers local contacts/profile/settings, zips, encrypts via
  `_encryptForUpload` (which reads the stored magic word → magicword mode),
  resolves the SecBizCard folderId, creates-in-folder or updates-in-place,
  runs migrate-then-delete of the legacy root file, and marks backed-up. The
  `sourceId == null` branch of `setMagicWordAndRepack` already delegates to
  `backup(force: true)`. So the fix is to make the WHOLE method delegate to
  `backup(force: true)` after storing the word, and delete the
  download+decrypt+re-encrypt+upload path.

- **`force: true` is required.** `backup()`'s non-force path has a
  cloud-newer-than-local guard (`BackupConflictFailure`). The user explicitly
  chose to set a word and overwrite, so we must pass `force: true` to bypass it
  (matches the existing no-cloud-file branch).

- **Rollback safety is kept.** Capture `oldWord`, store the new word, then on
  any failure of `backup(force: true)` call `_rollbackMagicWord(oldWord)` and
  surface the failure. This is the same shape the current `sourceId == null`
  branch already uses.

- **Helper dead-code check (resolved by code read).** `_migrateDeleteRootIfSafe`
  and `_isReadableBackup` are STILL called by `backup()` (step 6.5 of
  `backup()` calls `_migrateDeleteRootIfSafe`, which calls `_isReadableBackup`).
  After the rewrite they are no longer called from `setMagicWordAndRepack`, but
  they remain live via `backup()`. KEEP BOTH. Do not delete them.

- **Readback correctness (already correct).** `_isReadableBackup` reads the word
  fresh via `await _magicWordService.getMagicWord()` and `_encryptForUpload`
  does the same. Since the new word is STORED before `backup(force: true)` runs,
  both the encrypt and the migrate readback use the new word. No change needed;
  do not over-engineer.

- **Imports.** After removing the decrypt/re-encrypt/upload/temp-file logic from
  `setMagicWordAndRepack`, `backup()` and `restore()` still use `dart:io`,
  `archive`, `path_provider`, `BackupCodec`, etc. Do NOT remove any imports
  without confirming no remaining usage — expect NO import removals, but run
  `fvm flutter analyze` to catch any now-unused import and remove only those it
  flags.

## Steps

- [ ] 1. Rewrite `setMagicWordAndRepack(String word)` in
      `lib/core/services/backup_service.dart` to delegate to
      `backup(force: true)` instead of downloading/decrypting the old cloud
      file.
      Keep, in order: get `user` / guard `AuthFailure`; capture `oldWord` via
      `_magicWordService.getMagicWord()` (keep its try/catch →
      `GeneralFailure('Could not read current magic word: $e')`); validate+store
      the new word via `_magicWordService.setMagicWord(word)` (keep the
      `MagicWordValidationFailure` passthrough and the generic
      `GeneralFailure('Could not store magic word: $e')`).
      Then REPLACE the entire body currently inside the final `try { ... }
      catch (e) { ... }` (the `folderId`/`inFolderId`/`rootId`/`sourceId`
      lookups, the `sourceId == null` early backup branch, `downloadFile`,
      `_codec.decrypt(bytes, uid, oldWord)`, `_codec.encryptNew(...)`, temp-file
      write, `uploadBackup`, the `uploadResult.fold` with its
      `_migrateDeleteRootIfSafe` + `markBackedUp` block, and the trailing
      `catch` that rolls back and returns `GeneralFailure('Repack failed: $e')`)
      with a single delegation:
      ```dart
      final backupResult = await backup(force: true);
      return backupResult.fold(
        (l) async {
          await _rollbackMagicWord(oldWord);
          return left(l);
        },
        (_) => right(null),
      );
      ```
      The method no longer references `uid` after this change — remove the now
      unused `final uid = user.uid;` line (keep the `user == null` guard). Update
      the doc comment above the method to describe the new behavior (packs LOCAL
      data under the new word via `backup(force:true)` and overwrites the cloud
      copy; never decrypts the old cloud file; rolls the word back on failure).
      Leave `_migrateDeleteRootIfSafe`, `_isReadableBackup`, `_rollbackMagicWord`,
      `backup`, `_encryptForUpload`, and all other members unchanged.
      Files: lib/core/services/backup_service.dart
      Verify: `cd /Users/jack/_Projects/SecBizCard-Apps/.worktrees/fix-repack-overwrite && fvm flutter analyze` — no NEW issues beyond the documented baseline of 5 pre-existing (gitignored firebase_options.dart + 3 unrelated test warnings). No `@riverpod` providers changed, so build_runner is NOT required.

- [ ] 2. Add a regression test in
      `test/unit/services/backup_service_test.dart` proving the user's repro is
      fixed: an existing cloud file encrypted under a DIFFERENT/undecryptable
      magic word still succeeds because the repack now packs from LOCAL data.
      Add a new `test(...)` inside the `group('BackupService Test', ...)` block,
      following the existing `FakeDriveRepository` / `FakeMagicWordService`
      patterns. Steps inside the test:
      - Stub local data: `when(mockContactsRepo.getSavedContacts()).thenAnswer((_) async => right([<one UserProfile>]));`
        (required because `backup(force:true)` packs from local contacts). Also
        `when(mockContactsRepo.saveContactLocally(any)).thenAnswer((_) async => right(null));` is not needed here (no restore).
      - Seed an in-folder cloud file encrypted with a magic word the device does
        NOT have: build a zip with `data.json`, `codec.encryptNew(zipBytes,
        encMode: BackupCodec.encModeMagicWord, keySource: 'otherdeviceword')`,
        then `fakeDriveRepo.seedFile('folder_backup_id', otherBytes,
        parentFolderId: FakeDriveRepository.folderId);`. Do NOT set any local
        magic word before the call (so `oldWord` is null — cannot decrypt the
        seeded magicword file; this is the exact failing precondition).
      - Act: `final result = await service.setMagicWordAndRepack('mysecretword');`
      - Assert `result.isRight()` is true (reason: `result.fold((l) => l.message, (r) => '')`), and crucially assert the failure is NOT a wrong-word error — e.g. `result.fold((l) => fail('must not fail: $l'), (_) {});` so a `WrongMagicWordFailure` regression fails loudly.
      - Assert the word is stored: `expect(await fakeMagicWord.getMagicWord(), 'mysecretword');`
      - Assert the overwritten in-folder file is now magicword mode and decrypts
        with the NEW word only: read `fakeDriveRepo.bytesOf('folder_backup_id')`,
        `codec.readHeaderOrNull(repacked)!.encMode == BackupCodec.encModeMagicWord`,
        `codec.decrypt(repacked, uid: uid, magicWord: 'mysecretword')` yields an
        archive with `data.json`, and the local contact's `displayName` round-trips.
      Files: test/unit/services/backup_service_test.dart
      Verify: `cd /Users/jack/_Projects/SecBizCard-Apps/.worktrees/fix-repack-overwrite && fvm flutter test test/unit/services/backup_service_test.dart` — the new test passes.

- [ ] 3. Keep the existing `setMagicWordAndRepack` tests green, adjusting ONLY
      the stubs/assertions whose call shape changed under delegation (preserve
      each test's intent). Because the method now runs `backup(force:true)`,
      which packs from local contacts, every existing `setMagicWordAndRepack`
      test that did NOT stub `getSavedContacts()` must add
      `when(mockContactsRepo.getSavedContacts()).thenAnswer((_) async => right(<UserProfile>[]));`
      Specifically review these existing tests:
      - "setMagicWordAndRepack repacks a uid file into magicword mode" (seeds a
        ROOT-only file): add the `getSavedContacts()` stub. The create-in-folder
        + `lastUploadExistingFileId == null` + `lastUploadParentFolderId ==
        folderId` + magicword-mode + `deleted contains 'root_backup_id'`
        assertions remain valid because `backup()` performs the same
        create-in-folder and migrate-then-delete. NOTE: the file content now
        comes from local data (empty contacts) rather than the seeded root
        file's decrypted ZIP — that is the intended behavior; keep the
        header/encMode/decrypt-with-new-word assertions, which still hold.
      - "setMagicWordAndRepack updates the IN-FOLDER file in place when one
        exists": add the `getSavedContacts()` stub. `backup()` finds the
        in-folder file via `searchBackupFile(parentFolderId: folderId)` and
        updates it in place, so `lastUploadExistingFileId == 'folder_backup_id'`
        still holds.
      - "setMagicWordAndRepack with a root file keeps root until new home reads
        back" (`uploadShouldFail = true`): add the `getSavedContacts()` stub.
        `backup()` returns a left on upload failure, the delegation rolls the
        word back and returns left, so `result.isLeft()`, `deleted isEmpty`, and
        `hasFileWithParent('root_backup_id', null)` still hold. Additionally
        assert the word was rolled back: `expect(await fakeMagicWord.getMagicWord(), isNull);`
      - "setMagicWordAndRepack writes an initial magicword backup when no cloud
        file exists": already stubs `getSavedContacts()`; behavior is unchanged
        (now reached via the same `backup(force:true)` for all cases). Leave as
        is.
      Files: test/unit/services/backup_service_test.dart
      Verify: `cd /Users/jack/_Projects/SecBizCard-Apps/.worktrees/fix-repack-overwrite && fvm flutter test test/unit/services/backup_service_test.dart` — all tests in the file pass.

- [ ] 4. Full-suite verification and clean analyze.
      Run the whole unit suite plus analyze to confirm no regressions elsewhere
      and no new analyzer issues.
      Files: (none — verification only)
      Verify:
      - `cd /Users/jack/_Projects/SecBizCard-Apps/.worktrees/fix-repack-overwrite && fvm flutter analyze` → no NEW issues beyond the baseline of 5 pre-existing.
      - `cd /Users/jack/_Projects/SecBizCard-Apps/.worktrees/fix-repack-overwrite && fvm flutter test` → all tests pass.
      - If any widget/l10n test complains about generated localizations, run `fvm flutter gen-l10n` first, then re-run `fvm flutter test`.

## Out of scope / guardrails

- Do NOT bump the app version (pubspec `version:` stays at 1.6.2+185).
- Do NOT create git tags; do NOT push.
- Do NOT run `dart run build_runner build` unless an `@riverpod` provider is
  changed — this fix changes no providers.
- Do NOT delete `_migrateDeleteRootIfSafe` / `_isReadableBackup`; they remain
  used by `backup()`.
- Commit locally on the worktree branch only.
