# i18n Audit — hardcoded UI strings still to localize

Snapshot: 2026-09-23. Purpose: the app has ~170 hardcoded English UI strings
across ~25 screens that never went through l10n (a long-standing debt, unrelated
to the subscription work). This is the inventory so we can localize in
deliberate batches rather than one giant risky pass.

Locales: en (template, authoritative), zh-TW (authoritative), zh-CN, ja, ko
(ja/ko machine-translated per the project convention).

**Keep in English across ALL locales (brand / slogan / functional labels)** —
do NOT translate these:
- `Scan to Exchange` (QR screen slogan) — key `qrScanToExchange`
- `Share` / `Card` (main screen tab titles) — keys `navShare` / `navCard`
- `Notifications` — key `navNotifications`
- Tier names `Basic` / `Plus` / `Pro` / `VIP` / `Flex`, and `BYOK`
- Tech acronyms `CV` / `OCR` / `AI`
- Product brand names `SecBizCard Plus` / `SecBizCard Pro`

---

## Count of hardcoded strings per file (rough, from grep)

| # strings | File | Priority |
|----------:|------|----------|
| 32 | features/handshake/presentation/screens/handshake_screen.dart | P1 (core flow) |
| 29 | features/contacts/presentation/screens/contact_detail_screen.dart | P1 |
| 28 | features/settings/presentation/screens/backup_screen.dart | P2 |
| 23 | features/profile/presentation/screens/edit_profile_screen.dart | P1 |
| 21 | features/contacts/presentation/screens/vcard_import_screen.dart | P2 |
| 19 | features/profile/presentation/screens/profile_screen.dart | P1 |
| 19 | features/landing/presentation/landing_screen.dart | P3 (web landing) |
| 17 | features/onboarding/presentation/screens/onboarding_screen.dart | P1 (first run) |
| 17 | features/home/presentation/screens/main_screen.dart | P1 (nav titles — partly done: navShare/navCard/navNotifications keys added) |
| 16 | features/handshake/presentation/screens/qr_display_screen.dart | **IN PROGRESS this batch** |
| 16 | features/contacts/presentation/screens/scan_card_screen.dart | P1 (scan flow) |
| 16 | features/contacts/presentation/screens/edit_contact_screen.dart | P2 |
| 15 | core/widgets/app_drawer.dart | P1 (nav drawer) |
| 12 | features/handshake/presentation/screens/handshake_history_screen.dart | P2 |
| 11 | features/verification/presentation/screens/phone_verification_screen.dart | P2 |
| 11 | features/profile/presentation/screens/context_settings_screen.dart | P2 |
| 9  | features/handshake/presentation/widgets/incoming_request_sheet.dart | P1 (exchange flow) |
| 8  | features/verification/presentation/screens/email_verification_screen.dart | P2 |
| 8  | features/handshake/presentation/screens/qr_scanner_screen.dart | P1 (scan flow) |
| 7  | features/contacts/presentation/screens/contacts_list_screen.dart | P1 |
| 5  | features/home/presentation/screens/home_screen.dart | P2 |
| 4  | features/contacts/presentation/screens/manual_crop_screen.dart | P2 |
| 4  | core/utils/dialog_utils.dart | P1 (shared dialogs) |
| 3  | features/contacts/presentation/screens/contact_review_screen.dart | P2 |
| 1  | main.dart | P3 (init-error fallback only) |
| 1  | features/auth/presentation/screens/login_screen.dart | P1 |

Already localized (reference / no work): ocr_settings_screen.dart,
ocr_feedback_dialogs.dart, async_value_ui.dart.

**Total: ~170 strings.** These grep counts are approximate (include some false
positives like enum/status literals); treat as sizing, not exact.

---

## Suggested batching (deliberate, reviewable)

- **Batch 0 (this subscription batch):** qr_display_screen (in progress) +
  main_screen nav titles (keys added). Ship with the subscription build.
- **Batch 1 — core exchange + first run (P1):** handshake_screen,
  incoming_request_sheet, qr_scanner_screen, contacts_list_screen,
  contact_detail_screen, edit_contact_screen, scan_card_screen, profile_screen,
  edit_profile_screen, onboarding_screen, app_drawer, dialog_utils, login_screen.
- **Batch 2 — settings / secondary (P2):** backup_screen, vcard_import_screen,
  handshake_history_screen, phone/email_verification_screen,
  context_settings_screen, home_screen, manual_crop_screen, contact_review_screen.
- **Batch 3 — web/edge (P3):** landing_screen, main.dart init-error fallback.

Do each batch as its own commit; run `flutter gen-l10n` + `flutter analyze`
after each. ja/ko strings are machine-translated; zh-TW/en are authoritative.

## Method (per file)
1. Find hardcoded strings (Text/SnackBar/title/hintText/labelText/tooltip/dialog).
2. Add keys to app_en.arb (with placeholders for interpolated values).
3. Add the 4 locale translations (en/zh-TW authoritative; zh-CN/ja/ko follow).
4. Replace in the .dart with `AppLocalizations.of(context)!.<key>`.
5. gen-l10n + analyze; verify no untranslated warnings.
