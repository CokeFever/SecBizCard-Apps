# Web Portal + 端對端加密 規劃(未來,尚未動工)

> 狀態:**規劃 / 討論記錄**。這份不是要現在做的工作,是把一串設計討論固化下來,
> 等訂閱版上架後、要做「web 編輯器 + 加密升級」時的藍圖。**現在不動任何程式。**
> 排版檢視:在 Kiro/VS Code 開此檔按 `Cmd+Shift+V`。

---

## 動機
- 使用者(尤其 1–2 千筆聯絡人)想在**電腦網頁**上大量編輯,比手機方便。
- 想支援「秘書/助理代老闆編輯」的 B2B 場景。
- 想讓「備份加密」名副其實(目前商店文案宣稱 "we never have access",但**現況做不到**)。

---

## 現況(程式碼稽核結論)
- 備份流程:app 把 contacts + profile + settings 打包成 ZIP(`data.json` + `zip://` 圖片),
  整包 AES 加密後上傳使用者自己的 Google Drive,固定檔名 `ixo_app_backup.zip`。
  檔案佈局:`IV(16 bytes) + AES-CTR 密文`。(`lib/core/services/backup_service.dart`)
- **加密金鑰 = Firebase uid**,補/截到 32 字元直接當 AES-256 key。
  **沒有 KDF / salt / 裝置祕密 / 使用者密碼。** 演算法 AES-CTR(無完整性驗證)。
- Drive scope = `drive.file`;檔案在使用者 Drive root(非 appDataFolder)。
- uid 是 Firebase uid(不是 Google sub),同一 Firebase 專案登入同一帳號 → uid 一致。
- **安全結論**:任何拿到使用者 uid 的第一方(app、後端、web portal)都能解密 →
  "we never have access" 密碼學上不成立。放在使用者自己的 Drive 讓**外部攻擊者**門檻較高
  (要攻進該使用者的 Google 帳號 + 知道 uid),但不是零知識。
- ⚠️ app repo(SecBizCard-Apps)目前是 **PUBLIC**,加密演算法因此公開;但演算法公開不是
  真破口(反編譯 app 一樣看得到),真破口是「金鑰=uid」太弱。

---

## Web Portal 設計(討論定案的方向)

### 架構:純前端,伺服器不碰資料
```
ixo.app/editor(純前端 web app)
  - Firebase Auth 登入(同一 Firebase 專案 → uid 與手機一致)
  - 直接從 browser 呼叫 Google Drive API 讀/寫備份(伺服器不經手)
  - 解密 / 編輯 / 重新加密打包 全在 browser
  - 寫回使用者自己的 Google Drive → app 端 restore
```
好處:真零知識(伺服器沒看到明文或金鑰)、無中央資料庫外洩風險。

### 儲存模式:登入時讓使用者選(化解 memory vs IndexedDB 之爭)
- **私人裝置** → IndexedDB 草稿(可接續編輯,關分頁不怕白做,1–2 千筆較穩)
- **共用電腦** → 純記憶體(不落地,關頁即清)
- **登入時就提醒共用電腦風險**,讓使用者在資料讀進瀏覽器**前**知情選擇。
- 不論哪種:上傳完 / 登出 / 進場問「接續或清除」,都要嚴格清 IndexedDB。
- 原則:web 的威脅模型 ≠ 手機(常在共用電腦),清除責任更重、更主動。

### Firebase / OAuth 事實
- 同一個 Firebase 專案可註冊 Android / iOS / **Web** app,共用 Auth → uid 一致。✅
- 各平台的 Firebase API key 可不同但指向同一專案(API key 非祕密)。
- Google Drive 存取是獨立的 OAuth client + scope 問題。

### 需要 POC 驗證的技術點(可行性關鍵)
1. **Drive 存取**:web 用自己的 Web OAuth client + `drive.file`,能不能讀到 app(不同 client)
   建立的 `ixo_app_backup.zip`?`drive.file` 限「自己 client 建立/使用者用 Picker 選過的檔」。
   → 可能要用 **Google Drive Picker** 讓使用者手動選檔授權。**這是最需要先驗證的一點。**
2. **加密演算法對齊**:web 端(Web Crypto / crypto-js)要位元級重現 app 的
   AES-CTR + IV 佈局,產出的檔 app 要能 restore。
3. **Apple 登入者的 Drive**:登入身分是 Apple、儲存在 Google Drive → web 端要額外授權 Drive。

---

## 「秘書代老闆編輯」場景 + 授權模型

### 用 Google Drive Picker + 分享權限當「拿到檔案」的授權
- 老闆用 Drive 把備份檔分享給秘書 → 秘書在 web Picker 選到它 → **拿得到檔案**。
- 這用 Google 原生分享權限,省掉自建一套授權系統。✅
- **但**:拿到檔案 ≠ 拿到金鑰。現況金鑰 = 老闆 uid,秘書不知道 → **解不開**。這是死結。

### 演進方向(討論推導出的正解:公私鑰混合加密 / E2E)
標準做法 = **hybrid encryption**:
```
每份備份:
  1. 產生隨機資料金鑰 DEK
  2. 用 DEK 加密內容(AES,快)
  3. 用「授權對象的公鑰」加密 DEK(可包多份:老闆自己 + 秘書)
  4. 備份檔 = [公鑰加密的 DEK(們)] + [DEK 加密的內容]
解密:用自己的私鑰解出 DEK → 解內容
```
一次解決四件事:
- **本人 restore 無感**:老闆用自己私鑰解 DEK,不用記密碼、不用 token。
- **秘書代編輯**:老闆用秘書公鑰再包一份 DEK;秘書用她自己的私鑰解。老闆私鑰不出裝置。
- **真零知識**:伺服器只見公鑰(公開)+ 密文,"we never have access" 終於成立。
- **撤銷**:重新備份時不再包某人的 DEK。

（先前討論過的 "request edit token" 想法是對的直覺,但公私鑰更乾淨:授權不必傳金鑰,
用對方公鑰加密即可;token 可退化為「交換公鑰」用途,公鑰非祕密傳輸無風險。）

### E2E 的三大實務難點(做之前必須設計)
1. **私鑰生命週期**:存裝置 secure enclave;**換手機/重裝 app 私鑰就沒了 → 解不開舊備份**。
   需 recovery 機制(密碼加密的私鑰備份 / recovery key),這會重新引入「要保管一個東西」。
   → 「完全不用記任何東西」與「換裝置能救回」有根本張力,只能縮小到救援邊界。
2. **公鑰交換**(秘書↔老闆):雙方各有金鑰對;需要交換公鑰的流程(掃 QR / 貼 token /
   後端當公鑰目錄——後端存公鑰 OK,公鑰本來就公開)。
3. **向後相容遷移**(見下)。

---

## 向後相容:別讓兩個月前的備份 restore 不了(必做)
- 舊備份(uid 金鑰,無版本標記)升級後仍要能 restore。
- 解法:**新格式加 magic/version 標記**;restore 讀版本選解法:
  - 沒有新 magic → 當舊格式,用 uid 金鑰解(**舊解密邏輯永久保留**)。
  - 有新 magic → 用新(公私鑰/DEK)解法。
- backup 升級後一律寫新格式;restore 舊檔後、下次備份自動轉新格式。
- 舊 uid 解密的幾行 code 永遠留著 → 多年前的備份也救得回。

## 「零知識 vs 本人無感 vs 不用記密碼」三難(核心決策)
- 對稱(現況 uid):本人無感 + 不用記密碼,但**非零知識**(uid 能解)。
- 純 token/密碼派生:零知識,但本人每次 restore 要 token/密碼(UX 差)。
- **公私鑰混合**:本人無感 + 零知識 + 不用日常記密碼,代價集中在「換裝置/救援」。← 最佳解
- 動工 E2E 前,先把「私鑰存哪、換裝置怎麼救、要不要 recovery key」定案。

---

## 分階段路線(建議)
- **階段 0(現在,上架前)**:
  - 不做 web portal、不改加密。
  - **修文案**:別再宣稱 "we never have access"(現況不成立);改成務實描述
    (例如「加密後儲存在你自己的 Google Drive」)。低成本、避法律風險。
  - (考慮)評估 app repo 是否該轉 private(影響的不只備份,是全部程式碼)。
- **階段 1**:web portal V1 —— **本人**登入編輯自己的備份(可先用現況 uid 金鑰,不改加密)。
  先驗證產品價值 + Drive Picker POC。
- **階段 2**:E2E 加密升級(公私鑰混合)+ 秘書授權代編輯 + 向後相容遷移。大版本,認真設計。

## 待決策 / 待驗證清單
- [ ] Drive Picker + `drive.file` 能否跨 client 存取 app 建立的備份(POC)
- [ ] 私鑰生命週期與救援方案(換裝置)
- [ ] 公鑰交換流程(秘書場景)
- [ ] 向後相容:新格式 magic/version 設計
- [ ] app repo 要不要轉 private
- [ ] 上架前:修正「we never have access」文案(store copy + privacy 頁)
