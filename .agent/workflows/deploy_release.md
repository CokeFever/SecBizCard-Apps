---
description: Build and deploy a new release version (Android Bundle, Firebase, GitHub Release)
---

# 發版流程 (Deploy Release)

當你準備好發布新版本時，依照以下步驟執行。

## 前置確認

// turbo-all

### 1. 確認程式碼無錯誤
```bash
flutter analyze
```

**Action**: 如有錯誤，必須先修復。

### 2. 跑測試
```bash
flutter test
```

## 發版

### 3. 確認版本號
請告訴我這次的版本號（例如 `1.5.5`）和簡短描述。先在 `pubspec.yaml` bump
`version:`（格式 `X.Y.Z+build`，build number 必須比上一版高）。

### 4. 建立 Tag 並推送（平台各一個 tag）

> **重要 — Tag 命名慣例（platform-prefixed）：**
> 發版用「平台前綴」tag，**兩個平台各打一個**，通常指向同一個 commit：
> - `android/v<版本號>` → 觸發 **GCP Cloud Build**（trigger `android-release-build`
>   @ region `us-central1`，build config `cloudbuild.yaml`）→ `flutter build aab`
>   → fastlane 自動上傳 **Play internal testing**。
>   （注意：**不是** GitHub Actions。`.github/workflows/android_build.yml` 只會出一份 QA 用的 APK artifact，不上架。權威說明見 `.kiro/steering/cicd.md`。）
> - `ios/v<版本號>` → 觸發 **Xcode Cloud**（其觸發規則設定在 App Store Connect 的 Xcode Cloud workflow，不在本 repo；ci 腳本為 `ios/ci_scripts/ci_post_clone.sh`）→ Build iOS → App Store Connect。
>
> 舊的無前綴 `v*` tag（如 `v1.3.x`）已淘汰，**不要再用** —— 它不會觸發現在的發版流程。
> 歷史範例：`android/v1.5.1` + `ios/v1.5.1` 成對存在。

```bash
# 兩個 tag 指向目前 HEAD，分別觸發兩平台的 build
git tag -a android/v<版本號> -m "<版本描述>"
git tag -a ios/v<版本號>     -m "<版本描述>"
git push origin android/v<版本號>
git push origin ios/v<版本號>
```

建議：可先只推 `android/v*` 驗證 CI（尤其涉及 AGP/toolchain 變更時），
Android 綠燈後再推 `ios/v*`。

### 5. 完成後動作
- 到 [App Store Connect](https://appstoreconnect.apple.com) 提交 iOS 審核
- 到 [Google Play Console](https://play.google.com/console) 上傳 AAB（如需更新）
- 更新 `CHANGELOG.md` 記錄本次變更
