# Future Backlog — 已決定但尚未實作(cross-session)

重開 session 時,這裡記錄「已討論、owner 同意未來要做、但還沒排進版本」的項目。做了就從這裡移除
並寫進對應 handoff。

## 待辦

### 後端 App Check enforce(條件未到的未來決策,非即時待辦)
見 `backend-protection.md` 的 5 步前置鐵律。要等 1.6.6 普及 + 強更把舊版趕上來、verified 比例上升、
舊版流量歸零後,由 owner 明確指示才做。

---

## 常駐參考(不是待辦,但別忘)

### App Check 現況(monitor-only,2026-10)
- Client:1.6.4+ 起 `main.dart` 的 `FirebaseAppCheck.instance.activate()`(release =
  playIntegrity/appAttest,debug = debug provider,fail-open try/catch)。1.6.5/1.6.6 兩批**沒動**
  這段(2026-10-17 git -S 確認唯一改動是 1.6.4 的 `2124ab1`)。
- 後端:所有 service enforcement = OFF(monitor)。Firebase Console → App Check 的 verified 比例
  是**全體流量**統計:比例偏低 ≠ 新版 app 回歸,而是**舊版(無 App Check client,1.6.3/更早)還佔
  大宗 + 新版剛發未普及**。各服務比例分歧(Storage 高、Firestore 低)也佐證是流量組成問題,不是
  app 整個不送 token。要看「新版有沒有送 token」看 Console 的 **Apps** 分頁(按 app/版本),不是
  APIs 分頁的總比例。
- **2026-10-19:1.6.6+198 已雙平台上架** = enforce 5 步鐵律的步驟 1 達成;但「上架 ≠ 普及」,
  仍在步驟 2~3(monitor + 觀察 verified 比例上升、舊版流量下降)。enforce 還早。
- 翻 enforce 的 5 步鐵律見 `backend-protection.md`,**agent 不得自作主張**。

### 強更 version gate(2026-10-13 已實作,commit `1c03575`,在 main)
RC 控制:`min_supported_build`(default 180,force)+ `latest_build`(soft alert)。force 顯示不可
關閉的全螢幕更新牆,soft 顯示每次啟動一次的可關閉對話框,都用 url_launcher 開商店。fail-open、五語、
11 單元測試。= App Check enforce 鐵律「步驟 4:雙平台強更把舊版趕上來」的現成工具。要強更時在
Firebase Console 把 `min_supported_build` 設成目標 build 即可,純後台遠端控制。

### admin 工具:重置 feedback 計數
`SecBizCard/scripts/reset_feedback_count.mjs`(backend repo,**絕不可進 public SecBizCard-Apps**)。
用 email 查 uid → 重置 `ocr_feedback_submits/user_{uid}_{YYYYMM}.count` 為 0。測試超過每月 feedback
cap 時:`node scripts/reset_feedback_count.mjs --yes <email>`。⚠️ month key 用 `YYYYMM` 無分隔符
(對齊後端 `currentMonthKey()`)。
→ **owner 測試帳號 email/UID 對照見 backend private 文件 `SecBizCard/docs/internal_admin_reference.md`**
(機敏值不放 app repo,因 -Apps 計畫轉回 public)。

### feedback 月度 cap 分級(2026-10-17 已上線,1.6.6+198)
後端 `functions/src/quota.ts` 的 `feedbackCapForTier`:basic 5 / plus 10 / pro 20 / vip 無限(null
跳過)。`submitOcrFeedback` 用 `resolveTier` 判 tier。

---

## 已完成並清除的項目(2026-10 兩個 release 批次 + 強更 gate)
下列先前在此 backlog、現已實作上線,記錄一行免得重做:
- **強更 version gate(RC min_supported_build force + latest_build soft)** → commit `1c03575`,在 main。
- **OCR 姓名 vs title 修法** → OCR ref 已 bump,現 pin `dab6c0a`(1.6.6)。
- **precrop fallback(STATE3→STATE2→STATE1)** → commit `8850b76` 在 main,1.6.x 發出。
- **i18n 五語 + 欄位 i18n/涵蓋 + department 欄位 + feedback 背景上傳** → 1.6.5(+197)。
- **Android per-app 語言**(關 AAB language split + 實體 `values-b+zh+Hant` resource config +
  `keep.xml`;繁中含 zh-TW 可選、涵蓋台港澳不 fallback)→ 1.6.5(+194~196)。
- **OCR 部門雙欄守衛 + 「科」詞庫 + original scan 過曝分圖(OCR 圖/顯示圖分離 + RC previewContrast)
  + feedback 分級 cap** → 1.6.6(+198)。
- **Backup/Restore 授權 + magic word UX 合併修法(2026-10-21,workflow 完成,local-only 已 merge 進
  `-Apps` main,未 push/未發版)** → 兩 commit:`dd235c3`(子題 A:三段式最小權限 OAuth — 新增
  identity-only `loginGoogleSignIn`,login/drive/contacts 三實例隔離,登入不帶 sensitive scope、
  drive/contacts 延後 requestScopes;修好「不勾 drive.file 冒紅色錯誤」)、`f26f9e2`(子題 B:首次無
  magic word 備份軟性 nudge,文案「登入帳號綁定的基本加密」不提 uid、只提 web editor 限制、五語 ARB、
  codec/reminder 未動 → uid-mode restore 不變)。analyze/gen-l10n/build_runner/全測試綠(POC scratch
  test 的預期 fail 除外)。
  - ⚠️ **owner 待辦:on-device 手動測 9 項**(headless 無法跑真 OAuth consent)——清單見
    `-Apps/.agents/tasks/backup-auth-and-magicword-ux/plan.md` §Manual on-device OAuth verification。
    重點:登入拒 drive/contacts 要乾淨無紅錯、backup 時才跳 drive consent、無 magic word 跳 nudge
    三選項且每次都跳、"仍要備份"後同帳號能 restore、設密語後第二次不跳且能在 web editor 開。
  - 發版照常:owner 打 `android/v*+build` / `ios/v*+build` tag(見 cicd.md)。
