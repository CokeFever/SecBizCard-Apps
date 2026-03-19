# Changelog

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
