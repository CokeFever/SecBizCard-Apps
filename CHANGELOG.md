# Changelog

## [1.5.8] - 2026-09-20

### Added
- **Import**: Bring in a whole batch of cards at once with an AI assistant. Alongside a `.vcf` (text), the Import screen now also accepts a `.zip` package that carries the contact details **and** cropped card images, so imported contacts arrive with their card photos. Everything is processed on your device.
- **Export**: Exporting a contact (or a multi-selection) now offers three choices — text-only vCard (`.vcf`), a `.zip` that also includes the card images and can be re-imported, or Save to Google Contacts.
- **Backup reminder**: Because your data is stored on your device, the app now gives a gentle, occasional reminder to back up to your own Google Drive when you have unsaved changes. It never backs up automatically, and you can turn the reminder off for the month.

### Changed
- **Contact card images**: A contact can now hold a front and back card photo, edited in the Edit screen. When a card has front/back photos they are shown instead of the raw scan; a scanned card still keeps its original capture, which you can view and delete from Edit.

### Fixed
- **Contacts**: Removed a multi-select "select all" control that did not reliably clear the selection.

## [1.5.7] - 2026-09-18
### Fixed
- **Scan**: A promotional line on a card (such as "Follow us" or a social handle) is no longer mistaken for the person's name.
- **Scan**: Names written as initials plus characters (for example "HC Lo 羅宏哲") are now recognized correctly instead of losing out to other text on the card.
- **Scan**: A postal code sitting on a city line (for example "Taipei 110016") is no longer captured as a phone number.

## [1.5.6] - 2026-09-16
### Fixed
- **Scan**: Cards that were captured rotated or upside-down are now automatically turned upright before review, using the recognized text's direction. This also stops the person's name from being misread as the job title on a flipped card.
- **Scan**: Improved name detection so the real name wins over a large job title, even when the card is captured at an angle or the layout is unusual.
- **QR / Share**: Replaced the empty grey placeholder shown while the exchange QR is being prepared with a simple spinner, so the brief wait no longer looks like a blank QR code.
### Changed
- **Report bad recognition**: The feedback prompt is now offered in more low-quality cases — when the card fills too little of the frame, when nothing looked like a real name, or when the capture had to be rotated upright — so poor scans are easier to report.
### Security
- **Feedback backend**: Hardened the feedback submission endpoint (validates the upload path belongs to the signed-in user, caps payload size and line counts) and moved feedback deletion behind a dedicated admin allow-list. Backward-compatible; no effect on existing users.

## [1.5.5] - 2026-09-15
### Added
- **Languages**: Added Japanese (ja) and Korean (ko). The app now ships in English, 繁體中文, 简体中文, 日本語, and 한국어 (5 locales).
- **Report bad recognition (opt-in)**: When a card scan is recognized poorly, you can optionally send a feedback sample — the recognized text, the result, and the card photo — to help us improve OCR accuracy. It is always opt-in and confirmed on each card; a submission credits one scan back. Submitted samples are encrypted, used only to improve recognition, and deleted within 30 days.
### Changed
- **Scan**: Card-edge detection is now remotely tunable (Firebase Remote Config), so detection can be improved without an app update.
### Fixed
- **Scan**: Rotation-stable corner ordering fixes tilted cards being warped or flipped upside-down after capture.
### Privacy
- New in-app consent screen (all languages) and an updated Privacy Policy describe exactly what the optional feedback collects, its processors, 30-day retention, and how to request deletion.
### CI/CD
- Android Gradle Plugin 8.11.1 → 8.13.0 with optimized resource shrinking (first release validated on CI).

## [1.5.1] - 2026-09-08

### Added
- **Scan**: New Android card-edge detection strategy (Otsu threshold + larger close/dilate to bridge broken edges) plus emitting each large contour's min-area rect as a candidate. Cards on busy or low-contrast backgrounds are detected far more reliably. iOS Vision detection unchanged.

### Changed
- **Handshake / QR**: Removed the speculative session pre-warm. The Share screen is mounted eagerly inside the tab stack and consumed the warm session before it was ready, which wasted an extra Cloud Function call and briefly showed a loading placeholder. The QR is now generated once when the Share screen initializes; the Cloud Functions HTTP connection is still warmed up on login.

### Fixed
- **Drawer**: Fixed infinite recursion where `_dismiss()` called itself instead of `Navigator.pop()` (introduced by a stray replace-all during the docked-drawer change). Tapping any drawer item recursed until Dart ran out of memory (SIGABRT). Verified on Pixel 9 Pro.

### CI/CD
- Pinned Flutter to 3.38.9 across Android APK/AAB pipelines and Xcode Cloud.
- Set up the Flutter toolchain before secret injection on Android.

## [1.5.0] - 2026-09-06

### Added
- **Cloud Vision OCR**: New recognition client with engine abstraction and fallback chain (own key → shared key via Cloud Function → ML Kit). BYOK stored in the secure keychain; camera preview shows engine + remaining shared quota; new "AI Recognition" settings screen (en/zh/zh_TW).
- **iPad & Foldable support**: Adaptive layout with responsive breakpoints. Large landscape screens dock the drawer open as a left column; phones/portrait keep the modal drawer. iPad app icons and four-orientation support added.
- **Scanner**: Full-bleed camera preview without distortion in portrait and landscape; guide box sized to the shorter side on tablets; landscape moves capture controls to the sides. Localized scan hints (en/zh/zh_TW).
- **Contacts**: Export the full contact (typed phones, emails, addresses, website, organization) to Google Contacts. Edit a contact's profile photo (gallery/camera + square crop), including Drive-only photos.
- **Card detection**: Shared geometric scoring model across Android (`OpenCVProcessor.kt`) and iOS (`CardScoring.swift`) using convexity, near-90° corners, parallel edges, aspect ratio, and the on-screen guide frame as a prior.

### Changed
- **Android 16 KB compliance** (Google Play, May 2026): Migrated OpenCV from the discontinued `quickbirdstudios:4.5.3.0` (4 KB-aligned) to the official `org.opencv:opencv:4.14.0` (16 KB-aligned); enabled prefab, `c++_shared` STL, and `jniLibs useLegacyPackaging=false`.
- **Orientation**: Adaptive policy — phones (shortest side < 600dp) stay portrait-only; tablets/iPads/unfolded foldables allow all orientations for Split View / Stage Manager.
- **Memory**: Capped the in-memory image cache to 200 images / 50 MB to reduce peak memory on newer Android limits and multitasking.

### Security
- **vCard export**: Escape all interpolated values (backslash, `;`, comma, newlines) so OCR'd card text can't inject forged vCard properties. Gated OCR debug logging behind `kDebugMode`.

### Tooling & Tests
- cloudbuild installs android-36 + build-tools 36.0.0.
- Fixed `auth_repository_test` MockRef stubbing; added responsive breakpoint tests; enforced tests in CI.

## [1.4.5] - 2026-03-24

### Added
- **Handshake**: Card privacy controls in the exchange flow.

### Fixed
- **Auth**: Fixed authentication persistence.
- **Splash**: Resolved infinite splash-screen hang on auth error.
- **Backup**: Robust image sync and Google Drive persistence; fixed undefined `pJson` in `BackupService`.

### CI/CD
- Switched to a Dart-based secret injector; unified Firebase config injection across Android/iOS; robust URL-safe Base64 decoding; pre-install Android SDKs in cloudbuild to prevent OOM.

## [1.3.9] - 2026-03-22

### Fixed
- **Android**: Resolved infinite loading loop on Splash Screen after notification permissions.
- **iOS**: Fixed "Invalid OAuth response" error for Apple and Google Sign-In by restoring stable authentication logic.
- **UI/UX**: Aligned **Splash Screen** branding (logo, title, slogan) with the **Login Screen** for a seamless startup experience.

## [1.3.8] - 2026-03-22
(Internal debugging release for Android login persistence)

## [1.3.7] - 2026-03-22

### Fixed
- **iOS Deep Linking**: Added `Associated Domains` entitlement to fix Universal Links opening in browser.
- **Android Login Persistence**: Added `GoogleSignIn().signInSilently()` initialization logic.
- **Deep Linking**: Implemented iOS clipboard workaround for deferred deep linking on first launch.

## [1.3.6] - 2026-03-20

### Fixed
- **CI/CD**: Synchronized GCP Secret Manager with rotated Firebase API keys to fix Android login issue.

## [1.3.5] - 2026-03-20

### Fixed
- **Firebase**: Updated stale API keys for Android and iOS after rotation. (Resolved "API key expired" login error).

## [1.3.4] - 2026-03-20

### Changed
- **Architecture**:
    - Project refactored into two repositories for open-sourcing.
    - Extracted core OCR logic into a private package `SecBizCard_OCR`.
- **CI/CD**:
    - **GCP Cloud Build**: Added automated AAB builds and Play Store Internal distribution with robust Secret Manager integration.
    - **Xcode Cloud**: Configured iOS builds with secure environment variable injection for Firebase and private dependencies.
    - **GitHub Actions**: Configured Android QA APK builds for testing.
- **Reliability**:
    - Implemented robust Base64 decoding for sensitive configuration files in CI pipelines.
    - Optimized build node resource usage (Gradle memory limits) to prevent OOM errors.
    - Automated SSH key management for private git dependencies.

## [1.2.6] - 2026-02-01

### Added
- **OCR & Recognition**:
    - Multi-lingual logic (CN, JP, KR, EN) with improved accuracy.
    - Advanced Title & Name scoring system for better field mapping.
- **Contact Management**:
    - **Search & Filter**: Integrated search bar in the main AppBar.
    - **Locale Sorting**: Alphabetical sorting that respects system language rules.
- **QR Sharing & Handshake**:
    - **Handshake v2**: Fixed "Lite" context null-cast crash and refined "Share Back" sequence.
    - **QR Refresh**: Manual refresh button enabled after 60s for improved security.
    - Added 5-minute validity status and countdown.

### Fixed
- **Code Quality**:
    - Resolved 50+ lint warnings including deprecated `withOpacity`.
    - Sanitized `UserProfile` model for better null-safety in exchange flows.
- **UI/UX**:
    - Simplified App Version display (removed build number suffix).
    - Refined Main Action Button (FAB) behaviors based on current tab.

## [1.2.0] - 2026-01-26

### Added
- **Backup & Restore**:
    - Encrypted backup to Google Drive (ZIP + AES).
    - Restore function with data integrity check.
    - Silent Google Sign-In integration for seamless Drive access.
- **Contact Management**:
    - Swipe-to-Delete functionality in Contacts List.

### Fixed
- **UI/UX**:
    - "Restore" button visibility in Dark Mode.
    - "Delete" button width adjustment (1/3 width).
    - Instant theme application after restore.
- **Bugs**:
    - Fixed restored contacts not appearing immediately (state refresh).
    - Fixed Google Drive API "not enabled" error handling (user guidance).

### Dependencies
- Added `flutter_slidable`.
- Updated `google_sign_in` usage.
