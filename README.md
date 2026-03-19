# IXO: Decentralized Digital Business Card Exchange

IXO is a privacy-first ecosystem for exchanging digital business cards. It leverages decentralized principles and Google Cloud infrastructure to give users full ownership of their professional and social identity data.

## 🚀 Vision

- **Privacy First**: Detailed contact info is only shared during the "Handshake" protocol via encrypted channels.
- **Data Ownership**: Users own their data, stored locally and backed up to their own Google Account (Drive/Contacts).
- **Seamless Flow**: Bridges the physical and digital worlds using dynamic QR codes. (NFC removed for minimalism).

## 🛠 Tech Stack

- **Frontend**: Flutter (Android/iOS)
- **Backend**: Firebase & Google Cloud Platform
- **Database**: Cloud Firestore (Signaling) & Local SQLite (Source of Truth)
- **Authentication**: Firebase Auth (Google Sign-In, Apple Sign-In, Phone, Email Link)
- **Sync**: Google People API & Google Drive API

## 📱 Key Features

- **The "IXO Handshake"**: A secure protocol for peer-to-peer card exchange with context-aware privacy.
- **On-Device OCR Card Scanner**: Scan physical business cards using OpenCV and Google ML Kit (Supports EN, CN, JP, KR).
- **Contact Management**: Integrated **Search/Filter** and **Locale-aware sorting**.
- **vCard Interoperability**: Bulk import and export contacts via `.vcf` files.
- **Context Management**: Multiple personas (Business, Social, Lite) for different social environments.
- **Field-Level Verification**: Verified badges for phone numbers and professional emails.
- **Offline First**: Full functionality even without a network connection.

## 🔨 Development

### Prerequisites
- Flutter SDK
- Firebase CLI
- Google Cloud Project configured

### Setup
1. Clone the repository.
2. Run `flutter pub get`.
3. Configure your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS).
4. Run the app: `flutter run`.

## 📂 Project Structure

- `lib/`: Main Flutter application source code.
- `website/`: Nuxt 4 powered official website and deep link handlers.
- `docs/`: Project documentation (PRD, roadmap, setup guides).
- `assets/`: Global design assets (icons, images, logic).
- `store_assets/`: Official assets for App Store and Play Store submission.

## 📄 License

Distributed under the MIT License. See `LICENSE.md` for more information.

---
*Created by Google Antigravity Team*
