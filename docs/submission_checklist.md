# 送審檢查清單(1.6.1 訂閱版 — ✅ 雙平台已過審上架 2026-09-25)

雙平台(App Store + Google Play)送審前的完整待辦。`[x]` 已完成、`[ ]` 待辦、
`[~]` 進行中/部分完成。相關細節見同目錄其他 docs。

> 排版檢視:在 Kiro/VS Code 開此檔按 `Cmd+Shift+V` 開渲染預覽。

---

## A. 程式功能(App 行為)

- [x] 訂閱狀態機:樂觀顯示 → 鎖定動作(syncing)→ 輪詢同步真實用量
- [x] Basic→Plus、Plus→Pro 升級(升級用「所買方案」當目標,避免卡住)
- [x] 「已取消 · 可使用至 X」狀態顯示(取消後仍有效到期末)
- [x] 輪詢超時 fallback:收斂到後端真實值,不卡「無法取得用量」
- [x] Restore 只在 Basic paywall(有訂閱者不顯示,避免誤導)
- [x] 購買前 `logIn(uid)`,杜絕掛到匿名 RevenueCat id
- [x] 相機徽章誠實顯示(同步中顯示 Syncing,不用樂觀值誤導)
- [x] QR 分享畫面 `unavailable` 回前景自癒
- [x] 個人資料頁多語補齊(Verify/Delete Account 等 5 語)
- [x] Paywall 法律揭露(自動續訂說明 + 隱私政策 + 使用條款連結)

## B. 後端

- [x] `resolveTier` 防禦性過期(renewsAt 過期即降級)+ 測試
- [x] RevenueCat webhook reconciliation(避免低階事件蓋掉高階)+ 測試
- [x] webhook 結構化 log(方便診斷)
- [x] 已部署(functions)
- [x] RTDN(Android)已設定
- [x] App Store Server Notifications(iOS)已設定 + IAP `.p8` 已上傳

## C. 商店設定

- [x] 訂閱產品建立:secbizcard_plus_monthly / secbizcard_pro_monthly(兩平台)
- [x] 價格:Plus US$0.99、Pro US$2.99(≈ NT$30 / NT$90)
- [x] Subscription Group「SecBizCard Cloud Scans」(Plus/Pro 同組,順序正確)
- [x] IAP Display Name + Description(5 語)→ 見 subscription_store_metadata.md
- [x] IAP 審核截圖(1640×2360)→ ~/Desktop/iap_review_out/
- [x] App 上架素材(截圖/描述/標題)兩平台
- [x] **App Store Connect 填 App Privacy 標籤**(新增 Purchases + Device ID)→ 記得 Publish
- [x] **Play Console 填 Data Safety**(新增 Purchase history + Device or other IDs)→ 記得 Submit

## D. 法務文件(已上線)

- [x] 隱私政策 ixo.app/privacy 加訂閱段落 + 修正(已部署、線上驗證)
- [x] EULA ixo.app/eula 加訂閱條款(Apple 3.1.2)(已部署、線上驗證)

## E. 測試驗證(送審前必過)

- [x] Android:Basic→Plus→Pro、取消、退款降級 —— 已多次驗證
- [x] iOS:Basic→Plus、Plus→Pro —— 已驗證
- [~] **iOS:取消→到期→降回 Basic** —— sandbox 難模擬,尚未在乾淨環境跑通
      (後端降級邏輯與 Android 共用、已驗證;仍建議想辦法在 iOS 實測一次)
- [ ] **用最新 build 在「乾淨 sandbox 帳號」完整跑一輪**(避免幽靈訂閱干擾)

## F. 送審動作(1.6.1 已送審,等候結果)

- [x] 最終送審版本:**1.6.1+180**(版本名 1.6.1;iOS build 顯示 1.6.1(101))
- [x] iOS:App Store Connect 選 build + 訂閱一起送審
      (Draft Submission 含 iOS App 1.6.1 + SecBizCard Cloud Scans group + Pro + Plus)
- [x] Android:Play Console 建立 production release + AAB + 訂閱一起送審
- [x] 送審備註:App Review Notes 已備妥(訂閱測試、電話驗證、Google 登入、QR、
      OCR feedback、隱私)→ 見 release_1.6.1_store_copy.md

---

## ✅ 結果:1.6.1 雙平台已過審上架(2026-09-25)

- **App Store**:1.6.1 通過審核、上架。訂閱 group「SecBizCard Cloud Scans」+
  Plus + Pro 一併通過。(先被 3.1.2 打回一次,補 Description 的 EULA 連結後 resubmit 過關 — 見 F-1。)
- **Google Play**:1.6.1 production release 通過、上架。訂閱一併通過。

「新增付費訂閱(Plus/Pro)」這條線正式落地。

### 上架後仍建議的觀察項(非阻擋,正式環境驗證)
1. **iOS 取消→到期降級**:sandbox 沒完整驗過,現在可在正式環境用真實訂閱
   (可退款)觀察一次到期降級是否正確回 Basic。後端邏輯與 Android 共用、已驗證。
2. **正式環境的購買/還原**在真機各跑一次,確認 live 產品抓取與 RevenueCat 對接正常。
3. 留意頭幾天的 RevenueCat / webhook log 有無異常事件。

---

## F-1. 送審後被打回的修正紀錄

- **2026-09-25 Apple Guideline 3.1.2(訂閱)** — App Version Rejected(自動檢查):
  「offers auto-renewable subscriptions... but does not include a functional link
  to the Terms of Use (EULA) in the app metadata that appears on the App Store
  product page.」
  - **修法(不需新 build,只改 metadata):**
    1. 在 **App Store 版本頁 → Description** 結尾,每個上架語言都加兩行:
       `Terms of Use (EULA): https://ixo.app/eula`
       `Privacy Policy: https://ixo.app/privacy`
    2. (雙保險)App Information → License Agreement (EULA) 填 `https://ixo.app/eula`。
    3. 存檔後按 **Resubmit to App Review**。訂閱三項(group/Pro/Plus)是
       Ready for Review,會跟著一起重審,不用動。
  - 已線上驗證 EULA + Privacy 連結皆可通、內容含訂閱條款。
  - ⚠️ **常設規則**:提供訂閱的 app,**Description 必須含 EULA 連結**。以後每次送審沿用。
  - **狀態:✅ 已解決** — 5 語 Description 加 EULA + Privacy 連結後 resubmit,
    審核通過上架(無需新 build)。

## G. 下一版再處理(不擋 1.6.1 送審)

Play Console「Create production release」頁看到的增強項,這版先不動,下個版本評估:

- [ ] **開啟 automatic app text translation**(Play 的 3 項 enhancement 只開了 2 項:
      Google Play 簽章 + Automatic protection 已開;自動翻譯還是 Get started)。
      注意:我們的商店文案已人工備妥 5 語(見 release notes / metadata),自動翻譯
      可能與既有人工翻譯衝突或覆蓋,開之前先確認它作用範圍,別把人工文案洗掉。
- [ ] enhancement 變更要**重新上傳 AAB 才生效**(頁面提示
      "Upload your app bundle again to apply enhancement changes")。所以若真的要開,
      排在下個版本 build 時一起做。
- [ ] (順帶留意)Play 顯示 **Quantum-ready signing key available** —— 目前 Google Play
      簽章已啟用,量子安全金鑰是可選升級,列為日後觀察項,非必要。

### Play release notes 品牌一致性(已於 1.6.1 文案修正,存查)
- release notes 五語結尾統一帶 "SecBizCard"(ja/ko 原本漏了,已補)。下版沿用即可。
