# AGENTS.md — SecBizCard (backend/website) · 跨 repo 專案導覽

> 🧭 **先讀這段,避免失憶走錯方向。** 這是一個**跨兩個 git repo** 的專案。你現在在
> **`SecBizCard`(backend/website),這是主 project folder**(2026-10-18 起;舊習慣是以 app repo
> 為主,已反轉)。完整的跨 repo ground truth 見 steering `.kiro/steering/repo-layout.md`。

## 這個專案有兩個 repo

| Repo | 本機路徑 | 內容 | 可見性 |
|------|---------|------|--------|
| **`SecBizCard`**(你在這) | `/Users/jack/_Projects/SecBizCard` | backend Cloud Functions、Firestore rules、官網 Nuxt(`website/`,含 `/editor`、`/guide`)、private OCR package(`packages/SecBizCard_OCR`)、**所有 handoff/內部文件/設計文件/admin 機敏對照** | **private** |
| `SecBizCard-Apps` | `/Users/jack/_Projects/SecBizCard-Apps` | Flutter app(Android/iOS)原始碼 | **public**(2026-10-22 經 GitHub 官方完成敏感歷史抹除後已正式切回 public) |

兩個 repo 同屬 GitHub owner `CokeFever`。app 與 backend 的使用契約是**耦合**的——改後端 callable
或 OCR package 時,要同步考慮 app 端的呼叫點。

## 文件放哪(詳見 repo-layout.md)
- **只在這裡(backend, private)**:`docs/handoff_*.md`、`release_*_store_copy.md`、
  `release_*_runbook.md`、web editor/portal 設計(`web_editor_design.md` 等 3 份)、
  `firebase_functions_architecture.md`、`DEV_ENVIRONMENT.md`、
  **`docs/internal_admin_reference.md`(admin UID / owner 帳號 / demo 憑證,機敏)**。
- **兩邊同步**:`docs/oauth_verification.md`(public-safe,真實 owner email 只在 internal_admin_reference)。
- **最新進度**:讀 `docs/` 裡日期最新的 `handoff_*.md`(目前 `handoff_2026-10-29.md`)。

## Steering 與 Rules(ground truth,兩 repo 都放,backend 為權威)
- 規範存放於 `.kiro/steering/` 及 Antigravity 原生 `.agent/rules/`(`repo-layout.md`、`cicd.md`、`backend-protection.md`、`web-editor-csp.md`、`future-backlog.md`)。
- 專案技能已升級至 `.agent/skills/`(`sbc-card-ocr`、`sbc-firebase-backend`、`sbc-flutter-mobile`、`sbc-ocr-feedback`、`sbc-security-privacy`、`sbc-legal-compliance`)。
**改 steering/rules 以 backend 為準,並同步複製到 -Apps。**

## 鐵律速記(細節在 steering)
- **部署是手動的**:Firebase backend/官網 = `gh workflow run firebase_deploy.yml`(push main **不**
  自動部署,2026-09-22 起)。Android release = GCP Cloud Build(`android/v*` tag);iOS = Xcode
  Cloud(`ios/v*` tag)。
- **機敏資訊絕不進 `-Apps`**(它要轉回 public)→ 機敏值放 `docs/internal_admin_reference.md`。
- 官網動 Nuxt/build 產物 → 必做嚴格 CSP headless hydration 實測(見 web-editor-csp.md)。
