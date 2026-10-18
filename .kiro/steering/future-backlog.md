# Future Backlog — 已決定但尚未實作(cross-session)

重開 session 時,這裡記錄「已討論、owner 同意未來要做、但還沒排進版本」的項目。做了就從這裡移除
並寫進對應 handoff。

目前沒有待辦項目 —— 先前列的都已實作上線(見下方「已完成」紀錄)。下一個明顯的大動作是
**後端 App Check enforce**(見 `backend-protection.md` 的 5 步前置鐵律),但那要等 1.6.6 普及 +
強更把舊版趕上來、verified 比例上升、舊版流量歸零後,由 owner 明確指示才做 —— 不是「待辦」,是
「條件未到的未來決策」。

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
