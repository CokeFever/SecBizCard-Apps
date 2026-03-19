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

## 注意事項
- 如果遇到衝突，使用 `git rebase` 而非 `git merge`，保持線性歷史。
- Windows 和 macOS 的換行符差異已由 `.gitattributes` 處理。
- 確保 `pubspec.lock` 有被 commit（保證兩端依賴版本一致）。
- 建議在 GitHub Issues 上更新待辦事項，方便跨設備查看。
