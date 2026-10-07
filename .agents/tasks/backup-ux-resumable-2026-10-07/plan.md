# Implementation Plan — Backup/Restore UX & Reliability (A1 + A2 + B + C)

Worktree (ALL paths relative to it): `/Users/jack/_Projects/SecBizCard-Apps/.worktrees/backup-ux-resumable`
Branch: `feat/backup-ux-resumable`. Flutter is pinned to 3.38.9 via fvm — **always `fvm flutter …`, never bare `flutter`/stable**.

## Context discovered during exploration (read before starting)

- **A1/A2 UI** lives in `lib/features/settings/presentation/screens/backup_screen.dart`
  (`_BackupScreenState`). It already has an `_isLoading` flag and sets a staged
  `_statusMessage`, but the button handlers (`_performBackup`, `_performRestore`)
  do pre-flight async work (dialogs, `cloudIsMagicWordProtected()`,
  `cloudBackupModifiedTime()`, `hasMagicWord()`) **before** `_isLoading` is set
  true. That pre-flight is where the "tap feels dead" lag lives. Buttons are
  gated on `_isLoading || …` for `onPressed`, but there is NO re-entrancy guard
  covering the pre-flight window, so a second tap during pre-flight can start a
  second operation. The in-screen status card already switches to a spinner +
  `_statusMessage` text when `_isLoading` is true (good foundation for A2).
- **A2 phases** map to `BackupService.backup()` in `lib/core/services/backup_service.dart`:
  (1) gather contacts/profile + zip (`Archive`/`ZipEncoder`), (2) encrypt
  (`_encryptForUpload` → `BackupCodec.encryptNew`), (3) upload
  (`_driveRepo.uploadBackup`). `restore()` phases: download → decrypt → unzip →
  write. BackupService currently exposes NO progress callback. Cleanest
  non-format-affecting hook: add an optional `void Function(BackupPhase)?
  onPhase` param to `backup()`/`restore()` and call it at each boundary. This
  does NOT touch the backup byte format.
- **B (resumable upload)** is `DriveRepository.uploadBackup` in
  `lib/features/storage/data/drive_repository.dart`. Today it builds
  `drive.Media(file.openRead(), await file.length())` and calls
  `files.create`/`files.update` with `uploadMedia:` and the DEFAULT (multipart)
  upload options — this is the `uploadType=multipart` that fails mid-stream.
- **googleapis 15.0.0 resumable API — CONFIRMED available.** `files.create` and
  `files.update` (`drive/v3.dart`) both accept
  `commons.UploadOptions uploadOptions`. `ResumableUploadOptions` is exported
  from `googleapis/drive/v3.dart` and defined in `_discoveryapis_commons-1.0.7`
  (`lib/src/requests.dart`): `ResumableUploadOptions({int numberOfAttempts = 3,
  int chunkSize = 1024*1024, Duration? Function(int) backoffFunction =
  exponentialBackoff})`. It has built-in chunked upload + exponential-backoff
  retry (default 3 attempts/chunk, cap 5). `Media(stream, length, {contentType})`
  — resumable still accepts a known length (we have `await file.length()`), so
  keep passing it. This is a pure TRANSPORT change: same bytes, same temp file,
  same `uploadType` logic for find/folder/fileId stays untouched.
- **C (error mapping) — existing pattern to FOLLOW:**
  - `lib/features/handshake/data/handshake_repository.dart`: top-level pure
    functions `mapFunctionsError(code,msg)` and `mapGenericError(Object e)` that
    return a TYPED `Failure` subclass carrying a stable sentinel string
    (`ConnectionFailure('offline')`), classifying `SocketException` and strings
    like `failed host lookup`/`network is unreachable`/`connection
    refused`/`connection closed`.
  - `lib/features/contacts/data/contacts_repository.dart`: `_mapContactsError`
    returns `AuthFailure(kContactsPermissionDenied)` for 403/insufficient-scope.
  - **UI side**: `lib/features/handshake/presentation/screens/qr_display_screen.dart`
    maps `failure is ConnectionFailure` → a localized string (`l10n.qrErrorOffline`).
    So the convention is: data layer returns a TYPED failure with a sentinel;
    the SCREEN picks the localized string from the failure TYPE, never shows
    `failure.message` raw for known types.
- **Where raw text leaks today**: `BackupService.backup()` wraps any throw as
  `GeneralFailure('Backup failed: $e')` and `restore()` as
  `GeneralFailure('Restore failed: $e')`; `DriveRepository` catches to
  `ServerFailure(e.toString())`. The screen shows `l10n.backupFailed(l.message)`
  / `l10n.backupRestoreFailed(l.message)` — so the raw ClientException text
  reaches the user through `l.message`. Fix by classifying into typed failures
  and selecting localized copy by TYPE in the screen.
- **l10n**: `l10n.yaml` → arb-dir `lib/l10n`, template `app_en.arb`, output
  `lib/generated/l10n/app_localizations.dart`. **Five** arb files:
  `app_en.arb`, `app_zh_TW.arb`, `app_zh.arb` (zh-CN), `app_ja.arb`, `app_ko.arb`.
  Existing backup keys use the `backup*` prefix (`backupCreating`,
  `backupFailed` with `{error}` placeholder, `backupRestoringStatus`, etc.).
  Regenerate with `fvm flutter gen-l10n`.
- **Tests to follow**: `test/unit/handshake_repository_error_mapping_test.dart`
  (pure map-function tests — the model for C) and
  `test/unit/services/backup_service_test.dart` (Riverpod + Mockito +
  fake path provider; `test/unit/test_mocks.mocks.dart` has generated mocks).

### ENVIRONMENT BLOCKER — read first
`fvm flutter pub get` in this worktree currently FAILS: `pubspec.yaml` has a
git dependency `git@github.com:CokeFever/SecBizCard.git` (path
`packages/SecBizCard_OCR`) that needs SSH access (`Permission denied
(publickey)`), and `.dart_tool/` is not yet populated. Until SSH/deploy-key
access is available, `pub get`, `analyze`, `test`, `gen-l10n`, and `build apk`
cannot run. **Step 0 is to resolve this.** If it cannot be resolved in this
environment, implement all code+arb changes exactly per the steps below and
record in the final report that the verification commands are correct but could
not be executed here due to the missing OCR deploy key.

### Guardrails (do NOT cross)
- Do NOT touch `driveGoogleSignIn`/`contactsGoogleSignIn` in
  `lib/features/auth/data/auth_repository.dart` (verified 1.6.3+187 fix).
- Do NOT change the backup byte format: `BackupCodec`/SBCB, magic-word model,
  the `SecBizCard` folder / `ixo_app_backup.zip` name, or the
  find/folder/fileId/migrate logic. B changes only HOW bytes are transported.
- No hardcoded user-facing strings: every new string in all 5 arb files.

---

## Plan

- [ ] 0. Resolve dependencies so verification can run.
      Run `fvm flutter pub get`. If it fails on the `CokeFever/SecBizCard` git
      dependency, obtain/configure the OCR deploy key (SSH) and retry; this is
      the same `OCR_DEPLOY_KEY` the CI pipelines use. Do not alter the git
      dependency pin in `pubspec.yaml`.
      Files: none (environment only).
      Verify: `fvm flutter pub get` completes and `.dart_tool/package_config.json` exists.

- [ ] 1. Capture the analyze + test baseline BEFORE any change.
      Run the analyzer and the full test suite and record the counts so later
      regressions are detectable. Expected baseline per task brief: 5 pre-existing
      analyze infos (ocr_service null-aware assignment + two Share/shareXFiles
      deprecations in contact_detail_screen) and 139 passing tests.
      Files: none.
      Verify: `fvm flutter analyze` → only the 5 known pre-existing infos;
      `fvm flutter test` → all pass (baseline ~139). Note the exact numbers in
      the implementation report.

- [ ] 2. Add a backup/restore phase enum and friendly-error mapping to the core
      error layer. Define `enum BackupPhase { preparing, encrypting, uploading,
      downloading, decrypting, restoring }` (new small file
      `lib/core/services/backup_phase.dart`) and add a `NetworkFailure` typed
      failure (sentinel `'offline'` style, mirroring `ConnectionFailure`) plus a
      pure `Failure mapBackupError(Object e)` helper. `mapBackupError` must
      classify: offline/`SocketException`/`failed host lookup`/`network is
      unreachable`/`connection refused`/`connection closed`/`connection reset`,
      the `ClientException: Content size below specified contentLength` /
      "bytes written but expected" mid-upload drop, and timeouts → a
      network/interrupted failure; Drive auth (`DetailedApiRequestError`
      status 401/403, `insufficient authentication scopes`) → `AuthFailure`
      with a re-auth sentinel; everything else → a generic
      `GeneralFailure('backup_generic')` sentinel. Reuse the existing
      `ConnectionFailure` type if it fits rather than adding a near-duplicate;
      decide and note which. Follow the handshake `mapGenericError` shape
      (top-level pure function, lower-cased string matching).
      Files: `lib/core/errors/failure.dart` (add type if needed),
      `lib/core/services/backup_phase.dart` (new),
      `lib/core/services/backup_error_mapper.dart` (new, or colocate the pure
      function in backup_service.dart — prefer a separate file so it is unit-
      testable like handshake's).
      Verify: `fvm flutter analyze` clean on the new files (added to step 7 tests).

- [ ] 3. Switch `DriveRepository.uploadBackup` to resumable upload (B). In both
      the create and update branches, pass
      `uploadOptions: drive.ResumableUploadOptions(chunkSize: 1024 * 1024,
      numberOfAttempts: 5)` (or tuned constant) to `files.create`/`files.update`
      alongside the existing `uploadMedia: media`. Keep `drive.Media(file.openRead(),
      await file.length())` with its length. Do NOT change the fileId/folder/
      addParents/removeParents logic or the method signature. Also wrap the
      upload body so a thrown transport error is classified via `mapBackupError`
      (step 2) into a typed failure instead of raw `ServerFailure(e.toString())`
      — apply the same mapping in `downloadFile` so restore interruptions are
      friendly too. Confirm `ResumableUploadOptions` is imported from
      `package:googleapis/drive/v3.dart` (already the import alias `drive`).
      Files: `lib/features/storage/data/drive_repository.dart`.
      Verify: `fvm flutter analyze` clean; the backup_service_test still passes
      (it mocks DriveRepository, so transport is unaffected) — confirm in step 7.

- [ ] 4. Thread phase callbacks through `BackupService.backup()` and `restore()`
      (A2 core) and replace raw error wrapping with `mapBackupError`. Add an
      optional `void Function(BackupPhase phase)? onPhase` parameter to both
      methods (default null, so existing callers/tests are unaffected). Call
      `onPhase(BackupPhase.preparing)` at the start of data gather/zip,
      `onPhase(BackupPhase.encrypting)` right before `_encryptForUpload`,
      `onPhase(BackupPhase.uploading)` right before `_driveRepo.uploadBackup`;
      for restore: `downloading` before `downloadFile`, `decrypting` before
      `_codec.decrypt`, `restoring` before the unzip/write loop. In the outer
      `catch (e)` of both methods, return `left(mapBackupError(e))` INSTEAD of
      `GeneralFailure('Backup failed: $e')` / `'Restore failed: $e'`, but keep
      the existing typed early-returns (`AuthFailure`, `EmptyBackupFailure`,
      `BackupConflictFailure`, `WrongMagicWordFailure`, `BackupFormatFailure`)
      exactly as they are. Do NOT alter any zip/encrypt/codec/folder logic.
      Files: `lib/core/services/backup_service.dart`.
      Verify: existing `test/unit/services/backup_service_test.dart` still passes
      (onPhase defaults null); analyze clean.

- [ ] 5. Add the new localized strings to all 5 arb files and regenerate (A2 + C).
      Add keys (names illustrative — keep the `backup`/`backupError` prefix and
      a matching `@key` metadata entry for each, as the file requires):
      `backupPhasePreparing` ("Preparing…"), `backupPhaseEncrypting`
      ("Encrypting…"), `backupPhaseUploading` ("Uploading…"),
      `restorePhaseDownloading`, `restorePhaseDecrypting`, `restorePhaseRestoring`;
      error copy `backupErrorOffline` (no network), `backupErrorInterrupted`
      (upload/connection dropped mid-transfer — maps the contentLength case),
      `backupErrorAuth` (Drive sign-in/permission, re-auth oriented),
      `backupErrorGeneric` ("Backup failed. Please try again."), and the restore
      equivalents if the copy differs (`restoreErrorOffline`, etc. — or reuse the
      backup ones if identical). Provide real translations for en, zh-TW, zh-CN
      (`app_zh.arb`), ja, ko — do NOT leave English placeholders in non-en files.
      Then run `fvm flutter gen-l10n`.
      Files: `lib/l10n/app_en.arb`, `lib/l10n/app_zh_TW.arb`, `lib/l10n/app_zh.arb`,
      `lib/l10n/app_ja.arb`, `lib/l10n/app_ko.arb` (and regenerated
      `lib/generated/l10n/*` — committed).
      Verify: `fvm flutter gen-l10n` succeeds with no missing-translation errors;
      `AppLocalizations` exposes the new getters (confirmed by compile in step 7).

- [ ] 6. Wire the UI: immediate feedback, re-entrancy guard, staged text, and
      typed-error → localized copy (A1 + A2 UI + C UI). In
      `backup_screen.dart`:
      (a) Add an `_opInProgress` bool guard. At the VERY FIRST line of
      `_performBackup` and `_performRestore` (before any dialog or async
      pre-flight), `if (_opInProgress) return;` then
      `setState(() { _opInProgress = true; _isLoading = true; _statusMessage =
      l10n.backupPhasePreparing; _statusIsError = false; });`. Wrap the whole
      body in `try { … } finally { if (mounted) setState(() { _opInProgress =
      false; _isLoading = false; }); }` so the flag/spinner always clear on
      success AND failure. (Keep the existing nested spinner-clearing but ensure
      the finally is the single source of truth for re-enabling.)
      (b) Gate `onPressed` of BOTH the Back Up Now button and the Restore button
      additionally on `_opInProgress` (keep existing `_hasLocalContacts` /
      `_hasRemoteBackup` gates).
      (c) Pass an `onPhase:` callback to `service.backup(onPhase: (p) {
      setState(() => _statusMessage = _phaseLabel(p, l10n)); })` and likewise to
      `service.restore(...)`; add a `_phaseLabel` helper mapping `BackupPhase` →
      the localized strings from step 5.
      (d) In both failure `fold` branches, select the message by failure TYPE
      (NetworkFailure/ConnectionFailure → `backupErrorOffline` or
      `backupErrorInterrupted`; AuthFailure → `backupErrorAuth`;
      WrongMagicWordFailure/BackupConflictFailure/EmptyBackupFailure keep their
      existing dedicated copy; else `backupErrorGeneric`) — NEVER pass
      `l.message` into `backupFailed(...)`/`backupRestoreFailed(...)` for the raw
      network/server cases again.
      Files: `lib/features/settings/presentation/screens/backup_screen.dart`.
      Verify: analyze clean; manual reasoning that first tap shows "Preparing…"
      before zip/encrypt and a second tap is ignored (covered by widget test in
      step 7 if feasible, else documented for device QA on Pixel 9 Pro).

- [ ] 7. Add/extend tests and run the full suite + build. Add
      `test/unit/services/backup_error_mapper_test.dart` modeled on
      `handshake_repository_error_mapping_test.dart`: assert the contentLength
      ClientException string, `SocketException`, connection-reset/closed, and a
      401/403 `DetailedApiRequestError` each map to the expected typed failure,
      and that an unrelated error → generic. If practical, add a widget test for
      the re-entrancy guard (tap twice → one op) under `test/unit/` or
      `test/widget/`. Then run the full verification sequence.
      Files: `test/unit/services/backup_error_mapper_test.dart` (new),
      optional widget test.
      Verify (run all, in order):
      1. `fvm flutter gen-l10n` — succeeds.
      2. `fvm flutter analyze` — only the 5 pre-existing infos remain (no NEW issues).
      3. `fvm flutter test` — all green; count = baseline (139) + new tests.
      4. `fvm flutter build apk --debug` — builds successfully.

- [ ] 8. Final self-review against the guardrails. Diff-review that: the auth
      split in `auth_repository.dart` is untouched; `BackupCodec`/SBCB/magic-word
      and the folder/`ixo_app_backup.zip`/find/migrate logic are byte-identical
      in behavior (only transport changed); no raw `ClientException`/
      `PlatformException`/`DetailedApiRequestError` string can reach the UI from
      backup/restore; all new strings exist in all 5 locales. Confirm a backup
      uploaded via resumable still restores (byte format unchanged) — reason from
      code and, if a device is available, verify on the Pixel 9 Pro.
      Files: none (review).
      Verify: `git diff --stat` touches only the files listed above (plus
      generated l10n); re-run step 7's sequence once more if any fix was made.

## Notes / assumptions
- A2 uses real phase hooks (optional `onPhase` callback) because BackupService
  can expose them cleanly without touching the byte format — preferred over the
  minimum "Preparing… / Uploading…" fallback the brief allows.
- Whether to reuse `ConnectionFailure` or add `NetworkFailure` is left to the
  implementer in step 2; either satisfies C as long as the UI selects localized
  copy by type. Reusing `ConnectionFailure` keeps the type surface smaller.
- The user explicitly flagged the lag and the double-tap on-device; do NOT treat
  A1 as "already fine" from the existing `_isLoading` gate — the gap is the
  async pre-flight before `_isLoading` flips. Implement the guard as specified
  and verify on device.
