# Verification — Firebase App Check (client-side) + version bump 1.6.4+189

Branch: `feat/app-check-client`
Flutter: 3.38.9 via fvm (pinned per CI/CD ground truth; `fvm flutter --version`
confirmed `Flutter 3.38.9 • channel stable`).
Worktree: `/Users/jack/_Projects/SecBizCard-Apps/.worktrees/appcheck`.

## Scope / safety

CLIENT-SIDE ONLY. No backend (separate SecBizCard repo) change, no App Check
**enforcement** anywhere. This change only ADDS Play Integrity (Android) /
App Attest (iOS) attestation tokens the live backend currently ignores, so older
field apps and the current backend keep working unchanged. App Check activation
is best-effort (own try/catch) — a failure to activate or mint a token only
`debugPrint`s and continues; no code path gates any feature on App Check. No
push, tag, or deploy performed.

## firebase_app_check version chosen — and why it's compatible

Added `firebase_app_check:` **bare** (no pin) in `pubspec.yaml`, mirroring the
repo's own bare `firebase_core:` convention, and let pub resolve it against the
already-pinned stack. Resolved from `pubspec.lock`:

- `firebase_app_check` → **0.3.2+10**
- `firebase_app_check_platform_interface` → 0.1.1+10 (transitive)
- `firebase_app_check_web` → 0.2.0+14 (transitive)
- `firebase_core` → **3.15.2 (UNCHANGED)** — confirmed no firebase_core bump and
  no movement of any other firebase_* package.

Why compatible: firebase_app_check 0.3.2+10 is published from the same FlutterFire
monorepo release line that pins `firebase_core ^3.x`; firebase_core 3.15.2 (top of
the shipped 3.x line, already resolved here) satisfies that caret. `pub get`
resolved WITHOUT a version-solve conflict and WITHOUT touching firebase_core,
firebase_auth (5.7.0), firebase_storage (12.4.10), firebase_remote_config (5.5.0),
or firebase_messaging (15.2.10). No STOP-and-report trigger hit.

## Commands & outcomes

### Local resolution aid (uncommitted, gitignored)
`pubspec.yaml` declares the private `SecBizCard_OCR` as a git SSH dep
(`git@github.com:CokeFever/SecBizCard.git`), which fails with `Permission denied
(publickey)` here. Mirroring the prior task, a **gitignored**
`pubspec_overrides.yaml` was created pointing `SecBizCard_OCR` at the sibling
worktree path `../SecBizCard/packages/SecBizCard_OCR` (which exists). This file is
`git check-ignore`-confirmed ignored and is NOT committed; CI still uses the git
SSH dep. Codegen (`fvm dart run build_runner build --delete-conflicting-outputs`)
was run once so riverpod/freezed/json_serializable `*.g.dart`/`*.freezed.dart`
resolve for analyze/test (these outputs are gitignored and NOT committed).

### `fvm flutter pub get`
Succeeded — "Changed 3 dependencies!" (the 3 firebase_app_check packages above).
No version-solve conflict. firebase_core unchanged at 3.15.2.

### `cd ios && pod install`
Succeeded. Installed `firebase_app_check (0.3.2-10)` →
`FirebaseAppCheck (11.15.0)` → `AppCheckCore (~> 11.0)` /
`FirebaseAppCheckInterop (~> 11.0)`. This rides the SAME AppCheckCore ~> 11.x /
Firebase 11.15.0 native line already present, so the known
AppCheckCore↔google_sign_in conflict (flutterfire#17590) stays aligned:
`git diff ios/Podfile.lock` shows the FirebaseAppCheck pod ADDED with NO downgrade
of GoogleSignIn (stays 8.0.0) and no change to AppCheckCore or existing Firebase
pods. (The trailing CocoaPods base-configuration notice is pre-existing and
unrelated — the Runner target already uses a custom xcconfig.)

### `fvm flutter analyze`
`5 issues found.` — ALL pre-existing baseline, NO new issues, and specifically
NO error about `FirebaseAppCheck` / `AndroidProvider` / `AppleProvider` /
`kDebugMode` (the new import and API resolve cleanly):

- `error • Target of URI doesn't exist: 'firebase_options.dart' • lib/main.dart`
  (gitignored FlutterFire-generated file, absent in fresh worktree — baseline)
- `error • Undefined name 'DefaultFirebaseOptions' • lib/main.dart`
  (same root cause — baseline)
- 3 × `warning • unnecessary_non_null_assertion • test/unit/services/zip_import_service_test.dart`
  (pre-existing — same baseline as last task)

Same baseline set documented in the prior task's `verification.md`.

### `fvm flutter test` (broad) + `fvm flutter test test/unit`
- `test/unit` (the prior task's baseline scope): **158/158 pass** — matches the
  prior baseline exactly, including the 58 backup tests.
- Broad `fvm flutter test`: 162 pass, 1 fail. The single failure is in
  `test/unit/auth_repository_test.dart` ("signInWithGoogle success - new user").
  It **passes in isolation** (`fvm flutter test test/unit/auth_repository_test.dart`
  → All tests passed, 5/5) and passes within the full `test/unit` run; it only
  trips when combined with `test/poc` files due to shared global Firebase-mock
  singleton state (test-ordering flake). It is UNRELATED to App Check — the App
  Check change only adds a startup `activate()` call that no test exercises.
  Not a regression.

### Release build
NOT attempted — release signing is CI-only (per CI/CD ground truth). Debug
analyze/compile is the gate; the plugin registers via the (tracked) generated
registrants below.

## iOS / Android platform concerns — none

- **iOS deployment target:** `ios/Podfile` sets `platform :ios, '17.0'` and the
  `post_install` hook forces `IPHONEOS_DEPLOYMENT_TARGET = '17.0'`. App Attest
  needs iOS 14+, so 17.0 satisfies it. **No iOS target change needed/made.**
- **Android minSdk:** `android/app/build.gradle.kts` uses
  `minSdk = flutter.minSdkVersion` (Flutter 3.38.9 default = 21); the file already
  declares `implementation("com.google.android.play:integrity:1.6.0")`. Play
  Integrity App Check supports API 19+. **No minSdk change needed/made.**

## main.dart change (exact)

- Added `import 'package:flutter/foundation.dart';` (for `kDebugMode`).
- Added `import 'package:firebase_app_check/firebase_app_check.dart';`.
- Inserted the App Check `activate()` call IMMEDIATELY AFTER
  `await Firebase.initializeApp(...)` / its `debugPrint`, and BEFORE
  `CardDetectionConfig.initialize()` / `SubscriptionService` / `runApp`, inside its
  OWN try/catch (so an activate failure logs and continues — it does NOT fall into
  the outer catch that renders the "Initialization Error" screen):

```dart
try {
  await FirebaseAppCheck.instance.activate(
    androidProvider:
        kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider:
        kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
  );
  debugPrint('[Main] Firebase App Check activated');
} catch (e) {
  debugPrint('[Main] Firebase App Check activation failed (continuing): $e');
}
```

Providers are kDebugMode-gated per the task instruction: debug providers in debug
builds (so emulators/dev devices still attest), production playIntegrity/appAttest
in release.

## Version

`pubspec.yaml` `version:` bumped `1.6.3+188` → **1.6.4+189** (confirmed).

## Committed files

`pubspec.yaml`, `pubspec.lock`, `lib/main.dart`, `ios/Podfile.lock`, plus the two
TRACKED generated plugin registrants that now register the plugin on native
builds — `android/.../GeneratedPluginRegistrant.java` and
`ios/Runner/GeneratedPluginRegistrant.m`. (`pubspec_overrides.yaml` and all
codegen outputs are gitignored and NOT committed.) No push, no tag.
