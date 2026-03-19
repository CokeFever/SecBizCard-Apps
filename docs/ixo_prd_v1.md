Project IXO: 次世代資訊交換服務規格書 (PRD) v1.1

Prepared by: Google Antigravity Team
Date: 2026-01-14
Status: Draft / Phase 1
Version: 1.3 (Added Deep Linking & Deferred Deep Linking specs)

1. 專案願景 (Vision)

建立一個去中心化、隱私優先的數位名片交換生態系。透過 ixo.app 協議，讓使用者完全掌控自己的數據（Data Ownership），利用 Google Cloud Platform (GCP) 的無伺服器架構與 Firebase 的即時能力，實現物理世界與數位世界的無縫資訊流動。

2. 系統架構設計 (System Architecture)

本專案採用 Serverless Architecture，極大化利用 GCP Free-tier 與 Firebase 功能，降低維運成本並確保高可用性。

2.1 技術堆疊 (Tech Stack)

**Mobile App**: Flutter (Android + iOS 雙平台，單一程式碼庫)
- i18n: flutter_localizations, intl package (ARB 檔案)

**Website (SSR)**: Vue/Nuxt 3 (Hosted on Firebase Hosting)
- 用途：官網、About Us、SEO 優化
- i18n: @nuxtjs/i18n
- Styling: Tailwind CSS

**Deep Link Handler**: Flutter Web (僅處理 `/:sessionId` 握手連結)

Backend Logic: Firebase Cloud Functions (Python)。

Database (Signaling & Metadata): Cloud Firestore (用於握手信令、短暫 Session、使用者設定檔 Meta)。

User Data Storage (Source of Truth):

Local Storage: 應用程式沙盒 (SQLite/Realm)。

Cloud Sync: Google Contacts API (聯絡人同步), Google Drive API (App Data Folder 用於備份與圖片存儲)。

Auth & Identity: Firebase Authentication (Google Sign-In, Phone Auth, Email Link)。

Deep Linking: 
- Android: Intent URL + Play Install Referrer API (Deferred Deep Link)
- iOS: Universal Links + Server-side Fingerprinting via Firestore
- Firebase Hosting (Rewrites + apple-app-site-association)

2.2 數據流向原則

Privacy First: 伺服器端 (Backend) 不持久化儲存 使用者的詳細名片資料（如電話、地址）。這些資料僅在交換當下透過加密通道暫存轉發，或點對點傳輸。

User Owned: 所有資料最終儲存在使用者個人的本地裝置，再透過同步機制包存於個人的Google 帳號空間 (Contacts/Drive) 。

3. 功能模組詳解 (Feature Specifications)

3.1 身份識別與驗證 (Identity & Verification)

Google Sign-In: 核心登入方式，自動讀取 Profile 建立基礎帳號。

欄位級別驗證 (Field-Level Verification):

手機號碼: 使用 Firebase Phone Auth (SMS OTP) 進行驗證。驗證後該欄位標記為 Verified。

Email (公司/個人): 發送含有 Token 的驗證信 (Firebase Email Link Auth)。

商業邏輯: 偵測 Email Domain，若為非免費信箱 (非 gmail.com 等)，標記為 Business，未來 B2B 收費鋪路可針對Business Domain驗證加強信任，定期驗證，企業端也可針對Business Email信任進行Revoke (離職的情況)。

3.2 智慧情境管理 (Context Management)

使用者可預設 1-3 組 "Persona" (數位分身)：

情境 (Context)

建議用途

包含欄位範例

隱私層級

Context 1: Business

商務會議、研討會

全名, 職稱, 公司 Email, 公司電話, LinkedIn, 名片圖檔 (正反面)

高 (需授權)

Context 2: Social

派對、聚會

暱稱, 個人 IG/Twitter, 個人 Email, Avatar

中 (半公開)

Context 3: Lite

快速認識

僅姓名, Telegram/Line ID

低

資料來源: 所有欄位對應至 Google Contacts schema (GDPR 相容)。

圖片處理: 名片圖片上傳至使用者的 Google Drive (App Data Folder)，並產生短期 Access Token 供分享使用。

3.3 交換機制與連結規格 (Exchange Mechanism)

3.3.1 連結結構

URL 格式: https://ixo.app/[username]/[tempHash]

[username]:

免費版: 隨機生成的 UUID 或 Firebase UID。

付費版: 自訂 ID (e.g., ixo.app/CokeFever)。

[tempHash]:

由 Cloud Functions 生成的 JWT 或高熵隨機字串。

TTL (Time-To-Live): 預設 5 分鐘。

屬性: One-time use (單次交換後失效) 或 Multi-use (但在時效內)，可依使用者設定，Multi-use可作為收費項目。

3.3.2 交換介質

QR Code: 將上述 URL 編碼為 QR Code。

NFC: 寫入 NDEF 紀錄，內容為上述 URL。

Share Intent: 系統原生分享連結。

3.4 國際化與多語系支援 (Internationalization - i18n)

本服務設計之初即面向全球市場，故需完整支援 i18n。

UI 多語系:

Default: 自動偵測使用者裝置系統語言。

Fallback: 預設為英文 (en-US)。

Initial Support: 繁體中文 (zh-TW), 英文 (en-US)。

架構: 使用 ARB (Application Resource Bundle) 格式管理字串，便於未來整合 Google 的翻譯服務。

資料格式本地化 (Data Localization):

地址格式: 根據聯絡人/使用者所在地動態調整顯示順序 (e.g., 台灣: 國 -> 縣市 -> 區 -> 路; 美國: Street -> City -> State -> Zip)。

電話格式: 支援 E.164 標準儲存，但在 UI 上依據國碼 (Libphonenumber) 進行顯示格式化。

姓名顯示: 支援「姓在前，名在後」(CJK) 或「名在前，姓在後」(Western) 的顯示邏輯。

3.5 UI/UX 架構與導覽 (Navigation Architecture)

為了提升使用者體驗，App 採用「核心三功能」底端導覽與「側邊管理選單」的設計。

3.5.1 底端導覽列 (Bottom Navigation Bar)
- **左側: Share My Card** - 進入名片分享頁面 (QR / NFC)。
- **中央: Scan QR Code (圓形按鈕)** - 核心掃描功能。
- **右側: Card Storage** - 顯示已收集的名片清單 (Card List / Contacts)。

3.5.2 側邊管理選單 (Side Drawer)
- **My Profile**: 顯示與編輯個人資料，處理手機/Email 驗證。
- **Manage Contexts**: 設定不同情境下的欄位可見性。
- **Settings**:
    - 主題切換 (Light/Dark Mode)。
    - NFC 功能開關 (若關閉則在 App 中隱藏所有 NFC 相關 UI，確保 iOS 與無 NFC 裝置的視覺一致性)。
- **Logout (底部)**: 登出功能。

3.6 深度連結與延遲深度連結 (Deep Linking & Deferred Deep Linking)

本系統需要處理兩種情境：用戶已安裝 App 的直接開啟，以及未安裝 App 的安裝後續接。

3.6.1 平台策略

| 平台 | Deep Link 方案 | Deferred Deep Link 方案 |
|------|---------------|------------------------|
| Android | Intent URL + Custom Scheme (`secbizcard://`) | Play Install Referrer API |
| iOS | Universal Links | Server-side Fingerprinting (Firestore) |

3.6.2 Android 實作

**Intent URL**：Landing Page 使用 Android Intent URL 格式，可自動 fallback 到 Play Store：
```
intent://handshake/{sessionId}#Intent;scheme=secbizcard;package=app.ixo.secbizcard;S.browser_fallback_url={playStoreUrl};end
```

**Play Install Referrer**：透過 Play Store 的 referrer 參數傳遞 session ID，App 首次啟動時讀取。

3.6.3 iOS 實作

**Universal Links**：設定 `apple-app-site-association` 於 Firebase Hosting，讓 iOS 自動識別並開啟 App。

**Server-side Fingerprinting**：
- Landing Page 收集設備指紋（IP + User Agent）
- 儲存至 Firestore `pending_sessions` collection
- App 首次啟動時查詢並取得 pending session ID

3.6.4 Landing Page 流程

```
用戶掃描 QR / 點擊連結 (ixo.app/ABC123)
    ↓
Landing Page 偵測平台
    ├─ Android：Intent URL 自動嘗試開啟 App，失敗則跳轉 Play Store
    └─ iOS：Universal Link 嘗試開啟 App，失敗則顯示 App Store 按鈕
    ↓
用戶安裝 App 並首次啟動
    ├─ Android：讀取 Play Install Referrer → 取得 sessionId
    └─ iOS：發送設備指紋查詢 Firestore → 取得 sessionId
    ↓
繼續 Handshake 交換流程
```

詳細技術決策請參閱：`docs/deep_linking_DECISIONS.md`

4. 互動交換協議 (The "IXO Handshake" Protocol)

這是本系統的核心，描述 User A (Host) 與 User B (Guest) 的互動流程。

4.1 流程圖 (文字描述)

Initiation: A 選擇 Context (e.g., Business)，App 請求 Backend 產生 tempHash。

Presentation: A 展示 QR Code (包含 Hash)。

Discovery: B 開啟相機掃描。

Case B1 (未安裝 App): 瀏覽器開啟 ixo.app/... -> 導向 App Store/Play Store 下載 -> 安裝後 Deep Link 喚醒 App 並帶入 tempHash。

Case B2 (已安裝 App): Deep Link 直接喚醒 App。

Connection (Signaling):

B 的 App 解析 tempHash，向 Backend 發送 JoinRequest (包含 B 的基礎資料: Name, Avatar)。

Backend 驗證 Hash 有效性 -> 建立 Firestore Session Document。

Authorization:

A 的 App 監聽 Firestore Session，收到 B 的請求。

UI 顯示: "B 想要交換名片，是否同意？"

Data Transmission (Forward):

A 點擊「同意」。

A 的 App 將 Context 1 (Business) 的加密 JSONPayload 上傳至 Session。

B 的 App 收到 Payload -> 解密 -> 存入 B 的 Local Storage。

B 選擇「儲存至 Google Contacts」 (Option)。

Reciprocity (Reverse - Optional):

B 的畫面顯示: "已收到 A 的名片。是否也要分享您的名片？"

B 選擇 Context (e.g., Business) -> 發送請求給 A。

A 同意 -> B 傳送 Payload -> A 接收。

Closure: Session 標記為 Complete，Firestore Document 於 TTL 後自動刪除。

5. 數據與隱私策略 (Data Strategy)

5.1 儲存分層

Tier 1: Ephemeral (瞬時數據)

位置: Firestore (Session data)。

內容: Handshake tokens, 握手狀態, 暫時交換的加密 Payload。

生命週期: 5-10 分鐘後銷毀。

Tier 2: User Persistent (使用者持久數據)

位置: 使用者的 Android/iOS 設備 (SQLite/Preferences)。

內容: 完整的「名片夾」、歷史紀錄、App 設定。

Tier 3: Cloud Source (雲端來源)

位置: Google Contacts / Google Drive。

內容: 實際的聯絡人資料 (Sync 目標)、圖片資源。

5.2 離線支援 (Offline First)

App 優先讀取本地資料庫。

若 A 在離線狀態產生 QR Code:

生成包含加密 Payload 的 "Static QR Code" (資料量較大)。

B 掃描後可直接解析 (無需聯網)，但在 B 聯網前無法進行雙向確認或更新統計數據。

6. 未來擴充與變現 (Roadmap & Monetization)

Phase 1 (MVP)

基礎 Google Login & Contacts Sync。

單一 Context 分享。

QR Code 掃碼交換流程。

i18n 基礎架構 (繁中/英文)。

Phase 2 (Advanced)

NFC 支援。

多重 Context (Business/Social)。

企業信箱驗證 (Domain Verification) 與信任撤銷機制。

Phase 3 (Monetization - Google One 整合想像)

Premium Username: 訂閱制，保留特定 ID。

Corporate Dashboard: 企業管理員可統一派發名片樣板 (Template)，鎖定職稱與 Logo 欄位。

CRM Integration: 將交換來的名片直接匯出至 Salesforce 或 HubSpot (透過 API)。

7. 結論 (Conclusion)

Project IXO 利用 Google 強大的身份驗證與雲端設施，解決了傳統名片交換「輸入繁瑣」、「資訊過時」與「隱私擔憂」的三大痛點。作為 Google Antigravity 的專案，我們將展示如何優雅地整合 Web 與 Native App，創造流暢的用戶體驗。

Next Step: 開始建置開發環境，初始化 Firebase 專案，並撰寫核心的 Handshake Cloud Functions。