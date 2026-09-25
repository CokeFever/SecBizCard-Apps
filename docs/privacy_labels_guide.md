# Privacy Labels Guide — App Store App Privacy + Play Data Safety

Truthful inventory of what the app collects / stores / transmits, mapped to the
store privacy questionnaires. Based on a code audit (auth, profile, OCR,
handshake, subscription, storage). Update both stores AND the privacy policy
so they're consistent — reviewers cross-check.

## TL;DR of what changed for the subscription release
- **NEW: "Purchases" data type** — RevenueCat receives the Firebase uid
  (app_user_id) + the store purchase receipt to manage entitlements. This is
  the main addition. Everything else was already true pre-subscription.

---

## What the app actually does (ground truth)

### Identity / account
- Sign-in: **Google** and **Apple** only (OAuth → Firebase Auth). No email/password.
- Collected: uid, **email**, **display name**, **photo** (from the provider).
- **Phone**: optional phone verification via Firebase Auth SMS OTP; the number is
  bound to the Firebase Auth account and stored locally.
- Account deletion is implemented (Apple 5.1.1(v) requirement met).

### Profile / contacts
- The user's own card + saved contacts are stored **locally** (sqflite), not in
  the cloud. Images (avatar, card front/back, scanned cards) are local files.
- The only thing written to Firestore `users/{uid}` is the **FCM push token**,
  the **subscription state** (from the RevenueCat webhook), and OCR-feedback
  contribution counts.

### Business-card OCR
- Image is sent for OCR to **Google Cloud Vision**:
  - BYOK: the client calls Vision directly with the user's own key.
  - Shared key: image goes to our Cloud Function `recognizeCard`, which calls
    Vision server-side. The shared key never reaches the client.
  - Offline fallback: on-device ML Kit (never leaves the device).
- Normal OCR does **not** store the photo in the cloud. The card photo is only
  uploaded (to Firebase Storage `ocr_feedback/{uid}`) when the user **explicitly
  consents** to "report bad recognition", and it's kept **30 days** (TTL).

### Handshake (card exchange)
- Exchanged contact data passes **briefly** through Firestore `handshakes/{id}`
  (10-min `expiresAt`) as a relay; payload can be encrypted. The received
  contact is then stored **locally**. The cloud session is transient, not a
  long-term card store.

### Subscription / purchases
- **RevenueCat** (`purchases_flutter`). app_user_id = Firebase uid. RevenueCat
  receives the uid + the platform purchase receipt; the backend stores
  `subscriptionActive / subscriptionTier / renewsAt` on `users/{uid}`.

### Analytics / tracking / ads
- **None.** No Firebase Analytics, no Crashlytics, no ad SDK, no IDFA, no
  cross-app tracking. (So iOS needs **no** ATT prompt.)
- Uses: Firebase Auth, Firestore, Storage, Functions, Messaging (FCM push
  token), Remote Config (config only). Android `play_install_referrer` for
  deferred deep-links (not advertising).

### On-device secure storage
- flutter_secure_storage (Keychain / Keystore) holds ONLY the user's own Cloud
  Vision API key. Never leaves the device.

---

## Apple — App Privacy (App Store Connect → App Privacy)

For each type: is it **collected**? **linked to identity**? used for **tracking**?
Tracking = NO for everything (no ATT needed).

| Data type | Collected | Linked to user | Purpose |
|-----------|-----------|----------------|---------|
| Contact Info → Email address | Yes | Yes | App Functionality (account) |
| Contact Info → Name | Yes | Yes | App Functionality (profile) |
| Contact Info → Phone number | Yes | Yes | App Functionality (optional verification) |
| Contact Info → Physical address | Yes | Yes | App Functionality (card fields, mostly local) |
| **Purchases** | **Yes** | **Yes** | **App Functionality (manage subscription)** ← NEW |
| Identifiers → User ID | Yes | Yes | App Functionality (Firebase uid) |
| User Content → Photos (card images) | Yes | Yes | App Functionality (OCR; cloud only on consented feedback) |
| User Content → Other (card text) | Yes | Yes | App Functionality |
| Identifiers → Device ID (FCM push token) | Yes | Yes | App Functionality (notifications) |

- Tracking: **None** for all.
- Data used to track you: **No**.
- Account deletion: **Yes**, in-app (Profile → Delete Account).

## Google Play — Data Safety

Data collected/shared, all "App functionality", no tracking/ads:
- Personal info: Name, Email, Phone number, Address → collected, linked, app functionality.
- **Financial info: Purchase history → collected, linked, app functionality** ← NEW (RevenueCat/subscription).
- Photos: business-card images → collected (cloud only on consented feedback).
- App activity / other: OCR text (only on consented feedback).
- App info & performance: none (no crash/analytics SDK).
- Device IDs: FCM token (app functionality, notifications).
- Security: data encrypted in transit (HTTPS); user can request deletion (in-app account delete).

Third parties that receive data: Google (Firebase, Cloud Vision), RevenueCat,
Apple/Google billing. Optional user-controlled: their own Google Drive (backup).

---

## Privacy policy (ixo.app/privacy) — sections to add/confirm
The policy text should mention (to match the labels reviewers cross-check):
- Use of **RevenueCat** to process subscriptions and store purchase/entitlement data.
- Collection of **subscription status / purchase history**.
- OCR via **Google Cloud Vision**; card photos are not retained in the cloud
  except when the user opts into bad-recognition feedback (kept 30 days).
- Third parties: Google Firebase, Google Cloud Vision, RevenueCat.
- In-app **account deletion** and how to request data deletion.

## Notes
- If the app was already live pre-subscription, most labels are already set;
  the concrete change is **adding Purchases / Purchase history**.
- Keep it truthful — Apple/Google audit and reject mismatches.
