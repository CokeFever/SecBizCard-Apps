# Backend Protection Investigation — SecBizCard Firebase Functions

READ-ONLY investigation. Nothing was modified in either repo.

- Backend (private): `/Users/jack/_Projects/SecBizCard` — Functions source `functions/src/index.ts` (+ `quota.ts`, `revenuecat.ts`), `firestore.rules`, `storage.rules`, `firebase.json`.
- Client (public): `/Users/jack/_Projects/SecBizCard-Apps` — Flutter app.
- Owner app identity: Android `applicationId = "app.ixo.secbizcard"` (`android/app/build.gradle.kts:45`); iOS `PRODUCT_BUNDLE_IDENTIFIER = app.ixo.secbizcard` (`ios/Runner.xcodeproj/project.pbxproj:539,734,764`).

## Summary answer (the headline)

- **App Check is NOT present anywhere** — not initialized in the client (no `firebase_app_check` package in `pubspec.yaml`, no `FirebaseAppCheck...activate()` in `main.dart`) and not enforced on any Cloud Function (no `enforceAppCheck`, no `request.app` checks). State: **NOT PRESENT**.
- **Today every callable is gated ONLY by Firebase Auth** (`request.auth`). Any authenticated Firebase user — including one signed in from a forked app that merely changed its package name but still points at the owner's Firebase project — can call `recognizeCard`, the handshake functions, `getOcrUsage`, and `submitOcrFeedback`. The quota caps abuse volume but does not restrict *which app* calls.
- **BYOK bypasses the backend entirely.** The own-key path calls `https://vision.googleapis.com/...` directly from the Flutter client (`cloud_vision_recognizer.dart:66-110`). Only the SHARED-key path goes through `recognizeCard`. **Therefore enabling App Check on `recognizeCard` cannot break BYOK — it is safe.**
- The owner's app id is **NOT visible to the backend today** (Auth tokens carry the Firebase project + user, not the app package id). App identity only becomes available to the backend once App Check is enabled (its attestation is bound to the registered app/package).
- The `handleRevenueCatEvent` HTTP webhook is the one function NOT behind Firebase Auth; it uses a shared-secret `Authorization` header instead (`index.ts` ~line 430).

---

## Section A — Endpoint inventory

All callables are defined with `onCall({ cors: true })` in `functions/src/index.ts`. There is exactly one HTTP (`onRequest`) endpoint and one scheduled function. (README mentions `savePendingSession`/`getPendingSession`, but **no such functions exist in the current `functions/src` or compiled `lib`** — stale doc; `firestore.rules` still has a `pending_sessions` server-only rule.)

| Endpoint | Type | Purpose (one line) | Current auth / guard |
|----------|------|--------------------|----------------------|
| `createHandshakeSession` | onCall | Create a card-exchange session (6-char id, 10-min expiry), returns `ixo.app/{id}` | Firebase Auth only (`if (!request.auth) throw unauthenticated`) |
| `requestHandshake` | onCall | Receiver asks to exchange with a session; writes `REQUESTED`, FCM-notifies creator | Firebase Auth only |
| `respondToHandshake` | onCall | Creator approves/rejects; ownership check `creatorId == uid` | Firebase Auth + creator-ownership check |
| `returnHandshake` | onCall | Receiver returns their card back (reciprocal); `recipientId == uid` check | Firebase Auth + recipient check |
| `recognizeCard` | onCall | **SHARED-key** Cloud Vision OCR proxy, quota-gated; key never leaves server | Firebase Auth only + quota (`quota.ts`) |
| `getOcrUsage` | onCall | Return caller's monthly OCR usage/tier (admins also get global counters) | Firebase Auth only; admin branch via `ADMIN_UIDS` |
| `submitOcrFeedback` | onCall | "Report bad recognition": store sample + refund one scan, monthly cap | Firebase Auth only |
| `resolveOcrFeedback` | onCall | Admin deletes a feedback sample (image + doc) | Firebase Auth + `isAdmin` (`ADMIN_UIDS`) |
| `handleRevenueCatEvent` | onRequest (HTTP) | RevenueCat webhook → sync `users/{uid}` subscription fields | **Shared-secret header** (`REVENUECAT_WEBHOOK_AUTH`), not Firebase Auth |
| `notifyOcrFeedbackDigest` | onSchedule (cron 10:00 Asia/Taipei) | Daily FCM digest of pending feedback to owner | No external caller (scheduler-triggered) |

### Guard code evidence (quoted)

- Callables, uniform pattern, e.g. `recognizeCard`:
  ```ts
  if (!request.auth) { throw new HttpsError("unauthenticated", "Authentication required."); }
  ```
  Same `if (!request.auth)` guard appears in `createHandshakeSession`, `requestHandshake`, `respondToHandshake`, `returnHandshake`, `getOcrUsage`, `submitOcrFeedback`, `resolveOcrFeedback`.
- Ownership checks (handshake): `respondToHandshake` — `if (data?.creatorId !== request.auth?.uid) throw permission-denied`; `returnHandshake` — `if (data?.recipientId !== request.auth?.uid) throw permission-denied`.
- Admin gate: `isAdmin(request)` → `ADMIN_UIDS.includes(request.auth?.uid)` (owner UID `3XGBn4cAy3h3RhNQ3rPuavGwjAu2`).
- Webhook: `if (!isAuthorized(req.headers["authorization"], REVENUECAT_WEBHOOK_AUTH.value())) { res.status(401)... }`.

**No endpoint checks App Check, an app id, a package name, or any shared secret other than the RevenueCat webhook.**

---

## Section B — App Check current state

**State: NOT PRESENT** (neither client-initialized nor server-enforced).

Backend evidence:
- No `enforceAppCheck`, `consumeAppCheckToken`, or `request.app` usage anywhere in `functions/src` (grep returned nothing).
- `onCall` options are only `{ cors: true }` (+ `secrets`/`memory`/`timeout` on `recognizeCard`). The `onCall` default is `enforceAppCheck: false`, and `request.app` is never read, so even a present App Check token would be ignored.
- `firebase.json` contains no App Check config.

Client evidence (`SecBizCard-Apps`):
- `pubspec.yaml` Firebase deps: `firebase_core`, `firebase_auth`, `firebase_storage`, `firebase_remote_config`, `firebase_messaging` — **no `firebase_app_check`**.
- `lib/main.dart:51` initializes Firebase with `Firebase.initializeApp(options: ...)` and **no `FirebaseAppCheck.instance.activate(...)` call** before/after.
- The only `AppCheck`/`AppAttest`/`DeviceCheck` string matches are transitive CocoaPods headers under `ios/Pods/...` pulled in by GoogleSignIn (`GID*`/`GAC*`), not app code. No `PlayIntegrity`/`appAttest` provider is wired up by the app.

Conclusion: a fork pointing at the owner's Firebase project is indistinguishable from the genuine app at the backend today.

---

## Section C — CV shared vs BYOK routing, and the App-Check-on-`recognizeCard` risk

**Routing (client, `lib/features/contacts/data/services/ocr_service.dart` `recognize()` + `cloud_vision_recognizer.dart`):**

1. **Own key (BYOK)** — if a user key exists (`_settings.getApiKey()` not null), the client calls Cloud Vision **directly**:
   ```dart
   // cloud_vision_recognizer.dart recognizeWithOwnKey()
   final uri = Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$apiKey');
   resp = await http.post(uri, ...);
   ```
   This never touches the backend. Returns `VisionRecognitionResult(usedSharedKey: false)` with no `recognitionId`.
2. **Shared key** — only if there is no own key (or own-key failed and fell through), the client calls the Cloud Function:
   ```dart
   // recognizeWithSharedKey()
   final callable = _functions.httpsCallable('recognizeCard', ...);
   result = await callable.call({'imageBase64': imageBase64});
   ```
   The server (`recognizeCard`) holds `VISION_API_KEY` (Secret Manager) and calls Vision; key never ships to the client (`index.ts` `callVision()`).
3. **ML Kit** — on-device fallback for any Vision failure/quota.

Backend confirms the same split: `quota.ts` header note — *"Flex/BYOK ... runs Vision with the USER'S OWN key on the client and never reaches this backend"*; `submitOcrFeedback` only refunds when `engine === "cloud_vision_shared"`.

**Risk of enabling App Check on `recognizeCard`: effectively NONE for BYOK.** BYOK does not call `recognizeCard` at all, so enforcing App Check there cannot break the own-key flow. The only thing App Check on `recognizeCard` affects is the SHARED pool — which is exactly the intent (lock the shared pool to the owner's app; enterprises must use BYOK). The one real coupling is a **client release requirement**: enforcing App Check on `recognizeCard` requires the shipped app to first initialize App Check and attach a valid attestation, or genuine users get `unauthenticated`/`failed-precondition`. That is a backend↔app-release coupling (see Section E).

---

## Section D — Card-exchange (handshake) model + where an app-id allowlist plugs in

**Model** (`index.ts` handshake functions + `firestore.rules` `handshakes/{sessionId}`):
- Creation: `createHandshakeSession` makes a Firestore doc `handshakes/{shortHash}` with `creatorId`, `contextType`, `batchApproval`, `status:"waiting"`, `createdAt`, `expiresAt` (now + 10 min). Returns `{ sessionId, url: "https://ixo.app/{hash}" }`.
- Join / exchange: receiver calls `requestHandshake(sessionId, receiverProfile)` → doc goes `REQUESTED`, stores `recipientId = uid`, FCM to creator. Creator calls `respondToHandshake(accept, payload)` → `APPROVED`/`REJECTED` (ownership-checked). Receiver calls `returnHandshake(payload)` → `RETURNED` (recipient-checked). `DEMO0x` sessions are auto-approved with a canned profile.
- Client reads live status by subscribing **directly** to the Firestore doc: `handshake_repository.dart:187-190` — `FirebaseFirestore.instance.collection('handshakes').doc(sessionId).snapshots()`, gated by `firestore.rules` (`allow read: if request.auth != null`).
- Stored data fields: `creatorId`, `recipientId`, `contextType`, `batchApproval`, `status`, `payload`/`returnPayload` (the exchanged card data), `decisionAccept`/`decisionPayload`, timestamps, `expiresAt`.

**Is there any notion of "which app" created/joined a session? No.** No field carries an app id, package name, or licensee id. Identity on a session is purely the Firebase `uid` of creator/recipient.

**Where an app-id allowlist would plug in:**
- Natural gate = **inside `createHandshakeSession` and `requestHandshake`** (the two entry points that mint/join a session), checking the caller's attested app id against an allowlist and rejecting non-allowlisted apps before writing.
- The app id must come from an **App Check token** (see Section F) — nothing in the current Auth token exposes it.
- Add a persisted `appId` (and/or `licenseeId`) field written onto the `handshakes` doc at create time so a session records which app opened it; `requestHandshake` can then enforce an interop policy (e.g. only same-app or mutually-allowlisted apps may join). The allowlist itself is best stored server-side (e.g. a Firestore `app_allowlist` collection or a config doc) so the owner can extend it for paid licensees without a redeploy. Firestore rules remain server-only; enforcement lives in the functions.

---

## Section E — Staged hardening proposal (design input only; nothing implemented)

### Stage 1 — Lock the SHARED CV pool to the owner's app (LOW-RISK, but needs an app release)

Goal: only `app.ixo.secbizcard` can use the shared Cloud Vision pool; enterprises use BYOK.

1. Client: add `firebase_app_check`, initialize in `main.dart` right after `Firebase.initializeApp` with Play Integrity (Android) + App Attest (iOS) providers (debug provider for dev). Register the app in the Firebase console App Check for the project.
2. Backend: set `enforceAppCheck: true` on the `recognizeCard` `onCall` options (and reject when `request.app` is absent).
3. Leave BYOK untouched — it never hits the backend (Section C), so BYOK keeps working on forks (enterprises bring their own key, as intended).

Why low-risk on the backend: it's a single flag on one function, and BYOK can't break. **The care item is the client-release coupling**: once enforced, any app build without App Check init fails `recognizeCard`. Roll out order must be: ship an app version that initializes App Check → confirm attestation is flowing (App Check metrics / unenforced "monitor" mode first) → then flip enforcement. Firebase App Check supports a monitoring period before enforcement; use it. Also consider `getOcrUsage` and `submitOcrFeedback` (same shared-service family) for App Check in this stage.

### Stage 2 — Lock card-exchange + add an extensible app-id allowlist (NEEDS CARE)

Goal: card-exchange defaults to owner's app only, but the owner can extend the allowlist to PAID licensees (interop).

1. Enforce App Check on `createHandshakeSession`, `requestHandshake`, `respondToHandshake`, `returnHandshake` (`enforceAppCheck: true`).
2. Add a server-side allowlist (e.g. `app_allowlist/{appId}` docs or a config doc) defaulting to the owner's app id only; check it in `createHandshakeSession` and `requestHandshake` and reject non-allowlisted callers. Record `appId` on the handshake doc.
3. Tighten `firestore.rules` for `handshakes` so direct client reads/writes can't sidestep the allowlist. Note the client currently reads the session doc directly via `.snapshots()`, so App Check must also be enabled on Firestore (App Check supports Firestore) or the read path becomes a bypass. This is the "care" part: App Check enforcement on Firestore affects every direct Firestore access in the app, not just handshakes — stage and monitor it.

**Two trust models for an enterprise's app id:**

- **(a) Enterprise app registered under the OWNER's Firebase project.** The enterprise's package/bundle id is added as an app in Jack's Firebase project; its App Check attestation is valid for the shared backend, and its app id is added to the allowlist.
  - Pros: simplest allowlist (one project, one App Check config, app id directly comparable); no cross-project credential plumbing.
  - Cons: the enterprise app lives in Jack's project (Jack sees their app registrations, holds their App Check registration, and their users authenticate against Jack's Firebase Auth / consume Jack's project quotas unless carefully partitioned). Weak tenant isolation; billing/identity entanglement.
- **(b) Enterprise uses THEIR OWN Firebase project (per-licensee credential / cross-project App Check).** The enterprise runs their own Firebase project and App Check; the owner's backend must verify a per-licensee credential (e.g. a signed licensee token, an mTLS/shared-secret issued per licensee, or verifying the enterprise's App Check/JWT audience out-of-project) rather than a single-project App Check token.
  - Pros: clean tenant isolation; enterprise owns its users, quota accounting, and store presence; natural fit for "your額度歸你、計費歸你" and paid licensing.
  - Cons: the owner's backend can no longer rely on a single-project App Check token; needs a licensee-key issuance + verification layer and a per-licensee identity on each call. More to build and operate.

**Recommendation:** For card-exchange interop with PAID licensees, favor **(b) per-licensee credential** as the long-term model because it matches the licensing/billing-attribution goal and keeps tenants isolated — but implement it in a second step. For Stage 2's immediate default (owner-only + a couple of trusted testers), model **(a)** is enough and far cheaper: single-project App Check with a server-side app-id allowlist. Concretely: ship Stage 2 as model (a) with the allowlist defaulting to the owner's app id; design the allowlist/check so the identity key can later be swapped from "App Check app id" to "licensee credential" (model b) without reworking the call sites.

### Risk summary

| Change | Risk | App release coupled? |
|--------|------|----------------------|
| Stage 1: App Check enforce on `recognizeCard` | Low (BYOK unaffected; shared-only) | **Yes** — client must init App Check first; use monitor-then-enforce |
| Stage 1 (optional): App Check on `getOcrUsage`/`submitOcrFeedback` | Low | Yes (same app build) |
| Stage 2: App Check enforce on handshake callables | Medium | Yes |
| Stage 2: App Check on Firestore (handshake `.snapshots()` read path) | Medium–High (affects all direct Firestore reads) | Yes |
| Stage 2: server-side app-id allowlist | Low–Medium (new config + checks) | No (backend-only, if default = owner app) |
| Model (b) per-licensee credential | Higher (new issuance/verification layer) | Depends on licensee |

---

## Section F — How the owner's app id reaches the backend (today vs after App Check)

- **Today: not at all.** Firebase Auth ID tokens carry the Firebase project, the user `uid`, and provider claims (email, email_verified) — used by `isVip`/`isAdmin` — but **no app package id / bundle id**. `request.app` is never populated because App Check isn't enabled. So the backend cannot distinguish the genuine app from a repackaged fork that still authenticates against the same Firebase project.
- **After App Check (the intended gate):** `request.app` becomes available on `onCall`, and the attestation is bound to a specific registered app (Play Integrity → Android package `app.ixo.secbizcard`; App Attest → iOS bundle `app.ixo.secbizcard`). A fork that changed the package name cannot produce a valid attestation for the owner's registered app, so enforcement rejects it. This attested app identity is what a card-exchange allowlist would key off (Section D/E).

---

## Notes / stale-doc flags

- README lists `savePendingSession`/`getPendingSession`; these are **absent** from current `functions/src` and compiled `lib`. `firestore.rules` still carries a server-only `pending_sessions` rule — harmless but dead.
- The `handleRevenueCatEvent` webhook's shared-secret `REVENUECAT_WEBHOOK_AUTH` is unrelated to app-identity hardening but is the only non-Auth-gated endpoint; its secret must exist in Firebase functions:secrets before the Firebase deploy succeeds (consistent with the manual Firebase-deploy runbook).

Content was rephrased for compliance with licensing restrictions where external material would otherwise be quoted; all code citations above are from the two local repos.
