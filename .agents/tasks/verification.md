# Verification — 1.6.3+188 (backup conflict-guard + Save-to-Google lag)

Branch: `fix/backup-conflict-contacts-ux`
Flutter: 3.38.9 via fvm (pinned per CI/CD ground truth).

## Workspace used

Commands were run **in the worktree**
`/Users/jack/_Projects/SecBizCard-Apps/.worktrees/backup-conflict-contacts-ux`.

The worktree could NOT run `fvm flutter pub get` out of the box: `pubspec.yaml`
declares `SecBizCard_OCR` as a git SSH dependency
(`git@github.com:CokeFever/SecBizCard.git`), and the git clone fails with
`Permission denied (publickey)` in this environment. The main workspace resolves
it via a **gitignored** `pubspec_overrides.yaml` that points `SecBizCard_OCR` at
the local path `../SecBizCard/packages/SecBizCard_OCR`; that override file does
not exist in a freshly-created worktree.

To make the worktree self-consistent WITHOUT touching tracked files, two
local-only (uncommitted, environment-level) aids were created:

1. Symlink `.worktrees/SecBizCard -> /Users/jack/_Projects/SecBizCard` so the
   worktree-relative path `../SecBizCard/packages/SecBizCard_OCR` resolves
   (the symlink lives OUTSIDE the worktree, so it is not part of the branch).
2. `.worktrees/backup-conflict-contacts-ux/pubspec_overrides.yaml` mirroring the
   main workspace's override (this file is **gitignored** — it is not committed,
   matching the main workspace's own setup; CI still uses the git SSH dep).

Generated code (freezed/json_serializable/riverpod `*.g.dart`/`*.freezed.dart`
and `firebase_options.dart`) is gitignored and absent from a fresh worktree, so
`fvm dart run build_runner build --delete-conflicting-outputs` was run once to
generate it before analyze/test. `firebase_options.dart` is NOT produced by
build_runner (it is a FlutterFire-generated, gitignored file), so it remains
absent — this is the source of the 2 pre-existing baseline analyze errors below.

## Commands & outcomes

### `fvm flutter gen-l10n`
Clean. Regenerated `lib/generated/l10n/app_localizations*.dart`; the new
`String mainExportingProgress(int done, int total)` resolves in all 5 locales
(en, zh, zh_TW, ja, ko) and in `main_screen.dart`.

### `fvm flutter analyze`
`5 issues found.` — ALL pre-existing baseline, NO new issues:

- `error • Target of URI doesn't exist: 'firebase_options.dart' • lib/main.dart:15:8`
  (gitignored generated file, absent in fresh worktree — baseline)
- `error • Undefined name 'DefaultFirebaseOptions' • lib/main.dart:52:16`
  (same root cause — baseline)
- `warning • unnecessary_non_null_assertion • test/unit/services/zip_import_service_test.dart:36:38`
- `warning • unnecessary_non_null_assertion • test/unit/services/zip_import_service_test.dart:160:45`
- `warning • unnecessary_non_null_assertion • test/unit/services/zip_import_service_test.dart:215:45`

These match the baseline named in the plan (`unnecessary_non_null_assertion` in
`zip_import_service_test` + `firebase_options`). The transient
`use_build_context_synchronously` infos that appeared in an intermediate run
from the new single-contact dialog code were eliminated by capturing
`ScaffoldMessenger`/`Navigator` before the async gap and adding a `mounted`
guard — the final analyze shows none.

### `fvm flutter test test/unit`
`00:13 +158: All tests passed!`

~154 prior tests + the 4 new conflict-guard cases in
`test/unit/services/backup_service_test.dart` group
`backup() conflict guard (last-backup based)`:
- (a) same-device re-backup, no data change (cloudTime ≈ lastBackup) → NO conflict, uploads
- (b) another device wrote cloud AFTER our last backup → conflict, no upload
- (c) fresh device, never backed up, cloud exists → conflict
- (d) force: true bypasses the conflict guard, uploads

## On-device verification

NOT performed. Per the task note, a debug build uses an unregistered keystore
SHA-1 (ApiException 10) so Save-to-Google can't be exercised on-device from a
debug build; a release build would be needed. No on-device claims are made here.
The FIX 2 behavior (immediate persistent progress dialog, re-entrancy guard,
live n/total counter) is covered by the analyze pass and the service-level
`onProgress` threading; manual device QA remains pending for the release build.
