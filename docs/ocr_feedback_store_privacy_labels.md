# Store Privacy Labels — OCR Feedback feature

Fill-in checklist for the App Store / Play Store privacy disclosures that the
optional "report bad recognition" (OCR feedback) feature requires. These are
configured in the store consoles (not in code). Everything below is aligned to
the in-app consent copy (`ocrFeedbackTermsBody`), the 30-day retention, and the
uid-scoped Storage upload implemented in this release.

> ⚠️ Only mark these once the feature actually ships in a build. If a release
> does NOT include the OCR feedback feature, the labels must NOT claim image
> collection. Labels must match real behavior exactly.

---

## What the feature collects (source of truth)

| Data | Collected? | Sent when | Purpose | Retention |
|------|-----------|-----------|---------|-----------|
| Card recognized text + layout | Yes (opt-in, each time) | User taps "Agree and send" | Improve OCR accuracy | ≤ 30 days |
| Recognition result (parsed fields) | Yes (opt-in) | same | Improve OCR accuracy | ≤ 30 days |
| Card **photo** (image) | Yes (opt-in) | same | Reproduce/fix recognition errors | ≤ 30 days |
| Account UID | Yes (implicit) | same | Scope upload + submit cap + refund | ≤ 30 days |

- **Processors:** Google Cloud Vision (recognition), Firebase / Google Cloud Storage (storage).
- **Not** used for advertising or tracking. **Not** sold. **Not** shared with third parties for their own purposes.
- Fully optional and confirmed per-submission.

---

## Google Play — Data safety form

**Does your app collect or share any of the required user data types?** → Yes.

Declare these data types (Collected = Yes; Shared = No — processors acting on
our behalf are not "sharing" under Play's definition, but confirm current Play
policy at submission):

1. **Photos and videos → Photos**
   - Collected: Yes · Shared: No
   - Processed ephemerally: No (stored up to 30 days)
   - Required or optional: **Optional**
   - Purposes: **App functionality** (and, if offered, "Analytics"/product
     improvement — pick the closest: App functionality is the safest fit since
     it improves recognition, not ad analytics)

2. **App activity / App info & performance → "Other" (OCR text + recognition result)**
   - If no exact type fits the recognized card text, use the closest
     "Other user-generated content" / "Other data" bucket.
   - Collected: Yes · Shared: No · Optional: Yes · Purpose: App functionality

3. **App info and performance → Diagnostics** (appVersion / ocrPkgVersion / engine)
   - Optional metadata sent with the sample. Purpose: App functionality.

**Security practices:**
- Data is encrypted in transit: **Yes**
- Users can request data deletion: **Yes** (via privacy@ixo.app; also auto-deleted ≤ 30 days)
- Committed to Play Families policy: N/A unless targeting children (not targeted)

**Data deletion:** point the deletion request channel to `privacy@ixo.app`.

---

## Apple App Store — App Privacy

Add these under **App Privacy → Data Types**. For each, purpose = **App
Functionality** (or **Product Personalization**/**Analytics** only if you
genuinely use it that way — App Functionality is the accurate choice here).

1. **User Content → Photos or Videos** (the card photo)
   - Linked to user: **Yes** (uid-scoped upload)
   - Used for tracking: **No**
   - Purpose: App Functionality

2. **User Content → Other User Content** (recognized card text + result)
   - Linked to user: Yes · Tracking: No · Purpose: App Functionality

3. **Identifiers → User ID** (Firebase Auth uid)
   - Linked to user: Yes · Tracking: No · Purpose: App Functionality

- **Data Used to Track You:** None.
- **Data Linked to You:** the three items above.
- Ensure the app's Privacy Policy URL points to https://ixo.app/privacy (now
  includes the "OCR Recognition Feedback" section).

---

## Cross-checks before submitting

- [ ] Build actually contains the OCR feedback feature (else remove image claims).
- [ ] `ocrFeedbackTermsBody` in-app copy matches these labels (photo + 30 days).
- [ ] Privacy Policy (/privacy) OCR section is live on the site.
- [ ] Storage rules + 30-day lifecycle deployed; Firestore TTL = 30 days.
- [ ] Deletion request channel (privacy@ixo.app) is monitored.
- [ ] Legal review of the consent copy + labels (not a substitute for counsel).
