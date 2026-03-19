# Development Setup Guide

This project is built with **Flutter** (Frontend) and **Firebase** (Backend). Follow these steps to set up your development environment.

## 1. Prerequisites

- **Flutter SDK**: Install the latest stable version.
  - [Download Flutter](https://docs.flutter.dev/get-started/install)
  - Verify with `flutter doctor`
- **Java JDK 17**: Required for Android builds.
  - [Download Zulu JDK 17](https://www.azul.com/downloads/?version=java-17)
- **Git**: Version control.
- **IDE**: VS Code (Recommended) or Android Studio.
  - Install "Flutter" and "Dart" extensions.

## 2. Project Setup

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd SecBizCard
   ```

2. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Verify Environment**:
   ```bash
   flutter doctor
   ```

## 3. Running the App

- **Android**: Connect a device or start an emulator.
  ```bash
  flutter run
  ```

## 4. Building for Distribution

To generate an APK for testing (signed with debug key):
```bash
flutter build apk --release
```
Artifact location: `build/app/outputs/flutter-apk/app-release.apk`

## 5. Backend (Firebase)

If you need to modify Cloud Functions or Firestore rules:

1. Install Firebase CLI:
   ```bash
   npm install -g firebase-tools
   ```
2. Login:
   ```bash
   firebase login
   ```
3. Deploy functions:
   ```bash
   firebase deploy --only functions
   ```

## 6. Architecture Note

- **State Management**: Riverpod
- **Routing**: GoRouter
- **Database**: Cloud Firestore + Local Storage (Isar/SQLite logic)
- **CI/CD**: GitHub Actions (configured in `.github/workflows/android_build.yml`)
