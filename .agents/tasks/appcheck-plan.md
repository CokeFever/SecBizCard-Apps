# Implementation Plan — Firebase App Check (client-side) + version bump 1.6.4+189

Stage 1 of backend-hardening: ship an app that INITIALIZES Firebase App Check and
attaches Play Integrity (Android) / App Attest (iOS) attestation tokens, so the
backend can LATER (separate, user-controlled step) enforce App Check on the shared
Cloud Vision function. **Enforcement is NOT in this task. CLIENT-SIDE ONLY — do not
touch the backend repo.**

## Hard safety constraint (applies to every item)
The live backend does NOT enforce App Check and must keep accepting all requests
(older field apps must keep working). This change only ADDS attestation tokens the
backend currently ignores. App Check activation MUST be best-effort: a failure to
activate (or to mint a token) must NEVER crash startup or block any app feature.
No client code may gate functionality on App Check success.

All paths absolute. Worktree root: `/Users/jack/_Projects/SecBizCard-Apps/.worktrees/appcheck`.
Flutter is pinned 3.38.9 via fvm (`.fvmrc` present, no `.fvm/` dir) — always invoke
as `fvm flutter ...`. Use `git -C <worktree>` for any git. Branch: `feat/app-check-client`.

---

## Facts resolved by reading the actual files (design inputs — do not re-decide)

**Fact 1 — firebase_* versions (from pubspec.lock, the authoritative resolved set):**
- `firebase_core` **3.15.2** (declared bare `firebase_core:` in pubspec.yaml — the
  repo deliberately leaves it unconstrained and lets pub resolve)
- `firebase_auth` 5.7.0, `firebase_storage` 12.4.10, `firebase_remote_config` 5.5.0,
  `firebase_messaging` 15.2.10 (all transitively on firebase_core 3.x)
- **Compatibility decision:** firebase_app_check is published from the same FlutterFire
  monorepo and constrains firebase_core with a caret on the 3.x line (verified: the
  package pubspec uses `firebase_core: ^3.x`). firebase_core 3.15.2 is the top of the
  shipped 3.x line, so the current firebase_app_check should resolve against it WITHOUT
  bumping firebase_core or any other firebase_* package. **We do NOT hard-pin a
  firebase_app_check version in this plan** — mirroring the repo's own bare
  `firebase_core:` style, we add `firebase_app_check:` (bare) and let
  `fvm flutter pub get` pick the newest compatible release, then record the resolved
  version from pubspec.lock. **STOP-and-report trigger:** if `pub get` fails demanding a
  firebase_core higher than 3.15.2 (or wanting to change any other firebase_* package),
  do NOT force it — set the FEAT/plan status to report and surface the exact pub error.

**Fact 2 — Firebase init site (lib/main.dart):** inside `main()`'s `try` block, at
`await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);`
(the `debugPrint('[Main] Firebase initialized successfully');` line immediately
follows). `FirebaseAppCheck.instance.activate(...)` goes IMMEDIATELY AFTER that
`initializeApp` await and BEFORE the `CardDetectionConfig.initialize()` /
`SubscriptionService` / `runApp` calls — wrapped in its own try/catch so an activate
failure only logs and continues (it must not fall into the outer catch that renders
the "Initialization Error" screen).

**Fact 3 — iOS deployment target:** `ios/Podfile` sets `platform :ios, '17.0'` and the
`post_install` hook forces `IPHONEOS_DEPLOYMENT_TARGET = '17.0'`. App Attest needs
iOS 14+ → **17.0 easily satisfies it. No iOS target change needed.** (Also:
`ios/Podfile.lock` already contains `AppCheckCore: 11.2.0`, pulled transitively by
`GoogleSignIn (8.0.0) -> AppCheckCore (~> 11.0)`; Firebase native pods are 11.15.0.
firebase_app_check's native pod rides the same AppCheckCore ~> 11.x line, so the known
AppCheckCore↔google_sign_in conflict (flutterfire#17590) is already aligned here — but
a `pod install` re-resolve remains the authoritative check, see item 4.)

**Fact 4 — Android minSdk:** `android/app/build.gradle.kts` uses
`minSdk = flutter.minSdkVersion` (Flutter 3.38.9 default = 21). Play Integrity App
Check provider supports API 19+ → **no minSdk change needed.** Note the file ALREADY
declares `implementation("com.google.android.play:integrity:1.6.0")`, so the Play
Integrity native dependency is present. applicationId is `app.ixo.secbizcard`.

**Fact 5 — version bump:** pubspec.yaml `version: 1.6.3+188` → `1.6.4+189`.

**Provider choice (design decision):** use the production attestation providers —
Android `AndroidProvider.playIntegrity`, iOS `AppleProvider.appAttest`. Rationale:
App Attest requires iOS 14+ (target is 17.0, satisfied) and Play Integrity is already
wired natively; these are the providers the backend will later verify. Debug provider
is optional and OUT OF SCOPE for this release build (adding it does not affect release
attestation and risks a debug-token footgun; skip it).

---

## Plan

- [ ] 1. Add the `firebase_app_check` dependency (bare, no version pin) to pubspec.yaml.
      Insert `firebase_app_check:` in the dependencies block next to the other
      `firebase_*` entries (e.g. directly after the bare `firebase_auth:` line) so pub
      resolves it from the same FlutterFire release as firebase_core 3.15.2.
      Files: `/Users/jack/_Projects/SecBizCard-Apps/.worktrees/appcheck/pubspec.yaml`
      Verify: run `fvm flutter pub get` in the worktree — it completes WITHOUT errors
      and WITHOUT changing the resolved `firebase_core` version (confirm pubspec.lock
      still shows `firebase_core ... version: "3.15.2"`). Record the resolved
      `firebase_app_check` version from pubspec.lock in the plan/FEAT findings.
      STOP-and-report: if pub demands a firebase_core > 3.15.2 or wants to move any
      other firebase_* package, do not force-resolve — surface the exact error and halt.

- [ ] 2. Bump the app version in pubspec.yaml from `1.6.3+188` to `1.6.4+189`.
      Change only the `version:` line.
      Files: `/Users/jack/_Projects/SecBizCard-Apps/.worktrees/appcheck/pubspec.yaml`
      Verify: `git -C <worktree> diff pubspec.yaml` shows exactly the version line
      change (plus the firebase_app_check line from item 1); and the already-run
      `fvm flutter pub get` from item 1 still succeeds.

- [ ] 3. Initialize App Check in `lib/main.dart`, immediately after
      `await Firebase.initializeApp(...)` and before `CardDetectionConfig.initialize()`.
      Add `import 'package:firebase_app_check/firebase_app_check.dart';` with the other
      firebase imports. Wrap the activate call in its OWN try/catch (not the outer one)
      so a failure only `debugPrint`s and continues — startup must proceed and all
      features must work with no App Check token. Use production providers:
      `FirebaseAppCheck.instance.activate(androidProvider: AndroidProvider.playIntegrity, appleProvider: AppleProvider.appAttest)`.
      Do NOT add any code that blocks UI or features when activation/token fails.
      Files: `/Users/jack/_Projects/SecBizCard-Apps/.worktrees/appcheck/lib/main.dart`
      Verify: `fvm flutter analyze lib/main.dart` reports no new errors; visually
      confirm the activate call sits inside its own try/catch between the Firebase-init
      `debugPrint` and the `CardDetectionConfig.initialize()` line.

- [ ] 4. Refresh the iOS Pods so the firebase_app_check native pod is linked, and
      confirm the AppCheckCore graph still resolves alongside google_sign_in.
      Run `fvm flutter pub get` (done in item 1) then `pod install` in `ios/`
      (`cd <worktree>/ios && pod install`). This is the authoritative check for the
      AppCheckCore↔google_sign_in alignment noted in Fact 3.
      Files: `/Users/jack/_Projects/SecBizCard-Apps/.worktrees/appcheck/ios/Podfile.lock`
      (regenerated; expect FirebaseAppCheck ~11.15.0 and AppCheckCore to remain on the
      ~> 11.x line).
      Verify: `pod install` completes without a version-conflict error; `git -C
      <worktree> diff ios/Podfile.lock` shows the FirebaseAppCheck pod added and no
      downgrade of GoogleSignIn / existing Firebase pods. STOP-and-report if CocoaPods
      reports an AppCheckCore/Firebase version conflict (do not hand-edit the lock).

- [ ] 5. Build-verify both platforms with the pinned toolchain (debug builds — no
      signing/upload; this is client-only and must not touch release pipelines).
      Run, in the worktree: `fvm flutter analyze` (whole project),
      `fvm flutter build apk --debug`, and `fvm flutter build ios --debug --no-codesign`.
      Files: none (verification only).
      Verify: `analyze` passes with no new errors; both debug builds succeed. The app
      launches through `main()` even if App Check cannot attest (confirmed by the
      try/catch design in item 3 — no code path gates features on App Check).

- [ ] 6. Run the Dart test suite to confirm no regression from the new dependency/import.
      Run `fvm flutter test` in the worktree.
      Files: none (verification only).
      Verify: the suite passes (or shows only pre-existing failures unrelated to this
      change — compare against the base branch if any failures appear).

- [ ] 7. Commit the change locally on `feat/app-check-client` (do NOT push; do NOT tag —
      release tagging `android/v1.6.4` / `ios/v1.6.4` is a later, user-controlled step).
      Stage exactly: `pubspec.yaml`, `pubspec.lock`, `lib/main.dart`,
      `ios/Podfile.lock`. Commit message e.g.
      `feat(appcheck): initialize Firebase App Check client (playIntegrity/appAttest), bump 1.6.4+189`.
      Files: the four staged files above.
      Verify: `git -C <worktree> status` is clean apart from the new commit;
      `git -C <worktree> log -1 --stat` shows only the four intended files.

---

## Notes / assumptions / report items
- **No backend change.** This plan never touches the separate SecBizCard backend repo
  or any Firebase Function. Backend App Check enforcement is a later, separate,
  user-controlled step (and per repo rules, Firebase deploy is manual-only).
- **No release-impacting platform bumps.** iOS target (17.0) and Android minSdk (21)
  both already satisfy App Attest / Play Integrity, so no silent target/SDK bump is
  planned. If any tool later claims otherwise, treat it as REPORT-only.
- **firebase_app_check version is intentionally left to pub resolution** against the
  pinned firebase_core 3.15.2 (item 1), matching the repo's bare-`firebase_core:`
  convention. The STOP-and-report trigger covers the only real conflict risk.
- If `pod install` or `pub get` surfaces an AppCheckCore / firebase_core conflict,
  STOP and report rather than forcing versions — do not bump firebase_core or other
  firebase_* packages to make App Check fit.
