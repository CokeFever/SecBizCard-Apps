# 隱私標籤填寫指南 — App Store App Privacy + Play Data Safety

這份是「照著填」的指南。說明用中文,但**實際要勾／貼進 dashboard 的欄位值保留英文**
(Apple / Google 的介面是英文選項,對照才準,翻譯後貼進去會對不上)。

內容依實際程式碼稽核而來(auth、profile、OCR、handshake、subscription、儲存)。
**兩個平台的隱私標籤 + 隱私政策內文要一致** —— 審核會交叉比對。

> 檢視這份文件的排版:在 Kiro/VS Code 開此檔後按 `Cmd+Shift+V` 開渲染預覽。

## 這次訂閱版最主要的變動
- **新增「Purchases(購買記錄)」** —— RevenueCat 會拿到 Firebase uid(app_user_id)
  + 商店購買憑證來管理訂閱權限。這是主要新增項。其他資料類別在加訂閱前就已存在。

---

## App 實際的資料行為(據實盤點)

### 身分 / 帳號
- 登入:只有 **Google** 和 **Apple**(OAuth → Firebase Auth),沒有 email/密碼註冊。
- 收集:uid、**email**、**顯示名稱**、**頭像**(來自登入商)。
- **電話**:選用的電話驗證(Firebase Auth 簡訊 OTP);號碼綁到 Firebase Auth 帳號、存本機。
- 已實作**帳號刪除**(滿足 Apple 5.1.1(v) 要求)。

### Profile / 聯絡人
- 使用者自己的名片 + 儲存的聯絡人都存在**本機**(sqflite),不上雲。圖片(頭像、名片正反面、
  掃描的名片)都是本機檔案。
- 唯一寫到 Firestore `users/{uid}` 的:**FCM 推播 token**、**訂閱狀態**(RevenueCat webhook 寫)、
  OCR 回報的貢獻計數。

### 名片辨識(OCR)
- 名片影像送去 **Google Cloud Vision** 做 OCR:
  - BYOK(自帶金鑰):client 直接用使用者的金鑰呼叫 Vision。
  - 共用金鑰:影像送到我們的 Cloud Function `recognizeCard`,由後端呼叫 Vision(金鑰不下發 client)。
  - 離線:裝置端 ML Kit(完全不外傳)。
- 一般辨識**不會**把照片存雲端。只有使用者**明確同意「回報辨識錯誤」**時,才會把名片照上傳
  Firebase Storage(`ocr_feedback/{uid}`),保留 **30 天**(TTL)。

### 名片交換(handshake)
- 交換的聯絡資料**短暫**經過 Firestore `handshakes/{id}`(10 分鐘過期)中轉,payload 可加密。
  收到的聯絡人之後存**本機**。雲端 session 只是中轉,不是長期名片庫。

### 訂閱 / 購買
- **RevenueCat**(`purchases_flutter`)。app_user_id = Firebase uid。RevenueCat 收到 uid +
  平台購買憑證;後端在 `users/{uid}` 存 `subscriptionActive / subscriptionTier / renewsAt`。

### 分析 / 追蹤 / 廣告
- **完全沒有。** 沒有 Firebase Analytics、沒有 Crashlytics、沒有廣告 SDK、沒有 IDFA、
  沒有跨 App 追蹤。→ **iOS 不需要 ATT 授權彈窗。**
- 有用到的 Firebase:Auth、Firestore、Storage、Functions、Messaging(FCM token)、
  Remote Config(只拉設定)。Android 的 `play_install_referrer` 用於 deferred deep-link,非廣告用途。

### 裝置端安全儲存
- flutter_secure_storage(Keychain / Keystore)只存使用者自帶的 Cloud Vision API key,永不離開裝置。

---

## Apple — App Privacy(App Store Connect → App Privacy)

每個類型要回答:是否**收集**?是否**連結身分**?是否用於**追蹤**?
追蹤一律 **NO**(不需要 ATT)。下表右欄的英文是實際要選的用途值。

| 資料類型(Apple 的分類) | 收集 | 連結身分 | 用途(照選英文) |
|---|---|---|---|
| Contact Info → Email address | 是 | 是 | App Functionality |
| Contact Info → Name | 是 | 是 | App Functionality |
| Contact Info → Phone number | 是 | 是 | App Functionality |
| Contact Info → Physical address | 是 | 是 | App Functionality |
| **Purchases** | **是** | **是** | **App Functionality** ← 新增 |
| Identifiers → User ID | 是 | 是 | App Functionality |
| User Content → Photos or Videos(名片圖) | 是 | 是 | App Functionality |
| User Content → Other User Content(名片文字) | 是 | 是 | App Functionality |
| Identifiers → Device ID(FCM token) | 是 | 是 | App Functionality |

- 追蹤(Tracking):全部 **None**。
- Data used to track you:**No**。
- 帳號刪除:**Yes**(App 內 Profile → Delete Account)。

## Google Play — Data Safety

全部歸「App functionality」,無追蹤/廣告:
- Personal info:Name、Email、Phone number、Address → 收集、連結、App functionality。
- **Financial info: Purchase history → 收集、連結、App functionality** ← 新增(RevenueCat/訂閱)。
- Photos:名片影像 → 收集(僅在同意回報時才上雲)。
- App activity / other:OCR 文字(僅在同意回報時)。
- App info & performance:無(沒有 crash/analytics SDK)。
- Device IDs:FCM token(App functionality,推播用)。
- Security:傳輸加密(HTTPS);使用者可要求刪除(App 內帳號刪除)。

會收到資料的第三方:Google(Firebase、Cloud Vision)、RevenueCat、Apple/Google 帳務。
選用、使用者自控:使用者自己的 Google Drive(備份)。

---

## 隱私政策(ixo.app/privacy)—— 已更新的內容
(已於此次一併更新並部署上線,列出供對照,確認標籤與政策一致)
- 使用 **RevenueCat** 處理訂閱、儲存購買/權限狀態。
- 收集**訂閱狀態 / 購買記錄**。
- OCR 經 **Google Cloud Vision**;名片照片預設不留雲端,只有同意回報時保留 30 天。
- 第三方:Google Firebase、Google Cloud Vision、RevenueCat。
- App 內**帳號刪除**,以及如何要求刪除資料。

## 注意事項
- 若 app 之前已上架,大部分標籤已設過,這次具體變動就是**新增 Purchases / Purchase history**。
- **務必據實填** —— Apple/Google 會稽核,宣告與實作不符會被拒/下架。
- Apple 的 Display Name ≤ 30 字元、Description ≤ 45 字元(見 subscription_store_metadata.md)。
