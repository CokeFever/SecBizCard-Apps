---
description: How to build and distribute the Android App for testing (GitHub / Direct Install)
---

# Deploy for Testing (Android)

To test features like QR Code exchange that require multiple devices, you don't need to publish to the Google Play Store yet. You can build a raw **APK file** and install it directly.

## Option 1: Direct Install (If you have both phones with you)

1. Connect the **first phone** to your PC via USB.
2. Run `flutter run --release`
   - This installs a high-performance release version on the device.
3. Unplug the first phone.
4. Connect the **second phone**.
5. Run `flutter run --release` again.

## Option 2: Build APK for Distribution (GitHub / Share)

If you want to send the app to a friend or a second phone without connecting it to the PC:

### 1. Update Version (Optional)
Open `pubspec.yaml` and increment the version:
```yaml
version: 1.0.0+1  -->  1.0.0+2
```

### 2. Build Release APK
Run the following command in the terminal:
```bash
flutter build apk --release
```

### 3. Locate the File
The APK will be generated at:
`build/app/outputs/flutter-apk/app-release.apk`
(File size is usually 15-20MB)

### 4. Distribute
**Method A: GitHub Releases (Recommended)**
1. Go to your GitHub Repository -> **Releases**.
2. Click **Draft a new release**.
3. Tag: `v1.0.0-beta.1` (or similar).
4. Upload the `app-release.apk` file.
5. On the phones, open the GitHub release page and download the APK to install.
   - *Note: You may need to "Allow apps from unknown sources" in Android settings.*

**Method B: Direct Transfer**
- Send the APK via Signal, Telegram, Google Drive, or USB transfer to the phones.

---

## 💡 Troubleshooting

- **"App not installed"**: If you have a debug version (from `flutter run`) already installed, uninstall it first before installing the Release APK. Signatures might differ.
- **Safety Warning**: Android will warn about "Unknown Developer". This is normal for self-signed apps. Click "Install Anyway".
