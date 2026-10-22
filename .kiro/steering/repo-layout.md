# Repo Layout & Cross-Repo Ground Truth (cross-session)

CRITICAL 持久事實。重開 session 失憶時,關於「兩個 repo 誰是主、什麼文件放哪、steering 怎麼同步」
一律以本檔為準。2026-10-18 建立(repo 整併 + -Apps 轉 private 那次)。

## 兩個 repo 與主從(⚠️ 2026-10-18 起與舊習慣相反)

| Repo | 本機路徑 | 角色 | 可見性 |
|------|---------|------|--------|
| **`SecBizCard`**(backend/website) | `/Users/jack/_Projects/SecBizCard` | **主 project folder**(新)。backend functions、官網 Nuxt(`website/`,含 /editor /guide)、**所有 handoff/內部文件/設計文件/admin 機敏對照** | **private** |
| `SecBizCard-Apps`(Flutter app) | `/Users/jack/_Projects/SecBizCard-Apps` | app 端原始碼。**public**(2026-10-22 經 GitHub 官方完成敏感歷史抹除後已正式切回 public) | public |

- **以後開 project folder 以 `SecBizCard`(backend)為主**(舊習慣是以 -Apps 為主,已反轉)。
- `-Apps` 會轉回 public → **任何機敏資訊(帳密、admin UID、owner email、個人設備、真實 PII)
  絕不可進 -Apps**。機敏值集中放 backend private 的 `docs/internal_admin_reference.md`,
  -Apps 的文件/steering 只留「見該檔」指標。

## Steering 同步規矩(「兩邊都放,backend 為主」)
- `.kiro/steering/*.md` **兩個 repo 都放一份**(app 開發 session 從 -Apps 開也要有 ground truth)。
- **權威來源 = backend(`SecBizCard`)**。改 steering 時以 backend 為準,**同步複製到 -Apps**。
- -Apps 的 steering 內容必須 public-safe(轉回 public 會外洩)→ 不得含機敏值,只能放指標。

## 什麼文件放哪
- **只在 backend(private)**:所有 `docs/handoff_*.md`、`release_*_store_copy.md`、
  `release_*_runbook.md`、web editor/portal 設計(`web_editor_design.md`、`web_editor_ux_backlog.md`、
  `web_portal_and_e2e_encryption_plan.md`)、後端架構(`firebase_functions_architecture.md`)、
  開發環境(`DEV_ENVIRONMENT.md`,含個人設備)、`internal_admin_reference.md`(帳密/UID/email)。
- **兩邊同步**:`oauth_verification.md`(app contacts scope + web editor drive.file 都需要;兩份內容
  一致且 public-safe,真實 owner email 只在 internal_admin_reference.md)。
- **只在 -Apps(可 public)**:app 自己的開發/送審文件(`SETUP.md`、`card_detection_scoring.md`、
  `deep_linking_DECISIONS.md`、`ocr+import_DECISIONS.md`、`importing_from_other_card_apps.md`、
  `zip_*`、`privacy_labels_guide.md`、`submission_checklist.md`、`subscription_store_metadata.md`、
  `ocr_feedback_store_privacy_labels.md`、`agp9_migration_readiness.md`)。

## -Apps 轉回 public 前的未竟事項(2026-10-18)
1. ✅ **git 歷史重寫(已完成 2026-10-18)**:用 `git filter-repo` 兩輪清除所有歷史中的機敏文件
   (handoff/release/web_editor/portal/DEV_ENV/firebase_func docs、`.agents/` task 產物、
   失效的 `dev_sync.md`)+ 替換機敏字串(demo 密碼/admin UID/owner email/真實電話 → `***REMOVED-*`)。
   force-push 全部 branches + 107 tags(**全是 forced update,非 create → 未觸發 pipeline**)。
   force-push 前已先停用 Cloud Build trigger + Xcode Cloud workflow。mirror 備份留在
   `SecBizCard/.backups/`。normal clone 全史掃描確認乾淨(僅存 `REVENUECAT_WEBHOOK_AUTH` 這個
   **secret 名稱**,非值,刻意保留供 cicd/hook 文件參照)。GitHub 端舊 dangling object 會自動 GC;
   repo 已 private + 無 fork,外部不可達。
2. **demo / 審查帳號密碼**:這是給 App Store / Play / Google 審查員用的帳號,本質上**本來就會被
   審查員看到、不是秘密,不需要 rotate**。唯一要求:**不可出現在 public repo**。實際帳密放 backend
   private `internal_admin_reference.md` 與 `release_*_store_copy.md`(都在 private repo),-Apps
   不得出現。
3. ⚠️ **重新啟用 pipeline + 重驗**:force-push 前停用的 **Cloud Build trigger + Xcode Cloud workflow
   必須重新啟用**;public↔private 切換後,下次發版(owner 將從 `SecBizCard` 出發)確認兩者還能被
   tag 觸發。
