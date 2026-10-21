# Backend Protection & App Check — Ground Truth (cross-session)

CRITICAL持久事實。重開 session 失憶時,關於「後端防護 / App Check / 誰能用後端」一律以本檔為準。
細節與當時脈絡見 backend repo 的 `SecBizCard/docs/handoff_2026-10-10.md`(handoff 已於 2026-10-18
全數移至 private backend repo)及該 repo 的 investigate-backend-protection findings。

## 為什麼要防護(問題陳述)
> ℹ️ 2026-10-18:`SecBizCard-Apps` **暫時**轉 private,只為清掉不該出現在 public repo 的內部內容
> (handoff、admin UID、owner email 等;含 git 歷史);
> 清乾淨後**計畫轉回 public**。所以以下「public repo」前提**維持成立**,不要當它已永久私有。
> 另注:就算哪天真的永久 private,防護必要性也不消失——Firebase config 是**編譯進商店 app** 的,
> 反編譯 APK/IPA 即可取出,結論與對策不變。

`SecBizCard-Apps` 是 **public repo**(現暫時 private,待清理後轉回)。fork/反編譯者改掉 Android
`applicationId` / iOS bundle id、重新 build,只要仍指向 owner 的 Firebase 專案
(`ixo-app-secbizcard`),**今天就能免費用 owner 的後端**(所有 Cloud Functions callable 只有
Firebase Auth 把關 → 只證明「是個登入使用者」,**證明不了「是哪個 app」**)。防線 = **Firebase
App Check**(Android Play Integrity / iOS App Attest):改了 package name 就產不出有效 attestation,
後端據此拒絕。
- Owner app id(雙平台): `app.ixo.secbizcard`(package name,隨 app 發佈本就可見,非機敏)。
  Owner **admin UID** 是機敏值,**不放 app repo**(因 -Apps 計畫轉回 public)→ 見 backend private 文件
  `SecBizCard/docs/internal_admin_reference.md`。

## 兩類後端服務,授權策略不同(別搞混)
1. **CV OCR(shared Cloud Vision key 池)= `recognizeCard`** → 只放行 owner 自家 app。企業要用 →
   走 **BYOK(自備 Cloud Vision API key)**。關鍵: **BYOK 完全不經過後端**(app 直打
   `https://vision.googleapis.com`,見 `cloud_vision_recognizer.dart`),所以在 `recognizeCard`
   加 App Check enforce **不會弄壞 BYOK**。不需要為 CV 做 allowlist / per-app 計費。
2. **名片交換(handshake callables)** = 共用服務,未來企業可能要互通 → 需要 app-id **allowlist**
   (預設 owner only,可擴充給付費授權)。這是 **Stage 2,尚未實作**。

## App Check 目前狀態(2026-10-10)
- **Client:** app 1.6.4+189 已加 `firebase_app_check 0.3.2+10`,`main.dart` 在
  `Firebase.initializeApp` 後 activate(),**獨立 try/catch fail-open**(失敗只 log、不 crash、不 gate
  功能)。providers kDebugMode 分流(debug→debug / release→playIntegrity+appAttest)。
- **後端(GCP 專案 `ixo-app-secbizcard`):** App Check API 已啟用;Android Play Integrity + iOS
  App Attest provider 已註冊。**所有 service 的 enforcement = OFF(monitor-only)**。= 後端照收所有
  請求,帶不帶 App Check token 都放行。新版上線後 Firebase Console → App Check 會出現 attestation
  metrics 供觀察。

## 🚨 鐵律:後端 enforce 的前置條件(翻 enforce 前**必讀**,違反會打爆線上舊版)
正式商店使用者可能還在 1.6.3 或更舊(無 App Check)。**在下列全部完成前,絕對不要對任何 service /
function 翻 App Check enforce:**
```
1. 新版 app(1.6.4+,含 App Check client)上架雙平台
2. 後端全程 monitor,不 enforce
3. 觀察 Firebase Console App Check metrics:verified 比例上升、舊版(無 token)流量下降
4. 雙平台「強制更新」把舊版使用者趕上來
5. 確認舊版流量幾乎歸零 → 才翻後端 enforce
```
**翻 enforce 必須由 user 明確指示,agent 不得自作主張。**

## 翻 enforce 時實際要做的(Stage 1,等步驟 5 後,另開 workflow)
- 後端 `functions/src/index.ts`:`recognizeCard` + `getOcrUsage` + `submitOcrFeedback` 的 onCall
  options 加 `enforceAppCheck: true`(需要時檢查 `request.app`)。
- **改後端 code → 走手動 `firebase_deploy.yml` 部署**(backend 手動部署慣例,見 cicd.md)。
- BYOK 不受影響(不經過後端)。

## Stage 2(名片交換 + allowlist,未來,尚未做)
- handshake callables(createHandshakeSession / requestHandshake / respondToHandshake /
  returnHandshake)加 enforceAppCheck + server-side app-id allowlist(預設 owner app only)。
- ⚠️ 坑:app **直接訂閱 Firestore handshake doc**(`.snapshots()`,見 `handshake_repository.dart`),
  所以 Firestore 本身也要開 App Check,否則讀取路徑變繞過點 —— 而 Firestore App Check 影響 app
  **所有**直接讀 Firestore 的地方,牽連大,要分階段 monitor。
- 企業授權兩種信任模式:(a) 企業 app 掛 owner 的 Firebase 專案(簡單,租戶隔離弱);(b) 企業用自己
  專案 + per-licensee 憑證(乾淨隔離、符合計費歸企業,工程大)。**建議 Stage 2 先用 (a),但 allowlist
  檢查設計成之後能把 identity key 換成 (b) 而不改呼叫點。**

## App Check Debug Token(開發用,多數情況不需要)
只在「後端 enforce 已開 + 想用**模擬器**測」時才需要(真機有真 attestation,免 token)。要用時:本機
`fvm flutter run` terminal log 會印 `Firebase App Check Debug Token: <UUID>` → 電腦瀏覽器開
Firebase Console → App Check → 該 app → Manage debug tokens → 貼上。只影響開發機。現階段
(monitor + fail-open)完全不用管。
