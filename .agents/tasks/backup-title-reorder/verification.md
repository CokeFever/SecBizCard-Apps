# Verification — Backup & Restore: web-editor title rename, section reorder, version bump

Worktree: `/Users/jack/_Projects/SecBizCard-Apps/.worktrees/backup-title-reorder`
Branch: `feat/backup-title-reorder`
Flutter: fvm-pinned **3.38.9** (`fvm flutter --version` → `Flutter 3.38.9 • channel stable • revision 67323de285`).

## Environment setup for local analysis/test (NOT committed)

The private git dep `SecBizCard_OCR` (ref pinned in pubspec.yaml) cannot resolve over SSH on
this machine. Created a **gitignored** `pubspec_overrides.yaml` pointing it at the local checkout
`/Users/jack/_Projects/SecBizCard/packages/SecBizCard_OCR` (confirmed `git check-ignore
pubspec_overrides.yaml` → matched, so it is NOT committed). Then:

- `fvm flutter pub get` → `Got dependencies!` (exit 0).
- `fvm dart run build_runner build --delete-conflicting-outputs` → `Built with build_runner in 16s;
  wrote 54 outputs.` (generates the gitignored riverpod/freezed `*.g.dart`/`*.freezed.dart` the
  screen depends on). These generated files are gitignored and not part of the commit.

## Change 1 — ARB title rename → literal "Secured Web Editor" (all 5 locales)

`grep -rn '"backupWebEditorTitle"' lib/l10n/`:
```
lib/l10n/app_en.arb:809:  "backupWebEditorTitle": "Secured Web Editor",
lib/l10n/app_zh.arb:351:  "backupWebEditorTitle": "Secured Web Editor",
lib/l10n/app_zh_TW.arb:351:  "backupWebEditorTitle": "Secured Web Editor",
lib/l10n/app_ja.arb:360:  "backupWebEditorTitle": "Secured Web Editor",
lib/l10n/app_ko.arb:360:  "backupWebEditorTitle": "Secured Web Editor",
```
`backupWebEditorBody` / `backupWebEditorUrlCopied` left unchanged in every file (title-only).

### l10n regenerated

- `fvm flutter gen-l10n` → exit 0 (used l10n.yaml options).
- `grep -rn "backupWebEditorTitle => 'Secured Web Editor'" lib/generated/l10n/` → **5 getter
  overrides**: en, zh, zh_TW (both inside app_localizations_zh.dart), ja, ko:
```
lib/generated/l10n/app_localizations_en.dart:1180
lib/generated/l10n/app_localizations_zh.dart:1134  (zh)
lib/generated/l10n/app_localizations_zh.dart:2845  (zh_TW subclass)
lib/generated/l10n/app_localizations_ja.dart:1151
lib/generated/l10n/app_localizations_ko.dart:1150
```
- No stray old title values remain as a `backupWebEditorTitle` value (the only residual
  網頁編輯器/网页编辑器/ウェブエディター/웹 편집기 hits are inside `backupWebEditorBody` /
  `backupWebEditorUrlCopied`, which are intentionally untouched).

## Change 2 — Reorder CollapsibleSection below the action buttons

In `lib/features/settings/presentation/screens/backup_screen.dart` `build()`, the web-editor
`CollapsibleSection(title: l10n.backupWebEditorTitle, ...)` moved from between Magic Word and the
buttons to the **last child of the Column**, after the Restore `OutlinedButton`. Order confirmed
by reading the file:
`_buildMagicWordSection` → `SizedBox(24)` → Back Up Now `ElevatedButton` → disabled-hint block →
`SizedBox(16)` → Restore `OutlinedButton` → `SizedBox(24)` → `CollapsibleSection`.
Behavior preserved exactly: `initiallyExpanded: false`, `SectionStepText(l10n.backupWebEditorBody)`,
and tap-to-copy `TextButton.icon(onPressed: _copyWebEditorUrl, label: Text(_webEditorUrl))` — only
the widget's position changed. Single `SizedBox(height: 24)` sits between Magic Word and Back Up Now
(no double/zero gap).

## Change 3 — Version bump

`grep '^version:' pubspec.yaml` → `version: 1.6.4+191` (was `1.6.4+189`; +190 skipped per owner).

## Static analysis

`fvm flutter analyze lib/features/settings/presentation/screens/backup_screen.dart lib/generated/l10n/`
→ **No issues found!** (ran in 1.1s). No new issues in touched files.

## Tests (compile gate)

- Backup suites:
  `fvm flutter test test/unit/services/backup_service_test.dart backup_codec_test.dart
  backup_error_mapper_test.dart backup_reminder_service_test.dart` → **All tests passed!** (+58).
- Broader: `fvm flutter test test/unit` → **All tests passed!** (+158), matching baseline (incl. 58
  backup). No regressions; no tests weakened/skipped/deleted. Because the Flutter test runner compiles
  backup_screen.dart's dependency graph, the green run is also the compile check for the reorder.
- No release build attempted (signing is CI-only), per task.

## Commit hygiene

`git status --short` before commit shows only the 5 ARB files, the regenerated
`lib/generated/l10n/*.dart`, backup_screen.dart, pubspec.yaml, and the task docs. No
`pubspec_overrides.yaml` tracked (gitignored). No build_runner `*.g.dart` noise outside
`lib/generated/l10n/` is tracked (gitignored).
