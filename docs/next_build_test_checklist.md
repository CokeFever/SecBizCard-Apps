# Next Build — Test Checklist

Covers everything committed **after** `1.6.0+170` (the tagged `android/v1.6.0` /
`ios/v1.6.0` build currently on the test tracks). Two independent bodies of
work: a full-app **i18n pass** and an **app-level OCR tier cache** refactor.

- Current version (still un-bumped): `1.6.0+170`
- These changes are NOT in the 1.6.0 test build. Bump + re-tag when building the
  next version to test them (see "Build & tag" at the bottom).

---

## Part A — i18n (localization) pass

All user-facing screens were localized across **5 locales**: `en`, `zh-TW`,
`zh`, `ja`, `ko`. Test approach: switch the device/system language and walk the
screens; check for (1) untranslated leftovers, (2) layout overflow/truncation,
(3) params landing in the right place.

Kept in English on purpose (should NOT be translated): `Scan to Exchange`
slogan, nav labels (`Share`/`Card`/`Notifications`), tier names
(`Basic/Plus/Pro/VIP/Flex`), `BYOK`, `CV`/`OCR`/`AI`, `SecBizCard Plus/Pro`,
`vCard`/`.vcf`/`.zip`, App Store / Google Play badge text, `EULA`, the vCard
sample hint, and the AI-prompt clipboard text.

Screens to eyeball per locale (esp. zh-TW, ja, ko for length):

- [ ] Onboarding (all 4 steps) — `IXO` should read `SecBizCard`
- [ ] Login (sign-in error text)
- [ ] Main shell: Share / Card tab titles stay English; search hint; multi-select
      bar ("N selected"), Export sheet, backup-reminder dialog
- [ ] App drawer + unsaved-changes dialog
- [ ] QR share screen + "Generating secured QR code…" placeholder
- [ ] QR scanner (permission-denied copy) + camera-unavailable / retry
- [ ] Scan card screen (hint, toggles Horizontal/Vertical, tier badge)
- [ ] Contact review / manual crop
- [ ] Contacts list, contact detail (labels + "copied" toasts + share menu)
- [ ] Edit profile / edit contact (fields, dialogs, add-field)
- [ ] Handshake + incoming-request sheet + handshake history (status badges)
- [ ] Profile (view + delete-account flow)
- [ ] Context settings (Business/Social/Lite + toggles)
- [ ] Backup & restore (status messages red/green, dialogs)
- [ ] vCard import (steps, options, preview)
- [ ] Email + phone verification (all states, resend timer)
- [ ] Landing page (web) — hero, features, footer
- [ ] zh-TW specifically uses "重設" (not "重置") for reset
- [ ] "Resets in {time}" reads naturally per locale (param can reposition)

Regression sanity (localization delegate wiring):

- [ ] App launches and renders in the device language (falls back to en for
      unsupported locales)

---

## Part B — App-level OCR tier cache (cache-first + background revalidate)

Replaces the per-screen on-entry `getOcrUsage` call (which caused a visible
delay/flicker) with one shared, per-uid, disk-cached provider that is prefetched
at app start and revalidated in the background.

**These behaviours are runtime-only — analyze/compile can't verify them. Test on
a real device (ideally the non-VIP test account `cokeliebhaber@gmail.com`, since
the owner VIP account masks finite tiers).**

Core behaviour:

- [ ] Open **AI Recognition** screen → tier card shows the correct tier
      **instantly** (no spinner flash / no momentary "Basic" flicker) on a warm
      start
- [ ] Open **Scan card** screen → the top-right engine/quota **badge appears
      immediately** (from cache), not after a delay
- [ ] Cold start (first launch after install / cleared cache): tier resolves
      within a moment via network; no crash, no permanent spinner

Cache invalidation triggers (the part to exercise carefully):

- [ ] **Purchase** a plan → after the "Thanks for subscribing" toast, the tier
      card updates to the new tier (Plus/Pro) without needing to leave/re-enter
- [ ] **Restore** purchases → tier re-syncs
- [ ] **Entitlement change while app is open** (e.g. sandbox renewal/expiry, or
      change from another device) → RevenueCat listener refreshes the tier
- [ ] **BYOK**: add a Cloud Vision key → AI Recognition shows **Flex / "BYOK"**
      and scan badge shows the own-key engine; **remove** the key → reverts to
      the real backend tier
- [ ] **Logout → login as a different user** → tier reflects the NEW user, never
      the previous user's tier (per-uid cache; cleared on logout)
- [ ] **Offline**: open both screens with no network → shows last cached tier
      (or the shared-key badge without a count); no crash

Safety / correctness (cache must never grant wrong quota):

- [ ] After a plan **expires** but before the UI refreshes, actually scanning a
      card is still gated correctly by the backend (cache only affects display,
      not the real quota). Confirm a scan over-quota is blocked server-side even
      if the tier card momentarily shows a stale higher tier.
- [ ] Admin/owner account still shows the admin observability counters
      (shared800 / total) on the AI Recognition tier card

Startup wiring:

- [ ] No noticeable regression to QR-code generation speed on the Share tab
      (the OCR prefetch shares the login→home warm-up path)

---

## Build & tag (next version)

When 1.6.0 checks out and you're ready to build the next version to test the
above:

1. Bump `version:` in `pubspec.yaml` (e.g. `1.6.1+171`).
2. Regenerate l10n + codegen if building clean: `fvm flutter gen-l10n` and
   `fvm dart run build_runner build --delete-conflicting-outputs`.
3. Commit the bump.
4. Tag per platform (same commit), which drives the release pipelines:
   - `android/v<ver>` → GCP Cloud Build → Play internal testing
   - `ios/v<ver>` → Xcode Cloud → TestFlight
   (Bare `v*` tags are retired. See `.agent/workflows/deploy_release.md`.)

Reminder: Flutter stays pinned **3.38.9** across all pipelines — do not use
"stable".

---

## Part C — Subscription state-machine fixes (build 1.6.0+172)

Context: on 1.6.0+171 the Android purchase flow showed multiple problems — buying
Plus then Pro left BOTH active (each billing), ~20 sandbox order emails, tier
updated only after leaving+returning, cancel reflected only after app restart.
Root cause: the app never passed a Google **product-change** on upgrade (Play
stacked a 2nd independent subscription), the UI waited on the backend webhook
instead of RevenueCat's returned tier, there was no foreground refresh, the
paywall showed the already-owned tier, and the backend webhook was
last-event-wins (a late Plus renewal could overwrite an active Pro).

Fixes shipped in **1.6.0+172** (app) + a backend deploy (already live):
- App: `purchase()` passes `StoreProductChangeInfo(withTimeProration)` with the
  current active product id → Play REPLACES instead of stacking.
- App: optimistic tier update from RevenueCat's purchase/restore result, then
  `refresh()` reconciles used/cap.
- App: paywall hides the already-owned tier (Plus sees only Upgrade to Pro).
- App: OCR tier refreshes on app resume (foreground).
- Backend (DEPLOYED via firebase_deploy.yml): `shouldPersistDecision` — a
  lower-tier event can't clobber an active higher tier; an expire/cancel only
  clears the tier it actually refers to.

### BEFORE re-testing — clean the leftover sandbox state
The earlier test left TWO concurrently-active sandbox subscriptions (Plus + Pro)
and purchases attached to a RevenueCat anonymous id. Start clean:
1. Google Play (test account `cokeliebhaber@gmail.com`) → Subscriptions →
   **cancel** any active SecBizCard Plus/Pro test subs (they also auto-expire on
   the 5-min sandbox cycle).
2. RevenueCat Dashboard → Customers → delete the anonymous customer
   (`$RCAnonymousID:...`) and/or the test customer, so entitlements start fresh.
3. Optionally wait for the sandbox subs to fully expire before retesting.

### Re-test checklist (Android internal + iOS TestFlight)
- [ ] Sign in with Google `cokeliebhaber@gmail.com` (non-VIP).
- [ ] Subscribe to **Plus** → tier card shows **Plus almost immediately**
      (optimistic), then settles to `Plus x/20`. No leaving+returning needed.
- [ ] From Plus, tap **Upgrade to Pro** → the paywall shows **only Pro** (Plus
      hidden). Purchase → Play should say it's a **plan change/replacement**,
      not a new subscription.
- [ ] After upgrade: Google Play → Subscriptions shows **only ONE active** sub
      (Pro), NOT Plus+Pro. Tier card shows **Pro** (settles to `Pro x/100`).
- [ ] Far fewer order emails than before (ideally one per real change; sandbox
      5-min renewals still generate some — that's Play, not a bug).
- [ ] Cancel the sub in Google Play → return to the app (foreground) → tier
      reflects the change without needing an app restart (once the webhook +
      resume-refresh land).
- [ ] Tier never flips backwards on its own (backend reconciliation): once Pro,
      a stray Plus renewal event must not drop it back to Plus.
- [ ] Known limitation (do NOT file as a bug): a true DOWNGRADE Pro→Plus can
      briefly show Basic for one cycle if events arrive out of order. Deferred.

### If tier still doesn't update
- Check RevenueCat Dashboard → that customer → `app_user_id` == Firebase uid
  (not `$RCAnonymousID`) and the entitlement is active.
- Check the webhook is hitting the (now redeployed) `handleRevenueCatEvent`
  (RevenueCat → Integrations → Webhooks → recent deliveries = 200).

### Manage subscription + Restore links (build 1.6.0+173)
Product rule: no in-app downgrade. Plans only go up (Basic→Plus→Pro) or are
cancelled (→ expire → Basic). Cancel happens on the store, reached via the
in-app "Manage subscription" link. Verify:
- [ ] **Basic**: tier card shows the Subscribe button only; no Manage/Restore
      row (those live in the paywall sheet).
- [ ] **Plus**: tier card shows "Upgrade to Pro" + a row with "Manage
      subscription" and "Restore purchases".
- [ ] **Pro**: tier card shows **no upgrade/downgrade button** — only "Manage
      subscription" + "Restore purchases".
- [ ] Tap **Manage subscription** → opens the Google Play (or Apple) manage-
      subscription page for this app externally. Cancelling there → back in app
      (foreground) → tier returns to Basic after expiry.
- [ ] Tap **Restore purchases** while already Pro → stays Pro, shows the restore
      snackbar (no error).
- [ ] Fresh reinstall + sign in with the same Google account → tier is detected
      automatically WITHOUT tapping Restore (logIn + webbook sync); Restore is
      only the fallback / Apple 3.1.1 requirement.
