# Web Portal + 備份加密升級 規劃(未來,尚未動工)

> 狀態:**規劃 / 討論記錄**。這份不是要現在做的工作,是把一串設計討論固化下來,
> 等要做「web 編輯器 + 備份加密升級」時的藍圖。**現在不動任何程式。**
> 排版檢視:在 Kiro/VS Code 開此檔按 `Cmd+Shift+V`。
>
> **2026-09-28 更新**:加密升級的方向從「公私鑰混合 E2E」改為更務實的
> **magic word(使用者自訂密語)**方案 —— 見下方「備份加密升級:magic word 方案」。
> 原公私鑰 E2E 設計保留在文末「附錄:公私鑰 E2E(更遠期備選)」,非當前計畫。

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

## 威脅模型(本方案的前提,很重要)
magic word 不是「對抗能拿到檔案的攻擊者的唯一防線」。**要拿到這個備份檔,本來就得先有
使用者的 Google Drive 登入權限(或老闆主動分享資料夾)。** 所以 access 已被 Google 帳號
保護;magic word 只是「打包/解包」那一層額外保護。因此:
- magic word **強度不需到對抗離線暴力破解等級**;重點是「拿到檔也還要有密語」。
- 可記性 > 複雜度(因為選了「乙模式」:忘記=該檔無法還原,見下)。

---

## 備份加密升級:magic word 方案(當前定案方向)

### 一句話
把「加密金鑰的來源」從 uid 換成**使用者自訂的 magic word**。預設仍是 uid(現狀,相容),
使用者可改成只有自己知道的密語;改了之後,連官方都解不開 → "we never have access" 才成立。

### 甲乙鐵律(整個隱私模型的關鍵,不可違反)
備份檔 **header 自描述自己的加密模式**,解密**依 header 決定,不盲試**:
- `encMode = "uid"`(舊檔 / 未設 magic word)→ 用 uid 解。**相容性用途。**
- `encMode = "magicword"` → **只能**用 magic word 解;**輸錯就是失敗,絕不退回 uid。**

> ⚠️ 鐵律:**magicword 檔不退 uid。** 若做成「magic word 解不開就自動退 uid」,等於官方
> (能取得 uid)還是能解開 magicword 檔 → 隱私承諾破功。uid 只用在「header 標記自己就是
> uid 模式」的舊檔。這條是「乙模式=最強隱私」能成立的根本。

### 備份檔 header(自描述,讓 app 新舊版 + web 都能正確解)
```
version:  加密格式版本
encMode:  "uid" | "magicword"
kdf:      { algo, salt, iterations, ... }   // 僅 magicword 模式
```
- salt 存 header(salt 非祕密),每份備份一個。
- magicword 模式的 key = **KDF(magic word, salt)**,用加 salt 的 KDF(PBKDF2/scrypt/argon2id),
  **不是裸 hash**(成本極低,避免弱密語+檔案萬一外流的最壞情況)。
- app 與 web 端必須用**完全相同**的 KDF 參數與 AES 佈局,才能互解。

### magic word 規則(定案)
- **長度 8–16。**
- **不強制**大小寫/數字組合(避免逼出好猜又難記的密語;NIST 亦反對強制組合)。
- **符號允許但不強制**;**允許空格**(讓 passphrase 可行,如 `my first car was blue`)。
- **大小寫敏感**(要在 UI 明講)。
- 輸入框**關閉自動修正 / 自動大寫**(手機易把開頭自動大寫 → 和秘書打的對不上)。
- **正規化**:trim 前後空白 + Unicode NFC(避免「看起來一樣、位元組不同」解不開)。
- UI 引導往「用一句只有你記得住的話」帶,而非「請用 8 位含大小寫數字」。

### 儲存 / 生命週期(比照 BYOK,登出清除)
- magic word 存 `flutter_secure_storage`(iOS Keychain / Android Keystore),**比照 BYOK key**。
  (BYOK key 現況:key 名 `ocr_cloud_vision_api_key`,`KeychainAccessibility.first_unlock`。)
- 存了之後,backup/restore **自動使用,不再每次詢問**;只有「本機沒有這個值」時才需輸入。
- **登出:magic word 與 BYOK key 都清除**(連同聯絡人 DB)。不留前一帳號痕跡,也避免同台
  裝置換帳號時 B 繼承 A 的 key/密語。
  - ⚠️ 這會**順便修正現有缺口**:目前 `signOut` 只清聯絡人 DB(`DatabaseHelper.deleteAllData()`),
    **BYOK key 留在 secure storage**(等於「清一半」)。本方案一併補清。
- app 更新保留;**刪 app / 換裝置 / 登出** 後消失 → 需重新輸入自己的 magic word。
- 設定頁可**顯示 + 複製** magic word(方便老闆用 IM 傳給秘書)——因為它本就存在本機。

### 設定 / 變更 magic word 的流程
1. 使用者在「備份與還原」頁設定/變更 magic word(輸兩次確認)。
2. **完成後立即執行一次 backup**,把雲端備份檔重新打包成新的 magicword 模式
   (驗證舊的能解 → 用新 key 重新加密 → 寫回)。否則雲端還是舊 key 打包,會變成
   「檔在、但新 magic word 解不開」的窘境。
3. 一旦從 uid 模式切到 magicword 模式,那份檔就「升級」成 magicword;之後 uid 不再能解它。

### ⚠️ 組合風險(乙模式,UI 必須分層警示)
最糟情境:**使用者設了 magic word 但沒記住 → 登出(清本機 magic word + 清聯絡人)→
裝置沒資料、雲端是 magicword 檔、magic word 也沒了 → 永久打不開。** 因此:
- **設定 magic word 當下**:強警告「只有你知道、忘記將永久無法還原、官方也無法協助」。
- **登出流程**:警語**分層**提醒(可與現有「未備份變更」警語合併):
  1. 本機聯絡人會被清除(現有行為)。
  2. BYOK key 會被清除 → 下次要重新輸入才能用自己的 Cloud Vision。
  3. **magic word 會被清除 → 還原 magicword 備份需重新輸入,請確認你記得。**
  偵測到「本機存著 magic word / 雲端是 magicword 檔」時,登出警語要更強。

---

## Google Drive 固定路徑 + 遷移(先做,獨立且低風險)

### 目標路徑
從 Drive root 的 `ixo_app_backup.zip` 改到固定資料夾:
```
My Drive / SecBizCard / ixo_app_backup.zip
```

### 為什麼用資料夾(關鍵理由:分享資料夾 ≠ 分享檔案)
- 老闆把整個 **`SecBizCard/` 資料夾**分享給秘書(Drive 原生資料夾分享)。
- 分享權限掛在**資料夾**上,**不是掛在會被重建的檔案上**。
- 所以 app 之後即使「刪舊檔、寫新檔」(備份常見做法),只要新檔仍建在這個資料夾內,
  **秘書的存取就不受影響**。若分享的是單一檔案,一旦 app 刪檔重建 → fileId 變 → 分享失效。
- 推論:`SecBizCard/` 的 **folderId 要穩定**(建一次、記住、別亂刪重建);備份**盡量「更新同檔」
  而非刪重建**,以保資料夾分享關係。

### scope 不用動(走 `drive.file`)
- `drive.file` 只能存取「app 自己建立的檔案」。因此:**app 自己用 Drive API 建 `SecBizCard`
  資料夾**(parent=root),拿 folderId,之後備份指定 `parents:[folderId]`。資料夾是 app 建的,
  `drive.file` 權限足夠。
- **不要**為了放進使用者任意既有資料夾而升級到廣域 `drive` scope —— 會觸發 Google 敏感權限
  審查(年度安全評估 / 可能 CASA 稽核),成本極高,不划算。

### 遷移與查找順序(restore 時)
1. 先找 `SecBizCard/ixo_app_backup.zip`(新家)。
2. 找不到 → fallback 去 root 找舊的 `ixo_app_backup.zip`。
3. **root 有、新家沒有**(舊使用者首次升級):讀 root 舊檔 → 下次 backup 寫到 `SecBizCard/`。
   **成功寫入新家且確認可讀後,才刪 root 舊檔**(順序不可反)。
- 「雲端比本機新」提示**保留並正常運作**(這正是 web 編輯的核心場景:秘書在 web 改完重新
  打包 → 老闆 restore)。遷移後比對基準統一用 `SecBizCard/` 那份的 modifiedTime,勿拿新家
  時間比 root 內容而誤判。

### 註記:登出不清 secure storage 的落差已修正
本方案把 BYOK + magic word 都納入登出清除,所以「登出清乾淨」更名副其實。
(先前現況:secure storage 的值登出不清,屬刻意的體驗取捨;本方案改為清除。)

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

### 秘書代編輯流程(magic word 版)
1. 老闆分享 `SecBizCard/` **資料夾**給秘書。
2. 秘書在 web 用 **Google Drive Picker** 選該資料夾內的 `ixo_app_backup.zip`(拿到檔案)。
3. 秘書輸入老闆給的 **magic word**(老闆從 app 設定頁複製、用 IM 傳)。
4. web 端依 header 解包(magicword 檔只用 magic word 解,不退 uid)→ 編輯 → 用同 magic word
   重新打包 → **寫回同一個 `SecBizCard/` 資料夾**。
5. 老闆在 app restore(偵測雲端較新 → 提示 → 還原)。
- 「給秘書 magic word = 給對方解開你所有 magicword 備份的能力」—— UI 要說明。

### 儲存模式:登入時讓使用者選(私人裝置 vs 共用電腦)
- **私人裝置** → IndexedDB 草稿(可接續編輯,關分頁不怕白做,1–2 千筆較穩)
- **共用電腦** → 純記憶體(不落地,關頁即清)
- **登入時就提醒共用電腦風險**,讓使用者在資料讀進瀏覽器**前**知情選擇。
- 不論哪種:上傳完 / 登出 / 進場問「接續或清除」,都要嚴格清 IndexedDB。
- web 的威脅模型 ≠ 手機(常在共用電腦),清除責任更重、更主動。

### 需要 POC 驗證的技術點(可行性關鍵)
1. **Drive 存取**:web 用自己的 Web OAuth client + `drive.file`,配合 **Drive Picker** 讓秘書
   手動選檔授權,能否讀到老闆 app(不同 client)建立/分享的檔。**最需要先驗證的一點。**
2. **加密演算法對齊**:web 端(Web Crypto)要位元級重現 app 的 KDF + AES + header 佈局,
   產出的檔 app 要能 restore,反之亦然。
3. **Apple 登入者的 Drive**:登入身分是 Apple、儲存在 Google Drive → web 端要額外授權 Drive。

### Firebase / OAuth 事實
- 同一個 Firebase 專案可註冊 Android / iOS / **Web** app,共用 Auth → uid 一致。✅
- 各平台的 Firebase API key 可不同但指向同一專案(API key 非祕密)。
- Google Drive 存取是獨立的 OAuth client + scope 問題。

---

## 向後相容:別讓舊備份 restore 不了(必做)
- 舊備份(uid 金鑰,無 header)升級後仍要能 restore。
- 解法:**新格式加 header(version + encMode)**;restore 讀 header 選解法:
  - 沒有 header / `encMode=uid` → 舊格式,用 uid 金鑰解(**舊解密邏輯永久保留**)。
  - `encMode=magicword` → 用 magic word 解(不退 uid)。
- backup 升級後一律寫新格式;restore 舊 uid 檔後、下次備份自動轉新格式
  (若使用者此時已設 magic word,就轉成 magicword;否則維持 uid header)。
- 舊 uid 解密的幾行 code 永遠留著 → 多年前的備份也救得回。

---

## 分階段路線(建議)
- **階段 0(上架前,大致已處理)**:
  - 不做 web portal、不改加密。
  - **修文案**:別再宣稱 "we never have access"(現況不成立);改成務實描述
    (例如「加密後儲存在你自己的 Google Drive」)。低成本、避法律風險。**(仍待辦)**
  - (考慮)評估 app repo 是否該轉 private(影響的不只備份,是全部程式碼;目前刻意 public)。
- **階段 1:Drive 固定路徑 + 遷移**(低風險、獨立、是秘書情境的基石)。
  - 建 `SecBizCard/` 資料夾、folderId 穩定、備份盡量更新同檔、restore 新家優先 + root fallback
    + 遷移後刪 root。
- **階段 2:magic word 加密**(app 端)。
  - header 自描述、KDF、甲乙鐵律、規則 8–16、存 secure storage(登出清)、設定後立即 backup、
    組合風險分層警語。
- **階段 3:web 秘書 editor**。
  - Drive Picker 選分享資料夾內的檔 + magic word 解/編/重包寫回;雲端較新提示;共用電腦清除。
  - 依賴階段 1 的路徑/分享模型 與 階段 2 的 header/KDF 定案。

## 待決策 / 待驗證清單
- [ ] 階段 0:修正「we never have access」文案(store copy + privacy 頁)
- [ ] Drive Picker + `drive.file` 能否跨 client 存取 app 建立/分享的備份(POC)
- [ ] `SecBizCard/` folderId 穩定策略(存本地 or query 尋找;被手動刪/搬時自癒)
- [ ] 遷移:root → 新家 的實作與「確認可讀才刪 root」保護
- [ ] KDF 選型與參數(PBKDF2/scrypt/argon2id)+ app/web 位元級對齊
- [ ] header 格式版本化(version/encMode/kdf/salt)
- [ ] 登出清除擴及 secure storage(BYOK key + magic word)+ 分層警語
- [ ] web:共用電腦 vs 私人裝置 的草稿清除策略

---

## 附錄:公私鑰 E2E(更遠期備選,非當前計畫)

> 這是 2026-09-28 之前討論的方向,被 magic word 方案取代(更務實:不需金鑰目錄、不需
> 公鑰交換、不需私鑰救援機制)。保留備查 —— 若未來要做「不需任何共享密語、且可細緻撤銷
> 個別授權對象」的真 E2E,可回來看這段。

標準做法 = **hybrid encryption**:
```
每份備份:
  1. 產生隨機資料金鑰 DEK
  2. 用 DEK 加密內容(AES,快)
  3. 用「授權對象的公鑰」加密 DEK(可包多份:老闆自己 + 秘書)
  4. 備份檔 = [公鑰加密的 DEK(們)] + [DEK 加密的內容]
解密:用自己的私鑰解出 DEK → 解內容
```
一次解決:本人 restore 無感、秘書代編輯(用對方公鑰再包一份 DEK)、真零知識、可撤銷
(重新備份時不再包某人的 DEK)。

**三大實務難點(當初卡住、也是改用 magic word 的原因)**:
1. **私鑰生命週期**:換手機/重裝 app 私鑰就沒了 → 解不開舊備份;需 recovery(密碼加密的
   私鑰備份 / recovery key),又回到「要保管一個東西」。
2. **公鑰交換**(秘書↔老闆):需交換公鑰流程(掃 QR / 貼 token / 後端當公鑰目錄)。
3. **向後相容遷移**。

相較之下 magic word 方案:用一個「使用者記得住、可複製傳給秘書」的密語,換掉整套金鑰對 +
目錄 + 救援機制,複雜度大幅下降,對本專案規模更合適。
