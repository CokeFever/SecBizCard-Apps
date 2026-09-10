# IXO: Decentralized Digital Business Card Exchange

IXO is a privacy-first ecosystem for exchanging digital business cards. It leverages decentralized principles and Google Cloud infrastructure to give users full ownership of their professional and social identity data.

> This repository is the **Flutter application** (Android / iOS). The backend
> (Cloud Functions, Firestore rules), the official website, and the private OCR
> package live in the companion repository.

## 🚀 Vision

- **Privacy First**: Detailed contact info is only shared during the "Handshake" protocol via encrypted channels.
- **Data Ownership**: Users own their data, stored locally and backed up to their own Google Account (Drive/Contacts).
- **Seamless Flow**: Bridges the physical and digital worlds using dynamic QR codes. (NFC removed for minimalism).

## 🛠 Tech Stack

- **Frontend**: Flutter (Android / iOS / iPad / foldables)
- **Backend**: Firebase & Google Cloud Platform (Cloud Functions in the companion repo)
- **Database**: Cloud Firestore (signaling) & local SQLite (source of truth)
- **Authentication**: Firebase Auth (Google Sign-In, Apple Sign-In)
- **Sync**: Google People API & Google Drive API
- **OCR**: Cloud Vision (own key / shared key via Cloud Function) with on-device Google ML Kit fallback; OpenCV for card detection & perspective correction
- **Remote tuning**: Firebase Remote Config for card-detection parameters

## 📱 Key Features

- **The "IXO Handshake"**: A secure protocol for peer-to-peer card exchange with context-aware privacy.
- **AI Card Scanner**: Cloud Vision OCR with a strict fallback chain (your own key → shared quota → on-device ML Kit). OpenCV detects the card and corrects perspective; a shared geometric scoring model picks the card consistently across platforms.
- **Contact Management**: Integrated **search / filter** and **locale-aware sorting**; export full contacts to Google Contacts.
- **vCard Interoperability**: Bulk import and export contacts via `.vcf` files.
- **Context Management**: Multiple personas (Business, Social, Lite) for different social environments.
- **Field-Level Verification**: Verified badges for phone numbers and professional emails.
- **Adaptive UI**: Optimized layouts for phones, iPad / iPad mini, and wide foldables.
- **Offline First**: Full functionality even without a network connection.

## 🌐 Localization

English, 简体中文, 繁體中文, 日本語, 한국어. (Japanese & Korean are being
finalized with native-speaker review.)

## 🔨 Development

### Prerequisites
- Flutter SDK
- Firebase CLI
- Google Cloud project configured

### Setup
1. Clone the repository.
2. Run `flutter pub get`.
3. Configure your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS).
4. Run the app: `flutter run`.

### Localization
Strings live in `lib/l10n/*.arb`. After editing, regenerate with `flutter gen-l10n`.

## 📂 Project Structure

- `lib/`: Main Flutter application source code.
- `lib/l10n/`: Localization source (`.arb`) for en / zh / zh-TW / ja / ko.
- `android/`, `ios/`: Native platform projects (incl. OpenCV card detection).
- `assets/`: App design assets (icons, images).
- `store_assets/`: App Store / Play Store submission assets.
- `docs/`: App-side documentation.
- `test/`: Unit / widget tests.

## 📄 License

Distributed under the MIT License. See `LICENSE.md` for more information.

---
*Created by Google Antigravity Team*
