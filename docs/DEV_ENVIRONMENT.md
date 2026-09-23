# 開發環境與設備配置

## 開發設備

| 設備 | 地點 | OS | 主要用途 |
|------|------|-----|---------|
| Desktop PC | 家中 | Windows 11 | Android 開發、Web 開發 |
| MacBook Air M2 | 公司 | macOS | iOS 開發、全平台開發 |

## 測試設備

| 設備 | 用途 | 備註 |
|------|------|------|
| Pixel 6 Pro | Android 開發測試機 | USB debug |
| iPhone 15 | iOS 開發測試機 | Xcode debug |
| Pixel 9 Pro | 個人自用機 | ⚠️ 僅限最終測試，避免日常 debug |

## 同步方式

- **程式碼**：GitHub ([CokeFever/SecBizCard](https://github.com/CokeFever/SecBizCard), `main` branch)
- **待辦事項**：GitHub Issues + Labels
- **開發進度**：GitHub Projects (Board View)
- **CI/CD**（權威說明見 `.kiro/steering/cicd.md`；以下為摘要，勿再誤植）：
  - **Android 發版** = **GCP Cloud Build**（trigger `android-release-build` @ us-central1，`android/v*` tag，`cloudbuild.yaml`）→ 出 AAB → fastlane 自動上 Play internal testing。**不是** GitHub Actions。
  - GitHub Actions `android_build.yml` 只出 QA 用 APK artifact，**不上架**。
  - **iOS 發版** = **Xcode Cloud**（`ios/v*` tag，`ios/ci_scripts/ci_post_clone.sh`）。
  - Firebase 後端（private repo）= 手動 deploy（`workflow_dispatch`）。
  - 各 pipeline 機密位置不同：Cloud Build→GCP Secret Manager；Xcode Cloud→Xcode Cloud env；GitHub Actions→GitHub Secrets。

## 每日同步 SOP

參見 Agent Workflow: `/dev_sync`

## 跨平台注意事項

- 換行符由 `.gitattributes` 統一處理為 LF
- `pubspec.lock` 必須提交到 Git，確保兩端依賴一致
- iOS 相關開發（Xcode 設定、CocoaPods）僅在 MacBook 上操作
- Android 和 Web 開發可在任一設備進行
