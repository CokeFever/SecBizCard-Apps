# AGENTS.md — SecBizCard-Apps (Flutter app) · 跨 repo 專案導覽

> 🧭 **先讀這段,避免失憶走錯方向。** 這是一個**跨兩個 git repo** 的專案。你現在在
> **`SecBizCard-Apps`(Flutter app)**。後端、官網、設計文件、所有 handoff 在**另一個 repo**
> `SecBizCard`,**那是主 project folder**(2026-10-18 起)。跨 repo ground truth 見 steering
> `.kiro/steering/repo-layout.md`。

## 這個專案有兩個 repo

| Repo | 本機路徑 | 內容 |
|------|---------|------|
| `SecBizCard-Apps`(你在這) | `/Users/jack/_Projects/SecBizCard-Apps` | Flutter app(Android/iOS)原始碼 |
| **`SecBizCard`**(主 folder) | `/Users/jack/_Projects/SecBizCard` | backend Cloud Functions、Firestore rules、官網 Nuxt(含 `/editor`、`/guide`)、private OCR package、**所有 handoff / 內部文件 / 設計文件** |

app 與 backend 的使用契約是**耦合**的:改 app 端呼叫後端 callable / OCR package 的地方時,要對照
`SecBizCard` repo 的實作。OCR 解析「大腦」是 `SecBizCard` 的 `packages/SecBizCard_OCR`,app 以 git
dependency 引用。

## 這個 repo 的可見性與鐵律
- 本 repo **為 public**(2026-10-22 經 GitHub 官方完成敏感歷史抹除後已正式切回 public)。
- 🚫 **因此任何機敏資訊(帳密、admin UID、owner email、個人設備、真實 PII)絕不可進此 repo。**
  機敏值集中放 `SecBizCard`(private)的 `docs/internal_admin_reference.md`;此 repo 的文件/steering
  只能放「見該檔」指標。新增任何文件前先確認 public-safe。

## 文件放哪
- **此 repo(app 自己的,可 public)**:`docs/` 下的開發/送審/辨識/匯入/隱私標籤文件
  (`SETUP.md`、`card_detection_scoring.md`、`ocr+import_DECISIONS.md`、`zip_*`、
  `submission_checklist.md` 等)。
- **在 `SecBizCard`(private)**:handoff、release store copy/runbook、web editor/portal 設計、
  後端架構、開發環境、admin 機敏對照。
- **兩邊同步**:`docs/oauth_verification.md`(兩份內容一致且 public-safe)。
- **最新進度**:讀 `SecBizCard/docs/` 裡日期最新的 `handoff_*.md`。

## Steering(ground truth,兩 repo 都放,backend 為權威)
`.kiro/steering/`:`repo-layout.md`、`cicd.md`(三套發版 pipeline)、`backend-protection.md`
(App Check)、`web-editor-csp.md`、`future-backlog.md`。**改 steering 以 `SecBizCard` 為準再同步過來。**

## 發版速記(細節在 cicd.md)
- Android release = **GCP Cloud Build**(`android/v*` tag,us-central1)→ Play internal。**不是**
  GitHub Actions(那只出 QA APK)。
- iOS release = **Xcode Cloud**(`ios/v*` tag)。
- Flutter 版本 pin **3.38.9**(fvm),不要用 stable。
