# Web Editor 設計規格(規劃中,實作等 1.6.2 上架後)

> 狀態:**設計規格**。這是 `web_portal_and_e2e_encryption_plan.md` 階段 3「web 秘書
> editor」的細化實作規格。**實作要等 1.6.2 雙平台上架**(magic word 機制正式上線、
> 使用者實際產生 magicword 備份後,web editor 才有真實檔可對接)。規劃本身不需等。
> 排版檢視:Kiro/VS Code 開此檔按 `Cmd+Shift+V`。

---

## 1. 目標與定位
在 **PC/web 大螢幕 + 鍵盤** 上,高效率地檢視與編輯使用者自己的聯絡人備份——
補足手機 app 做不來的**批次操作**。核心場景:老闆把 Drive 的 `SecBizCard/` 資料夾
分享給秘書,秘書在網頁上整理聯絡人,重新打包回同一個備份檔,老闆在 app restore。

全程 **純前端、伺服器不碰資料**(真零知識):解包/編輯/重打包/加密都在瀏覽器內完成。

---

## 2. 技術棧(定案)
- **併入現有官網**:`SecBizCard` repo 的 `website/`(Nuxt 4 + Tailwind),新增 **`/editor`
  路由**(`app/pages/editor.vue` + `app/components/editor/*`)。共用官網部署(Firebase
  Hosting)、樣式、favicon。
- **多語支援(必做)**:對齊 app 的 5 語 **en / zh-TW / zh-CN / ja / ko**。官網目前
  **尚未裝 i18n 模組**(landing 用手動 navigator.languages fallback)。editor 的多語建議
  裝 `@nuxtjs/i18n`(較完整,editor 字串多),或沿用手動機制——**待定(見 §9)**。
- **關鍵前端套件**:Google Picker/Drive(直接用 Google API JS)、`JSZip`(解/打包 zip)、
  Web Crypto(PBKDF2 + AES-GCM,瀏覽器原生,不需外部 crypto lib)。

---

## 3. 介面架構:Master–Detail
```
┌─────────────────────────────────────────────────────────┐
│ Top bar: logo · 檔名/狀態 · [儲存並更新備份] · 語言切換       │
├───────────────┬─────────────────────────────────────────┤
│ LEFT: 聯絡人列表 │ RIGHT: 詳情 + 編輯器                       │
│  - 搜尋框        │  - 選取單筆 → 顯示/編輯所有欄位            │
│  - 全選 checkbox │  - 對齊 app 的 UserProfile 欄位 + 自訂欄位 │
│  - 每列 checkbox │  - 名片圖片(若 zip 內有)                 │
│  - 批次工具列    │  - 多選時 → 顯示批次動作(刪除 / 合併)      │
│    (刪除/合併)   │                                         │
└───────────────┴─────────────────────────────────────────┘
```
- 左列表 = master(可多選),右側 = 單筆 detail+editor,或多選時的批次面板。
- 比 CamCard 的純表格式更適合「邊看邊改」。

---

## 4. 流程(全前端)
1. **進入 `/editor`** → 立刻引導登入 Google + 開 **Google Drive File Picker**。
2. 使用者選檔(自己的或老闆分享的 `SecBizCard/ixo_app_backup.zip`)。
3. **輸入 magic word**(若該檔是 magicword 模式);uid 模式舊檔則不需要。
   - 依檔案 header `encMode` 決定(鐵律:magicword 檔只用 magic word 解,錯了乾淨失敗)。
4. **瀏覽器內解密 + 解 zip** → 載入 `data.json` + 圖片 → 渲染 master-detail。
5. 使用者**編輯 / 批次刪除 / 合併**。
6. **儲存** → 重新組 `data.json` + 圖片 → `JSZip` 打包 → Web Crypto 用**同一把 key**
   (同 magic word 或 uid)重新加密成 SBCB v2 → **Drive API update 覆蓋同一個 fileId**
   (保留資料夾分享關係,不刪不重建)。
7. 老闆在 app **restore**(偵測雲端較新 → 還原)。

---

## 5. 批次 / 鍵盤操作(web 專屬效率,核心賣點)
- **全選**:表頭 checkbox 一鍵全選 / 取消。
- **逐列 checkbox** 勾選。
- **批次刪除**:勾選多筆一次刪。
- **批次合併(merge)**:見 §6。
- **鍵盤**:Delete 刪除選取、方向鍵上下移動選取列、Shift+click 範圍選、
  Cmd/Ctrl+click 多選、Cmd/Ctrl+A 全選、`/` 聚焦搜尋。
- 刪除要有 undo 或確認(批次刪除前顯示筆數確認),避免誤刪整批。

---

## 6. 合併(Merge)規則(定案方向)
兩種進入方式:**手動勾選** 與 **自動盤點建議**(見 6A/6B)。

**(a) 可合併性門檻(先判斷才允許 merge):**
- 兩筆之間**至少一個欄位 ≥90% 相似**才允許進入合併(例如相同 email、或 name 高度相似)。
- 低於門檻 → 提示「這些聯絡人看起來不是同一人,確定要合併?」或擋下,避免亂合不相干的筆。
- 相似度:email 完全相同視為強訊號;name/phone 用字串相似度(如 Levenshtein 比例)。

**(b) 衝突解決:**
- **非衝突欄位**(一邊有值、一邊空)→ 自動補值。
- **多值欄位**(電話 / email / 自訂)→ 去重後**全部保留**。
- **衝突欄位**(兩邊都有值且不同,如兩個不同 name/company)→ 讓使用者選
  **保留 A / 保留 B / 兩者都留**(都留則存成多值或附註)。
- **原則:盡量保留不重複資料**,寧可多值全留,不默默蓋掉。

**(c) merge 預覽**:合併前顯示「合併後長這樣」的預覽 + 逐欄衝突選擇,確認才套用。

### 6A. 手動合併
使用者在列表勾選 ≥2 筆 → 按「合併」→ 走 (a)(b)(c)。

### 6B. 自動盤點建議合併(scan-through,新增)
系統掃描**全部聯絡人**,找出疑似重複的成對/成群,列成「建議合併」清單讓使用者逐組處理。
- **相似度分級**:
  - **高信心**(自動建議):email 完全相同;或 name+company 同時高相似;或 phone/mobile
    正規化後相同。
  - **中信心**(標記待確認):單一欄位高相似但其他不符。
- **效能(重要,全前端 + 可能上千筆)**:兩兩比較是 O(N²),1000 筆 = 50 萬次。必須用
  **blocking / bucketing**——先按 email domain、正規化電話、name 首字等分桶,只在同桶內
  兩兩比,把比較數降一兩個數量級。重活丟 **Web Worker** 跑,不卡 UI,附進度條。
- **UX**:「建議合併」面板,每組顯示相似度、差異欄位預覽,使用者對每組選
  **合併 / 忽略**;合併時沿用 (c) 的衝突解決。可「略過全部」或逐一處理。
- 這是秘書整理大量聯絡人的關鍵效率功能(手動在上千筆裡找重複不可行)。

---

## 7. 欄位(對齊 app 的 UserProfile)
editor 的欄位必須與 app 的 `UserProfile` + `customFields` 一致,restore 回去才不掉資料:
- name / 暱稱、title、company、department
- **phone / mobile**(分開,對齊 app 1.6.2 修正)、fax
- email、website、address(city/postalCode 等)
- taxId、note、customFields(動態鍵值,如 fax 等)
- 名片圖片(zip 內的 `zip://` 圖片)
> 實作前對 `data.json` 的實際 schema 做一次欄位盤點(以 app 的 UserProfile.toJson 為準)。

---

## 8. 檔案格式合約(與 app 一致,見 web_portal plan)
- **SBCB v2**:`[SBCB][uint16 headerLen][JSON header][12B GCM IV][ciphertext+16B tag]`。
- header:`{version:2, encMode:"uid"|"magicword", kdf:{algo:PBKDF2-HMAC-SHA256,
  iterations:100000, salt:base64(16B)}}`。
- KDF=PBKDF2-HMAC-SHA256 100k → 32B AES-256 key;cipher=AES-256-GCM。
- 舊格式(v1,無 SBCB)= uid + AES-CTR,只讀相容。
- zip 內容 = `data.json` + `zip://` 圖片(重打包要維持同格式)。
- **Web Crypto 必須位元級重現**(PBKDF2 當初已用 Python hashlib 對過一致,Web Crypto
  走同標準可對齊)。

---

## 9. 待驗證 POC(實作前先確認,排序 = 風險)
1. **Drive Picker + `drive.file` 跨 client 存取**(最高風險):秘書的 web OAuth client 能否
   透過 Picker 選到老闆 app(不同 client)建立/分享的 `SecBizCard/` 檔並讀寫。這決定整個
   秘書情境成不成立。先驗。
2. **Web Crypto ↔ app 位元級互通**:app 寫的 SBCB v2 檔 web 解得開;web 寫回的檔 app
   restore 得回。寫個最小 round-trip POC。
3. **Apple 登入者的 Drive 授權**:登入身分是 Apple、備份在 Google Drive → web 端要額外
   授權 Google Drive（身分與雲端儲存分離）。
4. **i18n 機制選型**:`@nuxtjs/i18n` vs 沿用官網手動機制。

---

## 10. 共用電腦的資料清除(web 威脅模型,必做)
web 常在共用電腦,清除責任比 app 重:
- 進入時讓使用者選「私人裝置 / 共用電腦」。
- 私人:可用 IndexedDB 暫存草稿(接續編輯);共用:純記憶體,關頁即清。
- 上傳完 / 登出 / 關閉 → 嚴格清除解密後的明文與金鑰(記憶體 + 任何 IndexedDB 草稿)。
- magic word 不落地(web 端輸入後只存記憶體,不寫 storage)。

---

## 10A. 官網全站 i18n(階段 0 前置,可先做,不等 1.6.2 上架)
editor 要併進官網且要多語,所以先讓**整個 ixo.app 官網**有一套正式 i18n,editor 直接沿用。
- **現況**:官網(`SecBizCard/website/`,Nuxt 4)**沒有正式 i18n 模組**;landing 用手動
  navigator.languages fallback,其他頁(about/privacy/eula/guide/manual/demo)多為寫死。
- **做法**:裝 **`@nuxtjs/i18n`**;把各頁文字抽成 translation keys;5 語 en/zh-TW/zh-CN/ja/ko。
- **語言選擇**:
  - **自動偵測**(navigator.languages,保留現有行為)當預設。
  - **footer 地球(🌐)圖示 → 語言選單**,可**手動切換**,覆蓋自動偵測。
  - 手動選擇**持久化**(localStorage),之後造訪沿用。
- 整合現有手動 landing i18n(避免兩套並存打架;以 @nuxtjs/i18n 為準,移除舊手動邏輯)。
- **此項獨立於 app 送審與 1.6.2 上架**,風險低,是 web editor 的鋪路。

## 11. 分階段實作
- **階段 0:官網全站 i18n + footer 地球選單**(§10A)—— **可現在做,不等 1.6.2 上架**。
  web editor 的多語基礎。
- **階段 A:POC** —— §9 的 1+2(Drive Picker 跨 client + crypto 互通)。這兩個通了才值得做
  後續。**POC 不需正式上架**(只要一個 SBCB v2 測試檔),可與階段 0 並行。
- **階段 B:唯讀檢視**(等 1.6.2 上架)—— Picker + magic word 解包 → master-detail 唯讀
  渲染。先驗證「秘書打得開老闆的備份」。
- **階段 C:編輯 + 批次 + 合併** —— 單筆編輯、批次刪除/全選/鍵盤、手動合併(6A)、
  自動盤點建議合併(6B)→ 重打包更新 Drive。
- **階段 D:共用電腦清除 + 打磨**(多語在階段 0 已就緒)。

---

## 12. 風險摘要
- Drive Picker 跨 client 讀寫(§9.1)—— 若不成立,秘書情境要改設計(例如老闆端產生分享連結)。
- crypto 位元級對齊——錯一個 byte 檔就解不開 / app restore 失敗。POC 必過。
- 共用電腦資料殘留——清除做不乾淨會洩漏明文聯絡人。
- merge 誤合——90% 門檻 + 預覽 + 盡量保留,降低誤合與資料遺失。
