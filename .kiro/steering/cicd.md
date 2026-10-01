# CI/CD & Release Pipelines — Ground Truth

CRITICAL: the release pipelines span THREE separate systems. Do not assume from
one. When reasoning about "how does a build/deploy happen", check the specific
system below — a past mistake was looking only at GitHub Actions and concluding
Android had no Play upload, when the real pipeline is GCP Cloud Build.

## Android release → GCP Cloud Build (NOT GitHub Actions)

- Trigger: **Cloud Build** trigger `android-release-build` in project
  `ixo-app-secbizcard`, **region `us-central1`**, fires on git tag `^android/v.*`.
  (Verify with: `gcloud builds triggers list --project=ixo-app-secbizcard --region=us-central1`)
- Build config: **`cloudbuild.yaml`** (repo root of SecBizCard-Apps).
- What it does: decode keystore (Secret Manager) → `flutter build aab --release`
  → fastlane `upload_to_play_store track:internal` → **auto-uploads the AAB to
  Play internal testing.**
- Secrets: **GCP Secret Manager** (project `ixo-app-secbizcard`), referenced via
  `availableSecrets` + `secretEnv` in cloudbuild.yaml. e.g.
  ANDROID_KEYSTORE_*, PLAY_STORE_SERVICE_ACCOUNT_JSON, GOOGLE_SERVICES_JSON,
  FIREBASE_OPTIONS_DART, OCR_DEPLOY_KEY, REVENUECAT_ANDROID_KEY.
- To add a build-time value (e.g. a --dart-define): add the secret to Secret
  Manager, list it in cloudbuild.yaml `availableSecrets` + the step's
  `secretEnv`, and reference it as `$$NAME` inside the step script.
- Cloud Build runs as SA `android-releaser@ixo-app-secbizcard.iam.gserviceaccount.com`,
  which holds `roles/secretmanager.secretAccessor` at the PROJECT level — so any
  new secret in this project is readable without per-secret IAM grants.

## GitHub Actions `android_build.yml` = QA APK only (does NOT ship)

- Fires on `android/v*` tag / PR / manual. Builds an **APK** and uploads it as a
  GitHub **artifact**. It does NOT upload to Play. This is a secondary QA build,
  not the release path. Its secrets live in **GitHub Secrets**. Don't confuse it
  with the Cloud Build release above.

## iOS release → Xcode Cloud

- Trigger rule lives in **App Store Connect → Xcode Cloud** (NOT in this repo);
  fires on git tag `ios/v*`. Build script: **`ios/ci_scripts/ci_post_clone.sh`**.
- Does: install Flutter 3.38.9, inject Firebase secrets, `flutter build ios
  --release --no-codesign --dart-define=REVENUECAT_IOS_KEY=...` → TestFlight /
  App Store.
- Secrets/env vars: set in the **Xcode Cloud workflow environment variables**
  (App Store Connect), NOT GitHub Secrets and NOT Secret Manager. e.g.
  OCR_DEPLOY_KEY, REVENUECAT_IOS_KEY.

## Firebase backend (private repo SecBizCard) → MANUAL

- `.github/workflows/firebase_deploy.yml` is **manual-only** (`workflow_dispatch`,
  the push-to-main auto-deploy was removed 2026-09-22). Deploys functions /
  hosting / firestore+storage rules / website. Run it deliberately, and only
  alongside the matching app release (app↔functions usage contract is coupled).
  Requires the `REVENUECAT_WEBHOOK_AUTH` Firebase secret to be set first.

## Where each secret lives (do not cross these up)

| Pipeline | System | Secret store |
|----------|--------|--------------|
| Android release | GCP Cloud Build | **GCP Secret Manager** (`ixo-app-secbizcard`) |
| Android QA APK | GitHub Actions | GitHub Secrets |
| iOS release | Xcode Cloud | Xcode Cloud env vars |
| Firebase backend | GitHub Actions (manual) | GitHub Secrets + Firebase `functions:secrets` |

## Flutter version pin

All pipelines pin **Flutter 3.38.9**. Do NOT use "stable" (3.47.x) — its newer
Dart analyzer crashes riverpod_generator 2.6.4 (visitDotShorthandPropertyAccess)
and hangs build_runner. This pin appears in cloudbuild.yaml, android_build.yml,
and ci_post_clone.sh.

## Version tagging convention

Release with platform-prefixed tags, one per platform (usually same commit):
`android/v<ver>` → Cloud Build → Play; `ios/v<ver>` → Xcode Cloud → App Store.
Bare `v*` tags are retired. See .agent/workflows/deploy_release.md.

## Provider deprecation notices — assessed, no action needed (as of 2026-10)

Two Google emails arrived late Sep 2026. Both assessed as **not impacting** this
project's current setup. Recorded so a future reader doesn't re-investigate.

### Firebase Hosting on-demand site provisioning (effective 2026-10-15)
- Change: NEW Firebase projects will no longer auto-create a default Hosting site;
  it provisions on first deploy/use instead.
- **Impact on us: none.** We deploy to the EXISTING project `ixo-app-secbizcard`
  with an EXISTING default site (ixo.app). `firebase.json` hosting has no explicit
  `site` field → uses the already-existing default site. The change only affects
  pipelines that CREATE brand-new projects.
- **Only relevant if** we ever spin up a brand-new Firebase project in CI — then
  run `firebase hosting:sites:create <site-id> --project=<project-id>` BEFORE the
  first `firebase deploy`, else it 404s. Does not apply to SecBizCard today.

### Cloud Build worker VM release channels (regular becomes default 2027-03-28)
- Change: Cloud Build adds release channels controlling the worker VM HOST env
  (Debian/Docker versions). `regular` channel becomes the default 2027-03-28.
- **Impact on us: negligible.** Our `cloudbuild.yaml` runs every step inside
  pinned containers (`ghcr.io/cirruslabs/flutter:3.38.9`, `gcr.io/cloud-builders/gcloud`),
  so all tool versions are container-controlled, not host-controlled. Host
  Debian/Docker version doesn't affect a Flutter-build + fastlane-upload flow.
- **Action: none now.** Optional: near 2027-03, run a test build on the `regular`
  channel to confirm. Only pin to `stable` channel if a host-behavior issue ever
  surfaces (unlikely given full containerization). Project flagged in the notice:
  `ixo-app-secbizcard`.
