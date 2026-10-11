# Findings — app→guide deep-link locale, guide content gaps, "Secured Web Editor" rename

Read-only investigation across two sibling repos. **Nothing was modified.**

- **App (public):** `/Users/jack/_Projects/SecBizCard-Apps` — Flutter, Dart `lib/` directly at repo root (NOT `app/lib`). App id both platforms `app.ixo.secbizcard`.
- **Website (private):** `/Users/jack/_Projects/SecBizCard/website` — Nuxt 4 (Vue 3) + `@nuxtjs/i18n` + Pinia, deployed to `ixo.app`. Guide at `ixo.app/guide`, editor at `ixo.app/editor`.

Locales in play (5): `en`, `zh-TW`, `zh-CN`, `ja`, `ko`.

---

## SUMMARY ANSWER (the three questions)

1. **App→guide deep link is BROKEN for locale.** The app opens `https://ixo.app/guide?lang=<x>` with `<x>` being `languageCode` or `languageCode_countryCode` (underscore, e.g. `zh_TW`). After the site-wide-i18n migration the website uses `@nuxtjs/i18n` with **`strategy: 'no_prefix'`** and selects locale **only from a cookie (`i18n_redirected`) + browser `Accept-Language`**. **No code anywhere on the site reads `?lang=`** (a comment in `app/pages/manual.vue` even states "no ?lang= is forwarded"). So an app user always lands on whatever locale their browser cookie says — usually the site default (English) on first visit — regardless of the app's language. Fix requires a website-side change (honor `?lang=` and set the locale), because changing the app alone cannot work with `no_prefix` + already-shipped installs. Full spec below.

2. **The guide is missing two whole features the owner called out — the Secured Web Editor and the Magic Word backup password — and has no coverage of several others** (handshake history/bell, vCard/zip import UI location, Save to Google Contacts is only partially covered, subscription plans/paywall, phone verification). The web editor's own feature set (merge/find-duplicates, phone normalize, Excel table, undo, custom fields) is entirely undocumented. English draft content for every gap is in Section 2.

3. **"Secured Web Editor" rename:** On the **app** side there is one key, `backupWebEditorTitle`, in 5 ARB files — change all 5 to the literal English `Secured Web Editor` (confirming the "English in every locale, don't translate" decision). On the **website** side there is currently **NO user-facing "SecBizCard Web Editor" / "Web Editor" brand string at all** — the editor page is headed by `editor.entry.title` = "Open your encrypted backup", and the editor has no browser-tab title key. So "aligning" the website means *adding* a brand label (and, if desired, the guide section from Section 2 referring to it as "Secured Web Editor"), not renaming an existing one. Details in Section 3.

---

## SECTION 1 — app→guide deep-link locale passing

### 1a. What the app emits (exact format)

The ONLY place the app deep-links to the guide is the drawer. Evidence — `lib/core/widgets/app_drawer.dart` (the Guide link `onTap`):

```dart
// Pass the app's current locale so the web guide opens in
// the reader's language (?lang=). The web page normalizes
// the value (e.g. zh_TW → Traditional) and falls back to
// English for anything it doesn't recognize.
final locale = Localizations.localeOf(context);
final lang = locale.countryCode != null && locale.countryCode!.isNotEmpty
    ? '${locale.languageCode}_${locale.countryCode}'
    : locale.languageCode;
_dismiss(context);
launchUrl(
  Uri.parse('https://ixo.app/guide?lang=$lang'),
  mode: LaunchMode.externalApplication,
);
```

`Localizations.localeOf` returns the **resolved supported locale**, and the app's supported set is (`lib/generated/l10n/app_localizations.dart`):

```dart
static const List<Locale> supportedLocales = <Locale>[
  Locale('en'), Locale('ja'), Locale('ko'), Locale('zh'), Locale('zh', 'TW')
];
```

So the only `$lang` values the app can emit are: **`en`, `ja`, `ko`, `zh`, `zh_TW`** (underscore separator; only `zh_TW` carries a country code). Note the app has **no `zh_CN`** — Simplified Chinese is just `zh`.

Other `ixo.app` links in the app (NOT the guide, listed for completeness — none pass locale): `lib/core/app_links.dart` → `ixo.app/privacy`, `ixo.app/eula`; `lib/features/settings/.../backup_screen.dart` → `ixo.app/editor` (copied to clipboard, never opened). The guide is the only locale-bearing deep link.

### 1b. How website i18n routing works NOW (post site-wide-i18n)

`website/nuxt.config.ts` i18n block (quoted):

```ts
i18n: {
  strategy: 'no_prefix',
  defaultLocale: 'en',
  vueI18n: 'i18n.config.ts',
  locales: [
    { code: 'en',    language: 'en-US', name: 'English',  file: 'en.json' },
    { code: 'zh-TW', language: 'zh-TW', name: '繁體中文',  file: 'zh-TW.json' },
    { code: 'zh-CN', language: 'zh-CN', name: '简体中文',  file: 'zh-CN.json' },
    { code: 'ja',    language: 'ja-JP', name: '日本語',    file: 'ja.json' },
    { code: 'ko',    language: 'ko-KR', name: '한국어',    file: 'ko.json' },
  ],
  detectBrowserLanguage: {
    useCookie: true,
    cookieKey: 'i18n_redirected',
    redirectOn: 'root',
    fallbackLocale: 'en',
  },
},
```

- **`strategy: 'no_prefix'`** → there are NO locale path segments. `/zh-TW/guide`, `/ja/guide` etc. do **not** exist. Every locale is served from the same `/guide` URL.
- Locale is chosen by the **`i18n_redirected` cookie**, first populated by browser-language detection (`fallbackLocale: 'en'`). A manual switch in the footer (`app/layouts/default.vue` → `setLocale(code)`) rewrites that cookie.
- `app/pages/guide.vue` renders purely from `useI18n({ useScope: 'global' })` via `t()` / `tm()`; it never looks at the URL query. There is **no middleware/, no plugins/ directory, and no `?lang=` reader anywhere** (grep for `query.lang` / `lang=` / `setLocale` across `app/` and `i18n/` finds only the footer switcher and the `manual.vue` comment).
- Website locale codes: `en`, `zh-TW`, `zh-CN`, `ja`, `ko` (hyphen; both Chinese variants present).

### 1c. VERDICT — BROKEN, and the exact fix

**Verdict: the deep link no longer controls the guide's language.** `?lang=` is silently ignored under `no_prefix`; the guide shows the cookie/browser locale. On a fresh browser with no cookie, that's the browser's `Accept-Language` (often English for the app's non-English users). The in-code comment in `app_drawer.dart` ("The web page normalizes the value") describes behavior that **no longer exists** after the site-wide-i18n change.

**Where the fix must live: the WEBSITE.** With `no_prefix`, there is no URL the app could emit that Nuxt would turn into a locale by itself, and older app installs will keep sending `?lang=` forever — so the site must honor the query. Recommended approach:

- Add a tiny client-side locale sync on the guide route (or global middleware/app plugin): if `route.query.lang` is present, map it to a supported website locale and call `setLocale(...)` (which also persists the `i18n_redirected` cookie so it sticks). This is backward-compatible with every already-shipped app version. Keep the footer switcher as the manual override.
- Because the app's set is a subset and uses different separators/codes, the mapping must be explicit.

**App locale → website locale mapping (the normalization the website must apply to `?lang=`):**

| App emits (`?lang=`) | Meaning | Website locale code to select | Notes |
|---|---|---|---|
| `en` | English | `en` | exact |
| `ja` | Japanese | `ja` | exact |
| `ko` | Korean | `ko` | exact |
| `zh_TW` | Traditional Chinese | `zh-TW` | **separator + case differ**: app underscore `zh_TW` → website hyphen `zh-TW` |
| `zh` | Simplified Chinese (app's only "zh") | `zh-CN` | **app `zh` means Simplified**; must map to website `zh-CN`, NOT a bare `zh` |

Normalization rule the website should implement (robust to older/edge values): lowercase and replace `_`→`-`; then `zh-tw`→`zh-TW`, `zh`/`zh-cn`/`zh-hans`→`zh-CN`, `en*`→`en`, `ja*`→`ja`, `ko*`→`ko`; anything unknown → `en` (matches the old fallback intent).

**Optional, lower priority — app-side tidy (not required for the fix):** once the website honors `?lang=`, the app could emit the website's exact code (e.g. send `zh-TW` and `zh-CN`) to avoid relying on the mapping. But since the website must map legacy values anyway for shipped installs, this is cosmetic. If changed, the drawer should emit `zh-CN` for `Locale('zh')` and `zh-TW` for `Locale('zh','TW')`. **Do the website side regardless.**

---

## SECTION 2 — guide content gap vs actual product features

### 2a. App user-facing feature inventory (from `lib/features/*`, settings, services)

| Feature | One-line description |
|---|---|
| Sign in | Google or Apple sign-in; optional phone/email verification (`features/auth`, `features/verification`). |
| Profile / my card | Create and edit your own card; multiple context versions to choose which to share (`features/profile`, `context_settings_screen.dart`). |
| Handshake (card exchange) | Secure direct exchange: show your QR / scan theirs; approval prompt lets you pick which card version to share; incoming requests also under a bell icon (`features/handshake`). |
| Handshake history | List of past exchanges (`handshake_history_screen.dart`). |
| AI card scanning (OCR) | Photograph a printed card → auto contact. Auto-deskew of sideways/upside-down cards; review screen before saving (`scan_card_screen.dart`, `contact_review_screen.dart`, `manual_crop_screen.dart`). |
| OCR engine routing | Shared Cloud Vision (best) → on-device ML Kit fallback when offline (`ocrSourceCloudVisionShared`, on-device badge). |
| BYOK (own Cloud Vision key) | Add your own key in **AI Recognition** settings → unlimited best-quality scans billed to your Google Cloud account (`ocr_settings_screen.dart`, keys `ocrUseOwnKeyHeading`, `ocrUsingOwnKey`). |
| Free monthly quota + plans | Free monthly cloud scans; **Plus** (20/mo) and **Pro** (100/mo) auto-renewable subscriptions; sending feedback on a poor scan credits one scan back (`features/subscription`, `ocrYourPlan`, paywall keys, EULA §4). |
| Report a poor scan (OCR feedback) | Opt-in, per-card: sends sample to improve recognition; encrypted; deleted within 30 days (`features/storage`/OCR feedback, `ocrFeedbackPromptBody`). |
| Contacts management | View/edit/delete; add front/back card images; original scan retained; multi-select; search by name/company/title (`features/contacts` screens). |
| Export: vCard (.vcf) | Text-only standard contact file, single or multi-select (`contactDetailShareVcard`, `contact_export_service`). |
| Export: .zip (text + images) | Re-importable package with card photos (`contactExportServiceProvider`, zip path). |
| Save to Google Contacts | Save one or many straight to the Google account; optional account switch (`contactDetailSaveToGoogle`, `saveToGoogleContacts`). |
| Import vCard / .zip | Import from file or pasted text; `.vcf` or `.zip` (manifest.json + images), parsed on-device, preview before save (`vcard_import_screen.dart`). |
| AI batch import prompt | In-app AI prompt to turn a stack of card photos into an importable `.vcf`/`.zip` (`kVCardAiPrompt`). |
| Backup & Restore (Google Drive) | Encrypted backup to the user's own Drive; staleness/conflict guards; backup reminder on unsaved changes; never auto-backs-up (`backup_service.dart`, `backup_screen.dart`). |
| **Magic Word** | User-set password that encrypts the Drive backup (PBKDF2-HMAC-SHA256 ×100 000 + AES-256-GCM); shareable with a secretary to open the backup; **if lost, the backup cannot be decrypted** (`magic_word_service.dart`, `backup_codec.dart`). |
| **Secured Web Editor** | Companion desktop-browser editor at `ixo.app/editor` to bulk-organize/edit/merge contacts from the encrypted Drive backup (URL shown in backup screen; see 2b). |
| Offline / QR | Offline QR handshake path (`landingFeatureOfflineTitle`). |
| Multi-language | App follows device language; en / zh-TW / zh-CN(=`zh`) / ja / ko. |

### 2b. Web Editor feature inventory (`website/app/pages/editor.vue`, `app/components/editor/*`, `i18n` `editor.*`)

| Feature | One-line description |
|---|---|
| 3-step entry stepper | Authorize Google Drive → choose backup file → enter magic word (`EntryStepper.vue`, `editor.entry.step1/2/3Title`). |
| Google Drive connect (`drive.file`) | OAuth + Google Picker, limited `drive.file` scope; "show only the SecBizCard backup" toggle (`useDrive.ts`, `editor.picker.*`). |
| Magic-word unlock | In-browser decrypt; wrong-word retry; rejects uid-only/legacy backups with a "set a magic word in the app first" message (`MagicWordPrompt.vue`, `editor.magicWord.*`, `editor.mode.*`). |
| In-browser only / zero-upload | Decryption happens on device; data never leaves the browser; data-clearing lifecycle wipes on leave/unload (`editor.vue` §10). |
| Contact list + search + filters | Search; filters: has phone/email/company/card image (`ContactList.vue`, `ContactFilters.vue`, `editor.filters.*`). |
| Excel-style table view | Multi-column grid, content-fit widths, on-demand multi-value columns, formula bar, hide-empty-columns (`ContactTable.vue`, `editor.table.*`). |
| Contact detail / edit | Google-Contacts-style editor; typed multi-value field blocks; custom fields; card front/back image view & delete (`ContactEditor.vue`, `ContactDetail.vue`, `editor.detail.*`). |
| Phone normalization | Standardize selected phone cells (preserves country code, trunk 0, extensions); undoable (`editor.table.normalizePhone`, `editor.normalizeConfirm.*`). |
| Undo | Cmd/Ctrl+Z undo of the last change (`editor.undo.*`). |
| Add contact | Add a new contact into the backup (`editor.list.addContact`). |
| Multi-select batch | Select rows → batch delete / merge (`BatchBar.vue`, `editor.batch.*`). |
| Manual merge | Merge ≥2 selected with keep-first/second/both, not-same-person gate, preview (`MergePanel.vue`, `editor.merge.*`). |
| Find duplicates (auto-scan) | Scan for duplicate groups with confidence tiers, merge/ignore/skip (`useAutoScan.ts`, `editor.merge.autoScan`). |
| Re-pack & upload | Serialize edits back into the SBCB zip and upload to Drive; dirty-state "Leave" guard + native beforeunload prompt (`SaveBar.vue`, `editor.save.*`, `editor.leave.*`). |

### 2c. What the CURRENT guide covers (`website/i18n/locales/en.json` → `guide.sections`)

Sections present today (English source; mirrored in zh-TW/zh-CN/ja/ko):

1. Getting started (sign in, fill your card)
2. Exchange a card (Handshake) — show/scan code, approve, bell icon
3. Scan a printed card (AI OCR) — capture, review, engines, BYOK
4. Report a poor scan
5. Manage your contacts — open, card images, delete, select several, search
6. Export & share — vCard .vcf, .zip, Save to Google Contacts, assistant tip
7. Import a batch with AI — .vcf, .zip, how to import
8. AI prompt for a .zip package (copy block)
9. Back up & restore — Drive backup, restore, backup reminder
10. Free recognition — monthly free scans, feedback credit, BYOK
11. Languages

Also: `guide.vue` embeds FAQ JSON-LD (English) covering handshake, scanning/BYOK, data storage, export, AI batch import.

### 2d. GAP TABLE (feature → documented in guide?)

| Feature | In guide? | Note |
|---|---|---|
| Sign in / getting started | yes | §1 |
| Profile / my card | partial | §1 mentions filling the card; **context/multiple card versions not explained** (handshake §2 says "choose which version" but there's no "how to create versions"). |
| Handshake exchange | yes | §2 |
| Handshake history | no | not mentioned. |
| AI OCR scanning | yes | §3 |
| OCR engine routing (Cloud/on-device) | yes | §3 "Engines". |
| BYOK own key | yes | §3 + §10. |
| Free quota + feedback credit | yes | §10. |
| **Subscription plans (Plus/Pro, paywall)** | **no** | guide never mentions paid plans; only EULA does. Likely intended given stores — **flag for owner**. |
| Report a poor scan | yes | §4. |
| Contacts: view/edit/delete/search/multi-select/card images | yes | §5. |
| Export vCard / .zip / Google Contacts | yes | §6. |
| Import .vcf / .zip | yes | §7–§8. |
| Backup & restore + reminder | yes | §9. |
| **Magic Word (backup password)** | **NO** | ⚠️ owner-flagged. Not mentioned anywhere in the guide. **Critical gap** — users won't learn they can protect the backup or the lost-word consequence. |
| **Secured Web Editor (`ixo.app/editor`)** | **NO** | ⚠️ owner-flagged. Entire feature + its merge/dedupe/table/normalize capabilities undocumented. |
| Offline / QR | partial | handshake covers QR; dedicated offline behavior not called out (low priority). |
| Phone/email verification | no | optional, low priority. |
| Multi-language | yes | §11. |

**Outdated / to-verify:** The `app_drawer.dart` claim that the guide opens in the app's language is now false (Section 1). The guide's "Languages" section says "The app follows your device language automatically" — accurate for the app, but the guide page itself no longer follows the app's language via the link (Section 1 fix needed).

### 2e. English draft content for missing/outdated sections

> These are **English drafts only**. After owner approval, each must be translated to **zh-TW, zh-CN, ja, ko** and added to all five `website/i18n/locales/*.json` under `guide.sections` (same array-of-objects shape: `{ h, p?, items:[{k?,v}] }`). "Secured Web Editor" and "Magic Word" are treated as **product proper names kept in English in every locale** (consistent with the app-side decision in Section 3). Translations are a later step.

**New section — "Protect your backup with a Magic Word"** (place right after "Back up & restore"):

```
h: Protect your backup with a Magic Word
p: A Magic Word is a password you set that encrypts your Google Drive backup. Your contacts are encrypted on your device before they ever reach Drive, so nobody — not even us — can read the backup without the word.
items:
  - k: Set it
    v: In Settings → Backup & Restore, tap Set Magic Word and choose a word of 8–16 characters. Future backups are encrypted with it automatically.
  - k: Share it (optional)
    v: You can reveal and copy the stored word to give it to a trusted assistant or secretary, so they can open your backup in the Secured Web Editor on your behalf.
  - k: Changing it
    v: Change the word anytime from the same screen. A new backup is then protected with the new word; older backups still need the word they were made with.
  - k: If you lose it
    v: The Magic Word is never sent to us and cannot be recovered. If you lose it, the backup it protects cannot be decrypted — by you or anyone. Keep it somewhere safe.
```

**New section — "Edit on a computer with the Secured Web Editor"** (place after the Magic Word section):

```
h: Edit on a computer with the Secured Web Editor
p: The Secured Web Editor is a companion tool that opens in a desktop browser so you can organize a large collection of contacts far faster than on a phone. Open ixo.app/editor on a computer. Your backup is decrypted inside your browser — your data and Magic Word never reach our servers.
items:
  - k: Open it
    v: On a computer, go to ixo.app/editor.
  - k: Connect Google Drive
    v: Authorize Google Drive (the editor can only see the file you pick — the drive.file scope), then choose your SecBizCard backup.
  - k: Enter your Magic Word
    v: Unlock the backup with the Magic Word you set in the app. (Backups without a Magic Word can't be opened here — set one in the app first.)
  - k: Organize
    v: Browse, search, and filter contacts; switch to a spreadsheet-style table; edit any field; add contacts; and tidy phone numbers with one-click normalization. Undo with Ctrl/Cmd+Z.
  - k: Merge duplicates
    v: Use Find duplicates to detect likely duplicate contacts, review each group, and merge — or merge a selection manually, keeping the best of each.
  - k: Save back
    v: Choose Re-pack & upload to encrypt your edits again and write them back to your Google Drive backup. Restore in the app to pull the changes to your phone.
  - k: Let an assistant help
    v: Share your Magic Word (and access to the Drive file) with a trusted assistant so they can clean up your contacts in the editor for you.
```

**Optional new section — "Subscriptions and cloud scans"** (owner to confirm whether the guide should mention paid plans; EULA §4 already defines them):

```
h: Subscriptions and cloud scans
p: Every account gets a number of free cloud (AI) scans each month. If you need more, optional subscriptions raise your monthly allowance.
items:
  - k: Plus
    v: 20 cloud scans per month.
  - k: Pro
    v: 100 cloud scans per month.
  - k: Bring your own key
    v: Prefer no monthly limit? Add your own Cloud Vision key in Settings → AI Recognition and scan through your own Google Cloud account instead.
  - k: Manage anytime
    v: Subscriptions renew monthly until cancelled; manage or cancel them in your App Store or Google Play account settings.
```

**Small edit to the existing "Languages" / link behavior:** no guide text change needed, but ship the Section 1 website fix so the guide actually opens in the app's language.

---

## SECTION 3 — "Secured Web Editor" rename inventory

Decision confirmed: use the literal English string **`Secured Web Editor`** in all 5 locales on both sides (product proper name, not translated).

### 3a. App side — one key, 5 ARB files

`l10n.yaml` config (so a later impl regenerates correctly):

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-dir: lib/generated/l10n
```

Key: **`backupWebEditorTitle`**. Current values and exact file paths:

| File | Locale | Current value → change to |
|---|---|---|
| `lib/l10n/app_en.arb` | en | `SecBizCard Web Editor` → `Secured Web Editor` |
| `lib/l10n/app_zh_TW.arb` | zh-TW | `SecBizCard 網頁編輯器` → `Secured Web Editor` |
| `lib/l10n/app_zh.arb` | zh-CN (Simplified; file is `app_zh.arb`) | `SecBizCard 网页编辑器` → `Secured Web Editor` |
| `lib/l10n/app_ja.arb` | ja | `SecBizCard ウェブエディター` → `Secured Web Editor` |
| `lib/l10n/app_ko.arb` | ko | `SecBizCard 웹 편집기` → `Secured Web Editor` |

After editing the ARBs, regenerate (`flutter gen-l10n`, or a build) so `lib/generated/l10n/app_localizations_*.dart` pick up the new strings. The title renders in `lib/features/settings/presentation/screens/backup_screen.dart` as the `CollapsibleSection(title: l10n.backupWebEditorTitle, ...)`.

Related keys that mention "web editor" (consider for copy consistency, lower priority — these describe it, not title it): `backupWebEditorBody`, `backupWebEditorUrlCopied` in the same 5 ARB files. The owner's instruction is specifically the collapsible **title**; the body text can stay or be lightly aligned.

### 3b. Website side — there is NO existing editor brand string to rename

Searched the whole website for "Web Editor" / "SecBizCard Web" / "Secured Web" / an `editor.title` / `meta.editor` key — **none exist as user-facing brand text.** Concretely:

- `app/pages/editor.vue` has **no `useHead`/title** — the browser tab shows the global default `SecBizCard - Secure Business Card Exchange`.
- The editor's on-screen heading is `editor.entry.title` = **"Open your encrypted backup"** (`EntryStepper.vue`), not a product name.
- The landing/index page and nav do **not** link to or name the editor at all.
- i18n keys for the editor live under `editor.*` in all 5 `website/i18n/locales/*.json`; there is no title/brand key among them.

**Therefore "aligning the website" means ADDING a brand label, not renaming.** Options for a later workflow (owner to pick):

1. Add a browser-tab title + visible brand heading on `/editor` using a new key, e.g. `meta.editor.title` = `Secured Web Editor - SecBizCard` and a heading `editor.brand` = `Secured Web Editor`, placed above or alongside `editor.entry.title`. Keep the English literal in all 5 locale files.
2. Add nav/footer link to the editor labelled "Secured Web Editor" (English in all locales).
3. In the new guide section (Section 2e) refer to it consistently as "Secured Web Editor" + the URL `ixo.app/editor` — this is the lowest-effort alignment and already covered by the draft.

How the guide currently refers to the editor: **it doesn't** (that's the Section 2 gap). So once Section 2e lands, "Secured Web Editor" becomes the single canonical name across app title, website (if added), and guide.

---

## IMPLEMENTATION PLAN PREVIEW (discrete change-sets for owner approval — NONE implemented)

1. **App l10n: rename title (5 files) + regenerate.** Change `backupWebEditorTitle` to `Secured Web Editor` in all 5 ARBs; regenerate `app_localizations_*`. Optional: align `backupWebEditorBody` wording. *(App repo, next tag 1.6.4+191 per the owner's note.)*
2. **App UI: reorder the Backup screen.** Move the Web Editor `CollapsibleSection` in `backup_screen.dart` to **below** the Back Up Now + Restore buttons (currently it sits between the Magic Word section and the buttons). *(App repo.)*
3. **App guide-link locale (optional/cosmetic).** Optionally make `app_drawer.dart` emit the website's exact codes (`zh-CN`/`zh-TW`); not required once change-set 4 ships. Fix/remove the stale "web page normalizes the value" comment. *(App repo.)*
4. **Website: honor `?lang=` on the guide (REQUIRED fix for the broken deep link).** Add a client-side locale sync (route/global middleware or plugin) that maps `?lang=` → website locale via the table in 1c and calls `setLocale`, persisting the cookie. Backward-compatible with all shipped app installs. *(Website repo — MANUAL Firebase deploy; coordinate per cicd rule.)*
5. **Website: guide content additions.** Add the Magic Word, Secured Web Editor, and (if approved) Subscriptions sections to `guide.sections` in `en.json`; mirror structure. *(Website repo.)*
6. **Website: 4-locale translation.** Translate the new guide sections into zh-TW, zh-CN, ja, ko (keeping "Secured Web Editor" / "Magic Word" as English proper names). Also consider zh-TW/zh-CN/ja/ko for any new editor brand keys. *(Website repo — later step, needs qa-localization.)*
7. **Website: editor title alignment (optional, owner to choose scope).** Add a `Secured Web Editor` brand (tab title + heading, and/or nav link) on `/editor` as new i18n keys, English in all 5 locales. *(Website repo.)*
8. **Store-copy / docs sync.** Update the 1.6.4 submission docs and any guide references to the new title and the two new guide sections; record the deep-link fix. *(Both repos' docs; store listings.)*

> Deploy coupling reminder (from repo rules): website + Firebase changes deploy **manually** via `firebase_deploy.yml`, and the app↔functions contract is coupled — ship website guide/editor changes deliberately alongside the matching app release. No backend/functions change is required for any of the above (the deep-link fix is front-end only).

---

### Evidence index (key files read)
- App link: `lib/core/widgets/app_drawer.dart`; supported locales `lib/generated/l10n/app_localizations.dart`; other links `lib/core/app_links.dart`, `lib/features/settings/presentation/screens/backup_screen.dart`.
- App l10n: `l10n.yaml`; `lib/l10n/app_{en,zh_TW,zh,ja,ko}.arb` (key `backupWebEditorTitle`).
- Magic word crypto: `lib/core/services/backup_codec.dart` (PBKDF2-HMAC-SHA256 ×100000, AES-256-GCM, 16B salt, 12B nonce, 16B tag), `backup_service.dart`.
- App features: `lib/features/*` screens, `lib/features/settings/presentation/screens/ocr_settings_screen.dart`, `lib/l10n/app_en.arb`.
- Website i18n: `website/nuxt.config.ts`, `website/i18n/locales/en.json`, `website/app/layouts/default.vue`, `website/app/app.vue`, `website/app/pages/{guide,editor,manual}.vue`, `website/app/components/editor/EntryStepper.vue`.

*Content from the two repositories was read for investigation; all draft copy above is original.*
