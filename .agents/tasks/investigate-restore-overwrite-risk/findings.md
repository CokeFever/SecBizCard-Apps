# Findings: Restore-vs-Overwrite data-loss risk (magic word / reinstall)

Status: READ-ONLY investigation. No code was changed.
Scope: `backup_service.dart`, `backup_codec.dart`, `backup_screen.dart`, `magic_word_service.dart`.

---

## Summary answer (the short version)

Yes — the user's concern is real and the data-loss path exists today.

- **The RESTORE flow is safe.** `restore()` only searches, downloads and decrypts the
  cloud file; it never uploads or overwrites it. When the cloud file is `magicword`
  mode and no local word is stored, decryption throws `WrongMagicWordFailure`, the UI
  prompts for the word, stores it, and retries restore. No write to Drive happens
  anywhere in the restore path.

- **The SET MAGIC WORD flow is dangerous after a reinstall.** `setMagicWordAndRepack()`
  always ends by writing a cloud file. In the specific reinstall case where the cloud
  backup is in `magicword` mode but the LOCAL word is absent, the repack-decrypt uses
  the newly-entered word (its `oldWord` is `null`), so one of two bad things happens:
  (a) if the entered word matches, it re-encrypts the SAME cloud bytes — harmless; or
  (b) **if the cloud file is NOT actually present as a readable in-folder/root source,
  the code falls into the `sourceId == null` branch and runs `backup(force: true)`,
  which packs the EMPTY local data and OVERWRITES the cloud copy.** There is **no
  empty-local-data guard** anywhere, and `force: true` **bypasses** the cloud-newer
  conflict guard.

- **The screen does mildly steer the user toward the wrong button.** When there is no
  remote backup detected (or while checking), the "Restore" button is **disabled**, so
  a user whose only visible actionable control is "Set Magic Word" / "Back Up Now" can
  easily set the word first — which is exactly what the user reported doing.

The user's own workaround in message #4 (deleting the stale local zip, then re-setting
the word) succeeded precisely because it removed the broken/partial state that was
making the first repack fail.

---

## Evidence

### 1. RESTORE path is strictly read-only w.r.t. the cloud file

`restore()` — `lib/core/services/backup_service.dart:382`:

- It resolves the folder, then **searches** for the file (`searchBackupFile`, new home
  then legacy root) and **downloads** it (`downloadFile`). There is no `uploadBackup`,
  `deleteFile`, or any write call in the entire method body (lines 382–560). The only
  writes are to the LOCAL filesystem (restored images under
  `getApplicationDocumentsDirectory()`) and local repos/prefs.

- Decryption routing (`backup_service.dart` ~line 420):
  ```dart
  final magicWord = await _magicWordService.getMagicWord();
  decryptedBytes = await _codec.decrypt(bytes, uid: uid, magicWord: magicWord);
  ```
  When the file is `magicword` mode and `magicWord` is `null`/empty, the codec throws
  `WrongMagicWordFailure` (never a uid fallback):

  `backup_codec.dart` (`decrypt`, encMode==magicword branch):
  ```dart
  if (magicWord == null || magicWord.isEmpty) {
    throw const WrongMagicWordFailure('Magic word required for this backup');
  }
  ```
  and a wrong word surfaces as `WrongMagicWordFailure` from `_decryptGcm`
  (`SecretBoxAuthenticationError` → `WrongMagicWordFailure` when `magicWordMode`).

- UI handling — `_performRestore()` at `backup_screen.dart:176`, failure branch at
  `backup_screen.dart:216`:
  ```dart
  if (l is WrongMagicWordFailure) {
    final retried = await _promptMagicWordAndRetryRestore();
    if (retried) return;
  }
  ```

- `_promptMagicWordAndRetryRestore()` — `backup_screen.dart:248`:
  - calls `_askForMagicWord()` (prompt dialog), using l10n keys
    `magicWordRestorePromptTitle`, `magicWordRestorePromptBody`,
    `magicWordEnterLabel`, `commonContinue`, `commonCancel`;
  - stores the entered word via `magicWordServiceProvider.setMagicWord(word)`;
  - calls `service.restore()` **again** (another read-only decrypt+download);
  - on a second `WrongMagicWordFailure` it **clears** the stored word again
    (`backup_screen.dart:276`) and shows `magicWordRestoreWrong`.

  **Conclusion for Q1:** Restore is strictly read-only against Drive. The magic-word
  prompt is correctly scoped to the restore flow, passes the word in, and retries
  decryption without ever uploading. This part is correct and safe.

### 2. SET MAGIC WORD path always writes a cloud file

Entry: "Set Magic Word" / "Change" button → `_openSetMagicWordDialog()`
(`backup_screen.dart:563` wires the button; dialog at `backup_screen.dart:675`) →
`_applyMagicWord(word)` → `service.setMagicWordAndRepack(word)`.

`setMagicWordAndRepack()` — `backup_service.dart:564`:

1. Captures `oldWord = await _magicWordService.getMagicWord()`. **After a reinstall the
   local word is absent, so `oldWord == null`.**
2. Stores the new word (`setMagicWord(word)`).
3. Looks for a source cloud file: `inFolderId` (in SecBizCard folder) then `rootId`
   (legacy root), `sourceId = inFolderId ?? rootId`.
4. **If `sourceId == null`** (`backup_service.dart:619`):
   ```dart
   if (sourceId == null) {
     final backupResult = await backup(force: true);   // backup_service.dart:620
     ...
   }
   ```
   → this packs LOCAL data and uploads with `force: true`. **This is the overwrite.**
5. If a source IS found, it downloads, decrypts with `oldWord` (= the just-entered word
   when `oldWord` was null — note the decrypt uses `magicWord: oldWord`), re-encrypts
   with the new word, and `uploadBackup(...)` writes it back
   (`backup_service.dart`, the `uploadResult = await _driveRepo.uploadBackup(...)` call
   in the repack path). This is also a cloud write.

**Conclusion for Q2:** Setting a magic word ALWAYS ends in a cloud write — either the
repack-upload (source found) or `backup(force:true)` (no source found). The dangerous
overwrite-with-empty-data is specifically the `sourceId == null` → `backup(force:true)`
branch at `backup_service.dart:619-620`.

### 3. No empty-local-data guard anywhere

- `backup()` (`backup_service.dart:98`) gathers contacts (`getSavedContacts()`) and
  profile and packs them **unconditionally**. There is no check for
  `contacts.isEmpty && profile == null` before building/encrypting/uploading. Searched
  the file: no `isEmpty`-based abort, no "nothing to back up" early return.
- `setMagicWordAndRepack()` likewise has no empty-data check before calling
  `backup(force: true)`.

**Conclusion for Q3:** No empty-data guard exists in either `backup()` or
`setMagicWordAndRepack()`. A backup of 0 contacts + no profile is a valid, uploadable
archive (it still contains `data.json` with empty `contacts`), so it will cleanly
overwrite a rich cloud backup.

### 4. The screen steers a reinstalled user toward "Set Magic Word"

- The **Restore** button is disabled whenever there is no detected remote backup or
  while checking — `backup_screen.dart:496`:
  ```dart
  onPressed: _isLoading || _checkingBackup || !_hasRemoteBackup ? null : _performRestore,
  ```
  Its label flips to `backupNoBackupFound` when `_hasRemoteBackup == false`.
  `_hasRemoteBackup` comes from `hasBackup()` (`backup_service.dart`), which only checks
  for file EXISTENCE, not decryptability. So if detection flaps or the file lives only
  in root under certain conditions, Restore can appear unavailable.
- Meanwhile **"Back Up Now"** (`backup_screen.dart:481`, always enabled unless loading)
  and the **Set / Change Magic Word** button (`backup_screen.dart:563`, always enabled
  unless loading) remain actionable.
- The magic-word section description (`magicWordSectionDescNone` /
  `magicWordSectionDescSet`) and the set-dialog warning (`magicWordForgetWarning`) talk
  about privacy/irreversibility, **not** about the risk of overwriting an existing
  cloud backup. Nothing on screen warns "you have a cloud backup you haven't restored
  yet — restore before you back up or set a word."

**Conclusion for Q4:** Button ordering + the enable/label logic can present "Set Magic
Word" / "Back Up Now" as the only live actions to a freshly reinstalled user, and no
copy warns that acting on them overwrites the un-restored cloud backup. This matches the
user's reported sequence.

### 5. The cloud-newer conflict guard does NOT help the reinstall case

Guard in `backup()` — `backup_service.dart:119-137`:
```dart
if (!force) {
  ... cloudTime ...
  final localModified = await BackupReminderService().lastModifiedAt();
  final cloudIsNewer = localModified == null || cloudTime.isAfter(localModified);
  if (cloudIsNewer) return left(BackupConflictFailure(...));
}
```

Two independent reasons it provides no protection here:

1. **It is gated on `!force`.** The repack path calls `backup(force: true)`
   (`backup_service.dart:620`), so the entire guard block is skipped.
2. **Even on a plain `_performBackup()` (force=false), it would TRIGGER but not
   protect well.** After reinstall `localModified == null`, so `cloudIsNewer` is true
   and `BackupConflictFailure` is raised — the UI then shows
   `_confirmOverwriteNewerBackup` (`backup_screen.dart`) which offers an **"Overwrite"**
   button. One tap of Overwrite re-invokes `_performBackup(force: true)` and destroys
   the cloud backup. So the guard degrades into a single confirmable dialog, and in the
   repack path it is bypassed entirely.

**Conclusion for Q5:** The conflict guard is bypassed in the repack path (`force:true`)
and, in the direct-backup path, is reduced to a one-tap-overwrite confirmation because
`localModified` is null after reinstall.

---

## Exact tap sequences

### DESTRUCTIVE sequence (what the user hit)
1. Reinstall / re-login → local word cleared, local contacts/profile empty; cloud holds
   a `magicword` backup.
2. Open Backup & Restore. "Restore" may be disabled/labelled "No backup found", or the
   user is drawn to the lock section.
3. Tap **Set Magic Word**, enter the word, tap Continue.
4. `setMagicWordAndRepack()` runs. If no readable source file is resolved
   (`sourceId == null`), it calls `backup(force: true)` → packs EMPTY local data →
   **overwrites the cloud backup**. (If a source IS resolved and the word matches, the
   same bytes are re-written — not destructive; the destructive case is the
   `sourceId == null` branch.)

Alternative destructive sequence:
3b. Tap **Back Up Now** → `BackupConflictFailure` → dialog → tap **Overwrite** →
    `_performBackup(force:true)` → empty local data overwrites cloud.

### SAFE sequence
1. Reinstall / re-login.
2. Open Backup & Restore, tap **Restore from Backup**.
3. Restore detects `magicword` mode, prompts for the word, stores it, retries decrypt,
   writes data LOCALLY. Cloud file is untouched. **Then** the user may back up.

The destructive and safe sequences differ only by which button is tapped first, and the
UI currently makes the destructive button easier to reach after a reinstall.

---

## Fix options (analysis only — not implemented)

**(a) Empty-local-data guard before ANY cloud overwrite.** In `backup()`, if
`contacts.isEmpty && profile == null`, abort with a dedicated failure (e.g.
`EmptyBackupFailure`) UNLESS the caller passes an explicit `allowEmpty` flag. This is
the smallest, highest-value guard — it directly blocks "empty data clobbers rich cloud
backup" regardless of entry point (`backup`, `setMagicWordAndRepack`, Overwrite dialog).
Tradeoff: must allow a legitimate "I really do have zero contacts" backup via explicit
confirmation.

**(b) Decouple "set magic word" from "auto-overwrite".** `setMagicWordAndRepack` should
only re-encrypt an EXISTING readable cloud file (repack-in-place). Remove the
`sourceId == null → backup(force:true)` branch (`backup_service.dart:619-620`); when
there is no cloud file, just store the word and let the next explicit "Back Up Now"
create it. This removes the exact branch that packs empty data.

**(c) Keep the magic-word prompt confined to the restore flow (already true) and add a
guard that a user with an un-restored cloud backup is warned before set/backup.**
Detect "cloud has a backup AND local data is empty AND local word absent" (a
fresh-install signature) and, before any overwrite, show a blocking dialog that steers
to Restore first.

**(d) Make "Restore" the primary, always-reachable action after reinstall.** Base the
Restore button's enabled state on `hasBackup()` existence (not decryptability) and
visually prioritize it; downrank/disable "Back Up Now" and "Set Magic Word" while a
cloud backup exists but local data is empty. Also add copy to the magic-word section
explaining the overwrite risk.

**Recommended combination:** (a) + (b) as the core safety net (defense in depth: even if
UI steering fails, empty data can never overwrite a real backup, and setting a word
never auto-creates/overwrites), plus (d) for the UX that prevents users from reaching
the destructive path at all.

---

## Notes / assumptions

- Per the brief, `setMagicWordAndRepack` is being refactored elsewhere to delegate to
  `backup(force:true)`. That refactor makes fix (a) even more important, because then
  BOTH "set magic word" and "back up" funnel through the same unguarded `backup()`
  overwrite — a single empty-data guard in `backup()` would cover both.
- `hasBackup()` checks existence only, so the Restore button's availability is not a
  reliable signal of "restorable"; this is relevant to fix option (d).
