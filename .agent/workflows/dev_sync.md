---
description: 跨設備開發同步 SOP（開工拉取最新 / 收工推送變更）
---

# 跨設備開發同步 (Dev Sync)

在 Windows（家中）和 MacBook（公司）之間切換開發時，請遵循以下流程。

## 開工流程 (Start of Session)

// turbo-all

### 1. 拉取最新程式碼
```bash
git pull origin main --rebase
```

### 2. 安裝依賴（確保兩台設備一致）
```bash
flutter pub get
```

### 3. 產生必要的檔案
```bash
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
```

### 4. 確認專案狀態
```bash
flutter analyze
```

**Action**: 如有錯誤，先修復再開始開發。

## 收工流程 (End of Session)

### 1. 檢查所有變更
```bash
git status
```

### 2. 提交並推送
請告訴我 commit 訊息（或我會根據變更內容建議）。

```bash
git add -A
git commit -m "<commit message>"
git push origin main
```

### 3. 觸發 Release (如需編譯 AAB/IPA)
如果本次變更包含 Firebase 或 API 密鑰更新，請務必先手動同步秘密：
- **Android**: 更新 GCP Secret Manager (`GOOGLE_SERVICES_JSON`, `FIREBASE_OPTIONS_DART`)。
- **iOS**: 更新 Xcode Cloud Environment Variables (`GOOGLE_SERVICE_INFO_PLIST`, `FIREBASE_OPTIONS_DART`)。

推送 Tag 以觸發正式編譯：
```bash
git tag v1.3.x  # 版本號請根據 pubspec.yaml
git push origin v1.3.x
```

## 注意事項
- 如果遇到衝突，使用 `git rebase` 而非 `git merge`，保持線性歷史。
- Windows 和 macOS 的換行符差異已由 `.gitattributes` 處理。
- 確保 `pubspec.lock` 有被 commit（保證兩端依賴版本一致）。
- **Shell 指令注意**：
  - Windows PowerShell 的 Base64 指令與 Mac 不同。
  - 建議使用 `python3 -c "import base64; ..."` 方式處理 Base64 以保證跨平台一致性（如 `ci_post_clone.sh` 所示）。
- 建議在 GitHub Issues 上更新待辦事項，方便跨設備查看。
