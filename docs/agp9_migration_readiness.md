# AGP 9.0 / 10.0 Migration Readiness

Status: **Not started — deliberately deferred.** This document is the plan and
the trigger conditions, not an in-progress migration.

Last reviewed: 2026-09-08 (against app version 1.5.1+161).

## Why this is deferred

Google Play recommends upgrading the Android Gradle Plugin (AGP) to 9.0+. We
evaluated it and decided **not** to upgrade now. AGP 9.0 (released as 9.0.1,
Jan 2026) removes support for *applying* the Kotlin Gradle Plugin and switches
to built-in Kotlin. For a Flutter app this is a breaking change, and one of the
hard blockers cannot be satisfied on our current toolchain yet:

- **Flutter version blocker (hard):** enabling built-in Kotlin
  (`android.builtInKotlin=true`) requires **Flutter 3.47+** per Flutter's own
  docs. We are on **Flutter 3.38.9**. On our current channel this flag cannot
  be turned on at all — this is not "risky", it is "not yet possible".
- **Version floors (hard):** AGP 9.0 requires **Gradle 9.1.0** (we have 8.14),
  **SDK Build Tools 36** (we have 35), and pulls **Kotlin 2.2.10** as a runtime
  dependency (we declare 2.1.0).
- **App-module blocker:** `android/app/build.gradle.kts` applies
  `id("kotlin-android")` and uses a `kotlinOptions { jvmTarget = ... }` block.
  Under AGP 9 built-in Kotlin, applying `kotlin-android` is an **error**, and
  `kotlinOptions` must move into a `kotlin { compilerOptions { ... } }` block.
- **Third-party plugin long tail:** any single plugin that still applies KGP
  and hasn't shipped an AGP-9-compatible release blocks the whole build. We do
  not control this code.

There is **no hard deadline yet**: the opt-out flags only disappear in AGP 10.0,
whose official estimate is "late 2026" (estimate, subject to change). We are
already on AGP 8.13.0, which satisfies the *optimized resource shrinking* Play
recommendation without touching any of the above.

## Current state snapshot (2026-09-08)

| Component        | Current            | AGP 9.0 requires        |
|------------------|--------------------|-------------------------|
| Flutter          | 3.38.9             | 3.47+ (for built-in Kotlin) |
| AGP              | 8.13.0             | 9.0+                    |
| Gradle wrapper   | 8.14               | 9.1.0                   |
| Kotlin (KGP)     | 2.1.0              | 2.2.10 (auto-pulled)    |
| JDK              | 17                 | 17 ✓ (already met)      |
| SDK Build Tools  | 35.0.0             | 36.0.0                  |
| compileSdk/target| 36 (via Flutter)   | max API 36.1            |

App-module Kotlin config to change later (`android/app/build.gradle.kts`):
```kotlin
plugins {
    id("kotlin-android")           // <- remove under built-in Kotlin
}
kotlinOptions {                    // <- replace with kotlin { compilerOptions { } }
    jvmTarget = JavaVersion.VERSION_17.toString()
}
```

## Plugins that contribute Android native build logic (audit targets)

These are the dependencies with an Android side that could apply KGP / touch the
AGP DSL. Each needs an AGP-9-compatible release confirmed before flipping
built-in Kotlin. (Pure-Dart packages are excluded.)

- firebase_core / firebase_auth / cloud_firestore / cloud_functions /
  firebase_messaging (Firebase BoM — usually migrates as a set)
- google_sign_in
- sign_in_with_apple
- mobile_scanner
- google_mlkit_text_recognition (+ the native `text-recognition-chinese` dep)
- image_picker
- image_cropper
- camera
- permission_handler
- share_plus
- flutter_secure_storage
- path_provider
- shared_preferences
- url_launcher
- app_links
- play_install_referrer
- file_picker
- package_info_plus
- flutter_svg (uses native? mostly Dart — verify)
- **OpenCV** (native, via `org.opencv:opencv:4.14.0` + prefab in build.gradle.kts)
- **SecBizCard_OCR** (our own private git package — we control this one)
- **com.google.android.play:integrity** (declared directly in build.gradle.kts)

Note: OpenCV is wired through `externalNativeBuild` + prefab, not KGP, so it is
less likely to hit the built-in-Kotlin change — but its 16 KB alignment and NDK
version must be re-verified against AGP 9's default NDK (28.2.x).

## What we can safely do NOW (optional, low risk)

Nothing is required today. The only change that is compatible with the current
AGP 8.13 + opt-out world AND reduces future work is app-side Kotlin
modernization — but on AGP 8.13 removing `kotlin-android` would break the build,
so we hold this until the AGP 9 branch work. **No action now.**

## Trigger conditions (when to actually start)

Start the migration on a **separate branch** only when ALL of these hold:

1. Flutter stable on our channel is **3.47+** (unblocks built-in Kotlin).
2. The Android-native plugins above have shipped AGP-9-compatible releases
   (watch flutter/flutter issue #181383 as the tracking bug).
3. We have scheduled a release window where 1.5.x can absorb a build-toolchain
   change (not while soaking a fresh release).

## Migration steps (for when triggered)

1. Record state: Flutter / AGP / Gradle / Kotlin / JDK / Build Tools versions.
2. Upgrade Gradle wrapper to 9.1.0+; AGP to 9.0.x; SDK Build Tools to 36.
3. Confirm Flutter has written `android.newDsl=false` and
   `android.builtInKotlin=false` into `android/gradle.properties` (it does this
   on `flutter run` / `flutter build apk` from 3.44+).
4. In a branch, set `android.newDsl=true` + `android.builtInKotlin=true` to force
   strict mode, build, and **record every failing plugin**. This produces the
   real blocker list. Do not ship from this branch — it is a probe.
5. Remove `id("kotlin-android")` and the `kotlinOptions` block from
   `android/app/build.gradle.kts`; add:
   ```kotlin
   kotlin {
       compilerOptions {
           jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
       }
   }
   ```
6. Re-verify OpenCV: 16 KB `.so` alignment holds, prefab still resolves, and the
   `c++_shared` / NDK combination builds against AGP 9's default NDK.
7. Audit custom Gradle logic against AGP 10.0 removals (we currently use none of
   `applicationVariants`, `variantFilter`, `buildConfigField`, `resValue`,
   Transform API — confirm this stays true).
8. Update CI (GitHub Actions, cloudbuild, Xcode Cloud not affected) for Gradle
   9.1.0 + Build Tools 36 + JDK 17 images.
9. Only after the plugin list is clear and Flutter >= 3.47, flip
   `android.builtInKotlin=true` on main.

## References

- AGP 9.0.1 release notes (Jan 2026) — developer.android.com
- Migrate to built-in Kotlin — developer.android.com/build/migrate-to-built-in-kotlin
- Built-in Kotlin migration (Flutter docs) — requires Flutter 3.47+
- Update your Kotlin projects for AGP 9.0 — JetBrains Kotlin blog
- flutter/flutter #181383 — "Flutter plugins should support AGP 9.0.0"

_Content synthesized from official AGP/Flutter/JetBrains documentation; rephrased
for licensing compliance._
