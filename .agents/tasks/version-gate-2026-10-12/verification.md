# Version Gate — Verification Report

Task: `version-gate-2026-10-12`
Branch: `feat/version-gate`
Feature commit: `1c03575` — *feat: add remote-controlled app version gate (force + soft alert)*
Verified with: Flutter **3.38.9** (fvm, matches CI pin).

A remote-controlled, client-only app version gate with two stages (force block +
soft alert), driven by Firebase Remote Config and compared against the running
app build number. Reuses the already-activated `CardDetectionConfig` RC instance
— no second Remote Config setup, no blocking network wait at startup.

---

## 1. Remote Config keys and defaults

The gate reads two integer RC keys. Both are compared against the **running app
build number** (an `int`), never a version string. Defaults are shipped in the
app so a missing/unavailable remote value falls back to the shipped default.

| Key | Default | Role |
|-----|---------|------|
| `min_supported_build` | **180** | FORCE threshold. Build below this => non-dismissible update wall. |
| `latest_build` | **0** | SOFT-ALERT threshold. `0` = soft alert OFF. Build below this (and ≥ min) => dismissible "update available" dialog. |

Defaults live in `lib/features/contacts/data/card_detection_config.dart`
(`_intDefaults`), read via `CardDetectionConfig.intValue(key)`. A **negative**
remote value is treated as nonsensical for a build number and the shipped
default is kept (console-value guard; fail-open on *unavailability* is handled by
the gate, see §4).

### Running-build source

The running build number comes from **`package_info_plus`**
(`PackageInfo.fromPlatform().buildNumber`, parsed via `int.tryParse`), in
`lib/core/version_gate/version_gate_provider.dart` (`readRunningBuild()`). Any
failure (plugin error, unparseable build string) resolves to **`null`**, which
the decision function treats as `proceed` (fail-open).

---

## 2. Decision table

Pure logic in `lib/core/version_gate/version_gate_decision.dart`
(`evaluateVersionGate`), with ZERO Flutter/Firebase/plugin imports so it is
unit-testable without mocks. Inputs: `runningBuild`, `minSupportedBuild`,
`latestBuild` (all nullable). Comparison is by integer build number.

| Condition | Decision |
|-----------|----------|
| `runningBuild == null` | **proceed** (fail-open — unknown build never gates) |
| `runningBuild < minSupportedBuild` | **forceBlock** (force wins over soft) |
| `minSupportedBuild <= runningBuild < latestBuild` (and `latestBuild > 0`) | **softAlert** |
| `runningBuild >= latestBuild` (and `>= minSupportedBuild`) | **proceed** |
| `latestBuild == 0` (default) | **never softAlert** → proceed (soft alert OFF) |
| `minSupportedBuild == null` | treated as `0` (no force wall) |
| `latestBuild == null` | treated as `0` (soft alert OFF) |

Notes:
- **Force precedence:** if `runningBuild` is below BOTH thresholds, the result is
  `forceBlock` (force wins over soft).
- `latestBuild` is an **exclusive** upper bound: `runningBuild == latestBuild`
  => `proceed` (you are current).
- Missing thresholds fail open: a null `minSupportedBuild` → `0` (no force
  wall); a null or `0` `latestBuild` disables the soft alert.

---

## 3. Store URLs per platform

Opened externally (`LaunchMode.externalApplication`) via `url_launcher` in
`lib/core/version_gate/store_launcher.dart`. Both stages (force wall + soft
alert) use the same launcher.

- **Android:** `market://details?id=app.ixo.secbizcard` (opens the Play Store
  app directly). If it can't be launched (e.g. no Play Store), falls back to the
  HTTPS URL `https://play.google.com/store/apps/details?id=app.ixo.secbizcard`.
- **iOS:** `https://apps.apple.com/app/id6759779351`.

A store-launch failure is swallowed/logged and never crashes the gate — on the
force wall the wall stays up and the user can retry the button.

---

## 4. FAIL-OPEN guarantee (plain words)

**The gate can only ever KEEP a user out when it has positive, fresh evidence
that it should. If anything needed to make that decision is missing, broken, or
still loading, the app opens normally.** Concretely:

- Remote Config not activated yet, a key missing, or the whole RC read throws →
  **proceed**.
- The running build number can't be read or parsed → **proceed**.
- The decision provider itself throws for any reason → it is wrapped and returns
  **proceed**.
- While the decision is still resolving (async), the gate shows the app
  (`decision.valueOrNull ?? GateDecision.proceed`) — startup is **never** blocked
  waiting on this.

A user is therefore **never** locked out because Remote Config could not be read.
The trade-off (documented in `version_gate_decision.dart`): downgrade/sideload
protection is an **online-time** guarantee — a rare user who downgrades while
offline (no fresh RC) may slip through until their next online launch. That is
accepted; the gate never blocks on unavailable config.

---

## 5. Where the gate runs in startup

`lib/main.dart`: the gate wraps **every route** via `MaterialApp.router`'s
`builder`:

```dart
builder: (context, child) =>
    VersionGate(child: child ?? const SizedBox.shrink()),
```

This sits **above all routes but under the localization context**, so:
- a `forceBlock` user has `child` replaced by the full-screen `ForceUpdateScreen`
  and **never reaches a route**;
- the gate is non-blocking and fail-open (it reacts only once a decision
  resolves, otherwise it shows the app).

`VersionGate` (`lib/core/version_gate/version_gate.dart`) watches
`versionGateDecisionProvider` and renders:
- `forceBlock` → `ForceUpdateScreen` (non-dismissible: `PopScope(canPop: false)`,
  no AppBar/close, single "Update" action, no version/build numbers shown).
- `softAlert` → shows `child`, and **once per launch** (`_softShown` in-memory
  guard; a cold restart re-shows) schedules the dismissible `showSoftUpdateAlert`
  dialog ("Later" / "Update").
- `proceed` / loading / error → shows `child`.

---

## 6. Localization — 5 locales, 4 keys each

ARB keys added to all five locales (`lib/l10n/`): **en, zh-TW, zh-CN, ja, ko**
(`app_en.arb`, `app_zh_TW.arb`, `app_zh.arb`, `app_ja.arb`, `app_ko.arb`), and
regenerated into `lib/generated/l10n/`.

| Key | en | zh-TW | zh-CN | ja | ko |
|-----|----|-------|-------|----|----|
| `versionGateUpdateTitle` | Update available | 有可用的更新 | 有可用的更新 | アップデートがあります | 업데이트 가능 |
| `versionGateUpdateBody` | A newer version of SecBizCard is available. Please update to continue. | SecBizCard 有新版本可用,請更新後繼續使用。 | SecBizCard 有新版本可用,请更新后继续使用。 | SecBizCard の新しいバージョンが利用できます。続行するには更新してください。 | SecBizCard의 새 버전이 있습니다. 계속하려면 업데이트하세요. |
| `versionGateUpdateAction` | Update | 更新 | 更新 | 更新 | 업데이트 |
| `versionGateLaterAction` | Later | 稍後 | 稍后 | 後で | 나중에 |

The copy only tells the user "a newer version is available" — no build/version
numbers are surfaced, matching the owner's instruction.

---

## 7. Test & analyze results

### Unit tests

`fvm flutter test test/unit/version_gate_decision_test.dart`

- **11 tests, 11 passed, 0 failed.** ("All tests passed!")
- Coverage of the decision function: null running build (fail-open); both
  thresholds null (no gate); `running < min` → forceBlock; `running == min`
  with `latest > min` → softAlert; `min <= running < latest` → softAlert;
  `running >= latest` → proceed; force precedence (below both) → forceBlock;
  `running == latest` → proceed (exclusive upper bound); `min` null + `latest`
  set → softAlert; `latest == 0` default with `running >= min` → proceed;
  `latest == 0` never triggers softAlert.

### Static analysis

`fvm flutter analyze` → **5 issues found**, none from version-gate code:

- 2 **errors** in `lib/main.dart` — `firebase_options.dart` URI doesn't exist /
  `DefaultFirebaseOptions` undefined. This is the **gitignored, CI-injected**
  Firebase config file (absent in a fresh/worktree checkout, generated/injected
  during the real build). Pre-existing, not a version-gate regression.
- 3 **warnings** (`unnecessary_non_null_assertion`) in
  `test/unit/services/zip_import_service_test.dart` — a pre-existing test file
  **not touched** by the version-gate commit.

The version-gate files (`lib/core/version_gate/*`, the RC config change, the ARB
files, and the gate's unit test) analyze clean.

> Build-tooling note: the worktree has no committed `pubspec_overrides.yaml`
> (correct — see the integration report). To run tests/analyze locally the OCR
> git dependency was resolved via a **temporary gitignored** `pubspec_overrides`
> pointing at the sibling checkout, then removed; the worktree remains pristine.

---

## NOTE — shipping with default 180 blocks essentially no one today

The force threshold ships at `min_supported_build = 180`, which is **below**
every build real users are on. **Shipping this does not force-update anyone.** It
is the **floor / anti-downgrade baseline**: it stops a user from sideloading or
downgrading to a build older than 180 (while online), and it wires up the
mechanism.

To actually force existing users to update, the owner must **RAISE
`min_supported_build` in the Firebase console** to the target build number —
and only **AFTER 1.6.5 (which contains this gate client) is widely adopted**.
Raising it before adoption would strand users who don't yet have the gate code
and can't be reached by it. The soft-alert threshold `latest_build` stays `0`
(off) until the owner sets it to a shipped build to start nudging.
