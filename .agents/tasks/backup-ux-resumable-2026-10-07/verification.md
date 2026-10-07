# Verification — Backup/Restore UX & Reliability (A1 + A2 + B + C)

Worktree: `/Users/jack/_Projects/SecBizCard-Apps/.worktrees/backup-ux-resumable`
Branch: `feat/backup-ux-resumable`
Flutter: 3.38.9 via fvm (pinned). All commands run with `fvm flutter …`.
Date: 2026-10-07

## Environment blocker (Step 0) — RESOLVED

`fvm flutter pub get` in the worktree initially failed: `pubspec.yaml` declares
the OCR package as a git SSH dependency (`git@github.com:CokeFever/SecBizCard.git`)
and there is no SSH/deploy key in this environment (`Permission denied (publickey)`).

Root cause (confirmed): the main workspace resolves OCR via an **untracked,
gitignored** `pubspec_overrides.yaml` that points OCR at a local path
(`../SecBizCard/packages/SecBizCard_OCR`). The worktree had no such override, so
pub tried to clone the git URL.

Fix applied in the worktree (NOT committed — both are gitignored / local-only):
1. Symlinked the real OCR checkout so the relative path resolves from the
   worktree parent:
   `/Users/jack/_Projects/SecBizCard-Apps/.worktrees/SecBizCard -> /Users/jack/_Projects/SecBizCard`
2. Created `pubspec_overrides.yaml` in the worktree identical to the main
   workspace's (`dependency_overrides: SecBizCard_OCR: path: ../SecBizCard/packages/SecBizCard_OCR`).

After that, `fvm flutter pub get` → "Got dependencies!" and
`.dart_tool/package_config.json` exists. `pubspec.yaml` / `pubspec.lock` were
NOT modified; the git dependency pin is intact (CI still uses the SSH dep).

A `build_runner build --delete-conflicting-outputs` was then run to generate the
missing `*.g.dart` (riverpod/freezed/json/mockito) — without it analyze reports
~797 phantom "undefined provider / uri not generated" errors. These are codegen
artifacts, not committed, and not real issues.

## Results

### 1. `fvm flutter gen-l10n` — CLEAN
No missing-translation errors. New getters generated for all 5 locales
(en, zh-TW, zh-CN, ja, ko). Note: zh-TW is emitted inside
`app_localizations_zh.dart` as the `zh_TW` variant (verified the Traditional
Chinese strings are present, e.g. `backupErrorInterrupted => '備份上傳中斷了…'`).

### 2. `fvm flutter analyze` — NO NEW ISSUES
`5 issues found` — identical to the pre-change baseline:
- `lib/main.dart:15` + `:52` — `firebase_options.dart` missing (gitignored
  secret, absent from the worktree; present in the main workspace).
- `test/unit/services/zip_import_service_test.dart:36 / :160 / :215` — 3
  pre-existing `unnecessary_non_null_assertion` warnings.

Baseline was captured before any edit (same 5). The new/changed files
(`backup_error_mapper.dart`, `backup_phase.dart`, `drive_repository.dart`,
`backup_service.dart`, `backup_screen.dart`, `failure.dart`, the arb files, and
`backup_error_mapper_test.dart`) introduce ZERO new analyzer issues.

### 3. `fvm flutter test test/unit` — GREEN
`All tests passed!` — **154 tests** (baseline 139 + 15 new).
New file: `test/unit/services/backup_error_mapper_test.dart` (15 tests) covering:
- interrupted mid-transfer: `ClientException` contentLength mismatch, connection
  reset, connection closed, broken pipe, `TimeoutException` → `InterruptedTransferFailure`
- offline: failed host lookup / network unreachable / connection refused →
  `ConnectionFailure('offline')`
- Drive auth: `DetailedApiRequestError` 401/403 and "insufficient authentication
  scopes" → `AuthFailure('backup_auth')`
- generic fallback (unknown error, HTTP 500) → `GeneralFailure('backup_generic')`
- passthrough: an already-typed `Failure` (WrongMagicWord/Empty) returned unchanged

The existing `backup_service_test.dart` (16 tests) still passes unchanged — the
new `onPhase` params default to null so existing callers/mocks are unaffected,
and `DriveRepository`'s PUBLIC signature did not change (only HOW bytes upload),
so no mock regeneration was needed.

### 4. `fvm flutter build apk --debug` — SUCCESS
`✓ Built build/app/outputs/flutter-apk/app-debug.apk` (315 MB).
Path: `/Users/jack/_Projects/SecBizCard-Apps/.worktrees/backup-ux-resumable/build/app/outputs/flutter-apk/app-debug.apk`

To build, two gitignored secret files were TEMPORARILY copied from the main
workspace into the worktree, then REMOVED after the build (confirmed absent from
`git status`): `lib/firebase_options.dart` and `android/app/google-services.json`.
They are gitignored and were never committed.

**On-device verification caveat (per brief):** the local debug keystore SHA-1 is
not registered, so Google Sign-In fails with `ApiException: 10` on debug builds.
Real end-to-end backup/restore (resumable upload, friendly errors on a flaky
network) CANNOT be verified from this debug APK and must be verified on a
release build later on the Pixel 9 Pro. No on-device backup success is claimed
from this debug build.

## What changed (summary)

- **A1** `backup_screen.dart`: a single `_opInProgress` re-entrancy guard set at
  the VERY FIRST line of the public `_performBackup`/`_performRestore` (before any
  cloud check or confirm dialog), released in a `finally` on BOTH success and
  failure. Backup shows "Preparing…" immediately on tap. Both buttons also gate
  `onPressed` on `_opInProgress`. The conflict→force retry runs INSIDE the same
  guarded session via a private `_runBackup`, so no concurrent op can slip in.
- **A2** real phase hooks: optional `void Function(BackupPhase)? onPhase` added
  to `BackupService.backup()`/`restore()` (default null → existing callers
  unaffected), called at the real work boundaries (gather/zip → encrypt → upload;
  download → decrypt → unzip/write). UI maps them to localized
  "Preparing…/Encrypting…/Uploading…/Downloading…/Decrypting…/Restoring…".
- **B** `drive_repository.dart`: `uploadBackup` now passes
  `drive.ResumableUploadOptions(numberOfAttempts: 5, chunkSize: 1024*1024)` to
  BOTH `files.create` and `files.update` (googleapis 15.0.0). Pure transport
  change — same `Media(file.openRead(), length)`, same find/folder/fileId/
  addParents/removeParents logic, same method signature. Backup byte format
  (BackupCodec/SBCB, magic-word) untouched.
- **C** `backup_error_mapper.dart` (new pure, unit-tested `mapBackupError`):
  classifies transport errors into typed failures. Wired in `drive_repository`
  (`uploadBackup` + `downloadFile`) and `backup_service` (both outer catches),
  and the UI selects localized copy by failure TYPE — the user never sees raw
  `ClientException`/`PlatformException`/`DetailedApiRequestError` text from
  backup/restore. Strings added to all 5 locales.

## Guardrails confirmed
- `lib/features/auth/data/auth_repository.dart` — UNTOUCHED (git status empty).
- `lib/core/services/backup_codec.dart` — UNTOUCHED. SBCB/magic-word/format and
  the SecBizCard-folder / `ixo_app_backup.zip` find/migrate logic unchanged.
- No new hardcoded user-facing strings; every new string exists in all 5 arb
  files.
- The only remaining `l.message` in `backup_screen.dart` is in
  `_applyMagicWord` (local set-magic-word store, NOT a backup/restore transport
  path) and is pre-existing / out of scope.
