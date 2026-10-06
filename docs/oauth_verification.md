# OAuth App Verification — SecBizCard (`ixo-app-secbizcard`)

> Source of truth for completing Google OAuth app verification. The project uses
> one **sensitive** scope (`contacts`) that triggers the "Google hasn't verified
> this app" screen until verification is approved. `drive.file` is non-sensitive
> and does NOT require verification; it is only listed because it is part of the
> consent screen.

## Why we must verify (do not skip)

The mobile app's "Save to Google Contacts" feature (People API `createContact` /
`people.get` in `lib/features/contacts/data/contacts_repository.dart`) requires
the **read/write Contacts** scope. The product owner decided this feature stays,
so the project is committed to OAuth verification. The web editor itself only
uses `drive.file`, but the consent screen is shared project-wide, so the app's
`contacts` scope governs the whole brand's verification status.

## Scopes the app/web actually request

| Scope | API | Classification | Needs verification? |
|-------|-----|----------------|---------------------|
| `https://www.googleapis.com/auth/contacts` | People API (createContact, people.get) | **Sensitive** | ✅ YES |
| `https://www.googleapis.com/auth/drive.file` | Drive API (per-file) | Non-sensitive | ❌ No |
| `openid` | Sign-In | Non-sensitive | ❌ No |
| `.../auth/userinfo.email` | Sign-In | Non-sensitive | ❌ No |
| `.../auth/userinfo.profile` | Sign-In | Non-sensitive | ❌ No |

`contacts` is **sensitive**, not restricted → standard verification, **no CASA
third-party security assessment required**.

## Pre-requisites (status)

- [x] Brand verified (app name, logo, support email) — done earlier this session.
- [x] Domain `ixo.app` ownership verified in Search Console (same Google account
      as the GCP project: cokefever@gmail.com).
- [x] Privacy Policy live: https://ixo.app/privacy
- [x] Terms of Service / EULA live: https://ixo.app/eula
- [x] Publishing status = In production.
- [ ] `contacts` scope ADDED to the consent screen's scope list (Data Access page).
- [ ] Verification submitted with justification + demo video.

## Steps

### 1. Add the `contacts` scope to the consent screen
Data Access page:
`https://console.cloud.google.com/auth/scopes?project=ixo-app-secbizcard`
→ "Add or remove scopes" → manual add box →
`https://www.googleapis.com/auth/contacts`
→ Update → Save. It will now appear under **Sensitive scopes** (not non-sensitive).
Adding it will surface a **"Submit for verification" / "Prepare for verification"**
prompt — that is the entry point for step 3.

### 2. Make sure the app actually requests `contacts` at runtime
The consent screen scope list and the runtime request MUST match (scope mismatch
is itself a cause of the unverified screen). Confirm the People API path requests
the `contacts` scope explicitly where the authenticated client is built
(`contacts_repository.dart`). If it currently relies on ambient authHeaders, add
`contacts` to the requested scopes so request ⊆ registered.

### 3. Submit for verification
From the Overview or Data Access page, start the verification request. Google
will ask for:
- **Scope justification** (why `contacts` is needed) — see text below.
- **A demo video** (YouTube, unlisted is fine) showing the OAuth consent screen
  and the feature that uses the scope (Save to Google Contacts), end to end.
- Confirmation of the privacy policy URL and that it describes the data use.

### 4. Scope justification (paste into the request)

> SecBizCard is a business-card manager. Users scan or exchange business cards and
> store them as contacts inside the app. The `https://www.googleapis.com/auth/contacts`
> scope powers an explicit, user-initiated "Save to Google Contacts" action: when
> the user chooses to export a card (individually, in a batch, or when accepting a
> card exchange), the app writes that contact into the user's own Google Contacts
> via the People API `createContact` method, and reads back the created record to
> confirm success. We only create/update contacts the user explicitly chooses to
> save. We do not bulk-read, sell, or share the user's contacts, and we do not use
> contacts data for advertising. The data stays between the user's device and the
> user's own Google account.

### 5. Demo video checklist (what Google wants to see)
- Open the app, show the Google OAuth consent screen with the SecBizCard brand.
- Show the exact feature that uses `contacts` (tap "Save to Google Contacts" on a
  card / accept a card exchange with "add to contacts" checked).
- Show the contact appearing in Google Contacts afterward.
- Keep it short (1–3 min), unlisted YouTube link.

## After approval
- The "unverified app" screen disappears for all users (app + web editor), and the
  100-user cap is lifted.
- Existing accounts that already granted the old scopes may need to re-consent to
  pick up the exact registered scope set.

## Note on the web editor's "unverified" warning (interim)
Until verification is approved, the web editor (ixo.app/editor) will still show the
warning because it shares the project's consent screen. Use "Advanced → continue"
to test. This is expected and not a bug.
