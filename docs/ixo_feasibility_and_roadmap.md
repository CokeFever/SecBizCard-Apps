# IXO 專案可行性與開發路線圖 (Revised for Secure Exchange)

## 1. 專案核心定義 (Rescoped)
**核心價值**: 安全、隱私優先的點對點資訊交換工具。
**關鍵原則**:
1.  **不儲存個資**: 伺服器端不保留任何使用者 Profile 資料。
2.  **QR Code 唯ㄧ**: 僅透過 QR Code 啟動交換，移除 NFC。
3.  **無自訂 ID**: URL 使用隨機 Hash，不支援自訂使用者 ID。
4.  **在線優先**: 移除離線交換與快取複雜度，交換需聯網。

## 2. 技術可行性評估

### 2.1 核心技術堆疊

| **Frontend (Mobile)** | Flutter | ✅ 高 | Android + iOS 雙平台（不含 Web 版本）|
| **Frontend (Website)** | Vue/Nuxt 3 | 🔲 規劃中 | SSR 官網（SEO 優化）|
| **Backend** | Firebase Cloud Functions | ✅ 高 | 處理握手信令 (Signaling) |
| **Database** | Cloud Firestore | ✅ 高 | 僅用於存放暫時的握手 Session (TTL 5 mins) |
| **Auth** | Firebase Auth | ✅ 高 | Google Sign-In |
| **Hosting** | Firebase Hosting | ✅ 高 | 官網 + Deep Link 處理 |
| **Link** | custom domain (ixo.app) | ✅ 高 | 格式: `https://ixo.app/{6-char-hash}` |

### 2.2 移除項目
- ❌ **NFC**: 移除所有 NFC 讀寫功能與 dependencies。
- ❌ **Offline Mode**: 移除離線 QR Code 與本地資料庫同步邏輯。
- ❌ **User Storage**: 移除 Firestore 上的 Users Collection 備份。

---

## 3. 開發路線圖 (Revised Roadmap)

### Phase 1: 核心交換流程 (Current Focus)

**目標：建立全新的 Request-Approval 交換流程**

#### Sprint 1: 清理與重構 (Refactoring) - [Completed]
- [x] **Cleanup**: 移除 NFC, Username, Offline 相關程式碼與套件。
- [x] **Model Update**: 簡化 UserProfile，移除 Server Backup 邏輯。

#### Sprint 2: 新版握手流程 (Handshake V2) - [Completed]
- [x] **Sender (A)**:
    - 介面簡化: "Share My Info" (無下拉選單)。
    - QR 生成: 6 碼 Hash (TTL 5 分鐘, 自動重生模擬)。
    - URL 結構: `https://ixo.app/{hash}`。
- [x] **Receiver (B)**:
    - 掃碼後動作: 顯示 "Send Request" 或 "Abort"。
    - 處理 "Exchange Timeout" (基礎機制已建立)。
- [x] **Sender (A) Response**:
    - 通知中心: 接收 Incoming Request (IncomingRequestDialog)。
    - 決策頁面: 選擇要分享的 Context (Business/Social) -> "Approve" 或 "Reject"。
    - Timeout 機制: 5 分鐘無回應自動失效 (後端邏輯)。

#### Sprint 3: 雙向確認與資料儲存 - [Completed]
- [x] **Data Exchange**:
    - [x] A Approve -> 加密 Payload 傳送給 B (已實作 Payload 傳輸)。
    - [x] B 接收 -> 解密並存入本地儲存 (Local Storage) (已驗證)。
    - [x] (Option) B 回傳自己的資料 (Reciprocal Exchange) (已實作)。

#### Sprint 4: 測試與品質強化 (Testing & Hardening) - [Completed]
- [x] **Unit Tests**:
    - [x] ProfileRepository (Create/Update, Verification).
    - [x] AuthRepository (Google SignIn, SignOut).
    - [x] EditProfileController (Save logic).
- [x] **Refactoring**: 修正多餘的 import 與 linter warnings。

#### Sprint 5: 官網與後端部署 (Official Site & Backend) - [Completed]
- [x] **Functions**: 部署 Firebase Cloud Functions (`firebase deploy --only functions`).
- [x] **Hosting**: 部署 Official Site / Landing Page (`firebase deploy --only hosting`).
- [ ] **Verification**: 確認 Deep Link 導向與基礎功能（需人工驗證）。

#### Sprint 6: 進階功能 (Advanced Features) - [Completed]
- [x] **Backup & Restore**:
    - [x] 整合 Google Drive API (Silent Sign-In).
    - [x] 備份: 聯絡人與設定加密打包 (ZIP + AES).
    - [x] 還原: 解密並驗證資料完整性.
    - [x] UI: Dark Mode 適配與狀態檢查.
- [x] **Contact Management**:
    - [x] 操作優化: Swipe-to-Delete (向左滑動刪除).
    - [x] 狀態同步: 還原後列表即時更新.

#### Sprint 7: OCR & Import (Business Card Scanning) - [Completed]
- [x] **OCR Engine**: On-device text recognition with ML Kit.
    - **Language Support**: Priority on **English**, **Chinese (Traditional & Simplified)**, **Japanese**, and **Korean**.
- [x] **Image Processing**: OpenCV native perspective correction.
- [x] **Information Extraction Priority**:
    1. **Name** (Full Name)
    2. **Phone** (Mobile, Work)
    3. **Email**
    4. **Company**
    5. **Job Title**
- [x] **VCF Interoperability**: .vcf bulk import & export.
    - **Standard**: **vCard 3.0** priority, maximizing **vCard 2.1** compatibility.
    - **Parsing**: Handle parameter variations (e.g., `TEL;WORK:`, `TEL;TYPE=WORK:`).
    - **Fields**: Mapped to native Profile fields with Type preservation.
- [x] **Review UI**: Scanned result verification & manual correction.

#### Sprint 8: Handshake Polishing & Search (v1.2.6) - [Completed]
- [x] **Search & Filter**: Added global search icon and bar to Contacts List.
- [x] **Sorting**: Locale-aware alphabetical sorting for multi-lingual contacts.
- [x] **Handshake Fixes**: Fixed "Lite" context null-safety crash.
- [x] **QR Refresh**: Added manual refresh button (60s cooldown) to QR display.
- [x] **Code Quality**: Cleaned 50+ lint warnings and modernized color APIs.
- [x] **Polishing**: Removed build number from App Drawer version.

#### Sprint 9: Profile & Verification Resilience - [Completed]
- [x] **Profile & Contacts**:
    - [x] Standardized UI copy and unified `FieldFormatter` for custom fields.
    - [x] Added native `showDatePicker` for standard birthday inputs.
    - [x] Hidden pending verification UI tags for secondary emails.
- [x] **Verification Handling**:
    - [x] Fixed dynamic parsing tie-breaker for shared country codes (NANP +1).
    - [x] Enhanced Error UI with `FirebaseAuthException` detection (`credential-already-in-use`).
    - [x] Added 60s UX countdown timer and a 45s silent failure timeout defense.
- [x] **Cloud Backup/Restore**:
    - [x] Implemented full personal `UserProfile` serialization, ensuring settings, custom fields, and profile images persist across devices.

### Phase 2: iOS 支援與上架
- [x] iOS 適配與測試。
- [x] Apple Developer Program 申請與配置。
- [/] App Store 審核與上架。
    - [x] v1.3.1 首次送審被退回。
    - [/] v1.3.2 補上 Sign in with Apple 功能，目前重新送審中。

### Phase 3: 官網 SSR 重構 - [Completed]
使用 **Vue/Nuxt 3** 重建官網，實現 SSR 加速與 SEO 優化。

**規劃頁面：**
| 路由 | 用途 |
|------|------|
| `/` | 首頁 - SecBizCard 功能介紹 |
| `/about` | About Us - 團隊介紹、其他 Projects |
| `/privacy` | 隱私權政策 |
| `/eula` | 使用者條款 |
| `/:sessionId` | Handshake 深度連結（保留 Flutter Web 處理）|

**技術選擇：**
- Framework: Nuxt 3
- Styling: Tailwind CSS
- Hosting: Firebase Hosting (URL Rewrites)
- i18n: @nuxtjs/i18n

---

## 4. 結論

本專案已轉向極簡化設計，專注於「交換當下」的安全性與隱私。透過移除 NFC 與複雜的 Username/Offline 邏輯，大幅降低維護成本與資安風險。

**架構決策（2026-01-31 更新）：**
- ✅ App 僅發布 Android 和 iOS（不提供 Web App 版本）
- ✅ 官網將使用 Vue/Nuxt SSR 重構（SEO + 效能優化）
- ✅ Flutter Web 僅保留處理 Handshake Deep Link
