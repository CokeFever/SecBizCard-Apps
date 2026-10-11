# Implementation Plan — Backup & Restore: rename web-editor title, reorder section, version bump

CLIENT UI ONLY. No backend. All work happens inside the worktree
`/Users/jack/_Projects/SecBizCard-Apps/.worktrees/backup-title-reorder` on branch
`feat/backup-title-reorder`. Use `git -C /Users/jack/_Projects/SecBizCard-Apps/.worktrees/backup-title-reorder`
for all git ops and absolute paths rooted at that worktree for all files. Do NOT touch the main repo
at `/Users/jack/_Projects/SecBizCard-Apps`.

## Ground truth confirmed during exploration

- l10n.yaml: `arb-dir: lib/l10n`, `template-arb-file: app_en.arb`,
  `output-localization-file: app_localizations.dart`, `output-dir: lib/generated/l10n`. (`flutter: generate: true` in pubspec.)
- Flutter pinned to **3.38.9** via `.fvmrc` → use `fvm flutter ...` (matches cicd.md pin; do NOT use `stable`).
- The 5 ARB source files and their CURRENT `backupWebEditorTitle` values (to be replaced with the single
  English literal `Secured Web Editor`):
  - `lib/l10n/app_en.arb`  → `"SecBizCard Web Editor"`   (line ~809; followed by `"@backupWebEditorTitle": {}`)
  - `lib/l10n/app_zh.arb`  → `"SecBizCard 网页编辑器"`     (line ~351, zh-CN/Simplified)
  - `lib/l10n/app_zh_TW.arb` → `"SecBizCard 網頁編輯器"`  (line ~351)
  - `lib/l10n/app_ja.arb`  → `"SecBizCard ウェブエディター"` (line ~360)
  - `lib/l10n/app_ko.arb`  → `"SecBizCard 웹 편집기"`      (line ~360)
  - DO NOT touch `backupWebEditorBody` / `backupWebEditorUrlCopied` in any file — title only.
- Generated output: 4 physical files under `lib/generated/l10n/` — `app_localizations_en.dart`,
  `app_localizations_ja.dart`, `app_localizations_ko.dart`, `app_localizations_zh.dart`. zh_TW is NOT a
  separate file: it is subclass `AppLocalizationsZhTw extends AppLocalizationsZh` **inside**
  `app_localizations_zh.dart` (so that file carries TWO `backupWebEditorTitle` overrides — the zh one
  near line ~1134 and the zh_TW one near line ~2845). The abstract base `app_localizations.dart` also
  carries the en value inside a doc comment (`**'SecBizCard Web Editor'**`) above the abstract getter.
  After regen, expect **5 override occurrences** of `Secured Web Editor` across the generated getters
  (en, zh, zh_TW, ja, ko) plus the doc-comment occurrence in `app_localizations.dart`.
- backup_screen.dart widget order inside `build()` (the `Column(crossAxisAlignment: stretch)`):
  Last-Backup `SectionCard` → `SizedBox(height: 24)` → `_buildMagicWordSection(l10n)` →
  `SizedBox(height: 24)` → **web-editor `CollapsibleSection(title: l10n.backupWebEditorTitle, ...)`** →
  `SizedBox(height: 24)` → Back Up Now `ElevatedButton.icon` (wrapped in `SizedBox(width: double.infinity)`)
  → optional disabled-hint block (`if (!_isLoading && !_hasLocalContacts) ...`) → `SizedBox(height: 16)` →
  Restore `OutlinedButton.icon` (wrapped in `SizedBox(width: double.infinity)`). The CollapsibleSection is
  currently BETWEEN Magic Word and the buttons; it must move to BELOW the Restore button.
- `_webEditorUrl = 'https://ixo.app/editor'`; `_copyWebEditorUrl()` copies to clipboard + snackbar, no
  browser launch — leave this method and the URL constant untouched. Only the widget's POSITION changes.
- Tests: no widget test exists for backup_screen.dart. Backup suites live in `test/unit/services/`:
  `backup_error_mapper_test.dart`, `backup_codec_test.dart`, `backup_service_test.dart`,
  `backup_reminder_service_test.dart`. Baseline per task: `test/unit` ~158 tests incl. ~58 backup, full
  suite 404/404. The reorder is a pure widget-tree move with no logic change, so it is verified by
  analyze + compile, not by a dedicated test.
- `pubspec_overrides.yaml` is gitignored (confirmed via `git check-ignore`) — safe to create locally for
  dep resolution, and it will not be committed. The private `SecBizCard_OCR` git dep may require this +
  `build_runner` to resolve for analysis.
- pubspec.yaml currently `version: 1.6.4+189` → bump to `1.6.4+191` (skip +190 per owner).

## Steps

- [ ] 1. Rename `backupWebEditorTitle` to the literal `Secured Web Editor` in all 5 ARB source files.
      Replace ONLY the value string of the `backupWebEditorTitle` key in each file; leave the key name,
      the adjacent `@backupWebEditorTitle` metadata (en file), and `backupWebEditorBody` /
      `backupWebEditorUrlCopied` unchanged. Same English literal in every file (product proper name, not
      translated — consistent with the website "Secured Web Editor").
      Files: lib/l10n/app_en.arb, lib/l10n/app_zh.arb, lib/l10n/app_zh_TW.arb, lib/l10n/app_ja.arb,
      lib/l10n/app_ko.arb
      Verify: `grep -R '"backupWebEditorTitle"' lib/l10n/` shows the value `Secured Web Editor` in all 5
      files and `backupWebEditorBody`/`backupWebEditorUrlCopied` are unchanged. (This is a staging check,
      not the acceptance gate — step 2 regenerates and step 6 is the real gate.)

- [ ] 2. Regenerate localizations so the generated Dart picks up the new title.
      If `fvm flutter gen-l10n` cannot resolve the private `SecBizCard_OCR` dep, first create a local
      gitignored `pubspec_overrides.yaml` pointing `SecBizCard_OCR` at a local path (or stub) and run
      `fvm flutter pub get` + `dart run build_runner build --delete-conflicting-outputs` as needed to get
      a resolvable project, THEN run gen-l10n. Do NOT commit `pubspec_overrides.yaml`.
      Files (regenerated, committed): lib/generated/l10n/app_localizations.dart,
      lib/generated/l10n/app_localizations_en.dart, lib/generated/l10n/app_localizations_zh.dart
      (contains both zh and zh_TW overrides), lib/generated/l10n/app_localizations_ja.dart,
      lib/generated/l10n/app_localizations_ko.dart
      Verify: `fvm flutter gen-l10n` exits 0, then
      `grep -R "backupWebEditorTitle => 'Secured Web Editor'" lib/generated/l10n/` returns 5 getter
      overrides (en, zh, zh_TW, ja, ko). Confirm no stray `SecBizCard Web Editor` / `網頁編輯器` /
      `网页编辑器` / `ウェブエディター` / `웹 편집기` remain as a `backupWebEditorTitle` value.

- [ ] 3. Move the web-editor CollapsibleSection to below the Restore button in backup_screen.dart.
      In `build()`, remove the `CollapsibleSection(title: l10n.backupWebEditorTitle, ...)` block (and its
      preceding `const SizedBox(height: 24)`) from its current spot between `_buildMagicWordSection(l10n)`
      and the Back Up Now button, and re-insert it AFTER the Restore `OutlinedButton.icon`'s wrapping
      `SizedBox` (the last child in the Column). Add a `const SizedBox(height: 24)` BEFORE the moved
      CollapsibleSection so it is separated from the Restore button, and ensure exactly one blank-space
      unit sits between Magic Word and Back Up Now now that the section is gone (keep a single
      `const SizedBox(height: 24)` there — do not leave a double gap or zero gap). Keep
      `initiallyExpanded: false`, the `SectionStepText(l10n.backupWebEditorBody)`, and the tap-to-copy
      `TextButton.icon(onPressed: _copyWebEditorUrl, ...)` exactly as-is.
      Files: lib/features/settings/presentation/screens/backup_screen.dart
      Verify: covered by analyze + compile in steps 5–6 (no dedicated widget test exists). Manually
      confirm by reading the file that the CollapsibleSection is now the final child of the Column, after
      the Restore button, and that vertical spacing (`SizedBox` heights) around Magic Word, the buttons,
      and the moved section reads cleanly.

- [ ] 4. Bump the app version in pubspec.yaml.
      Change `version: 1.6.4+189` to `version: 1.6.4+191` (skip +190 per owner).
      Files: pubspec.yaml
      Verify: `grep '^version:' pubspec.yaml` shows `version: 1.6.4+191`.

- [ ] 5. Run static analysis on the touched code.
      Command: `fvm flutter analyze`
      Verify: no NEW issues in the touched files (backup_screen.dart, the 5 ARB files, generated l10n,
      pubspec.yaml). Pre-existing baseline noise is acceptable and must NOT be "fixed" here:
      firebase_options placeholder warnings and zip_import test warnings. If analyze surfaces anything in
      a touched file, resolve it before proceeding.

- [ ] 6. Run the relevant test suites to confirm no regression (compile gate).
      Command: `fvm flutter test test/unit/services/backup_service_test.dart
      test/unit/services/backup_codec_test.dart test/unit/services/backup_error_mapper_test.dart
      test/unit/services/backup_reminder_service_test.dart` (or `fvm flutter test test/unit` for the
      broader settings/backup coverage).
      Verify: all pass with no regressions vs baseline (test/unit ~158 incl. ~58 backup). Do NOT weaken,
      skip, or delete any test to make it pass. Because step 6 compiles backup_screen.dart's dependency
      graph via the Flutter test runner, a green run is also the compile check for the reorder. Do NOT
      attempt a release build (signing is CI-only); analyze + this test/compile run is the gate.

- [ ] 7. Commit the change locally on the branch (never push).
      Stage ONLY: the 5 ARB files, the regenerated `lib/generated/l10n/*.dart`, backup_screen.dart,
      pubspec.yaml, and this plan file. Explicitly do NOT stage `pubspec_overrides.yaml` (gitignored) or
      any build_runner-generated noise outside `lib/generated/l10n/`.
      Command: `git -C /Users/jack/_Projects/SecBizCard-Apps/.worktrees/backup-title-reorder add <paths>`
      then `git -C ... commit -m "..."`.
      Verify: `git -C /Users/jack/_Projects/SecBizCard-Apps/.worktrees/backup-title-reorder status`
      shows a clean tree (no stray `pubspec_overrides.yaml` tracked) and `git show --stat HEAD` lists only
      the intended files.

## Notes / assumptions

- "Secured Web Editor" is treated as a non-translated product proper name per the task and the website,
  so the same English literal goes into every locale's ARB — matching how the site already renders it.
- The abstract `app_localizations.dart` doc-comment showing the en example value will update to
  `**'Secured Web Editor'**` automatically on regen; no manual edit needed.
- No existing widget test asserts the section's position, so the reorder's correctness rests on analyze +
  compile plus a human read of the widget tree. If the implement-and-review loop wants stronger proof, a
  lightweight widget test could be added, but the task does not require one and says not to over-build.
