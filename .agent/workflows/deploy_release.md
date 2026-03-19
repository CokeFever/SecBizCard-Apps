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
請告訴我這次的版本號（例如 `v1.3.3`）和簡短描述。

### 4. 建立 Tag 並推送
```bash
git tag -a v<版本號> -m "<版本描述>"
git push origin v<版本號>
```

這會自動觸發：
- **Xcode Cloud** → Build iOS → 上傳 App Store Connect
- **GitHub Actions** → Build Android APK + AAB → 建立 GitHub Release

### 5. 完成後動作
- 到 [App Store Connect](https://appstoreconnect.apple.com) 提交 iOS 審核
- 到 [Google Play Console](https://play.google.com/console) 上傳 AAB（如需更新）
- 更新 `CHANGELOG.md` 記錄本次變更
