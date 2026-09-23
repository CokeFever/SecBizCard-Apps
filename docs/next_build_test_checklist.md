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
