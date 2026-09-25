# Release 1.6.1 — 送審文案(What's New + App Review 說明)

> 送審前只留這一份文件。排版檢視:Kiro/VS Code 開此檔按 `Cmd+Shift+V`。

1.6.1 是這條「新增訂閱」路線的送審版(接續 1.6.0 開發)。對使用者**唯一有感**
的變化:新增選用的 **Plus / Pro 訂閱**,解鎖每月更多雲端 AI 名片辨識。免費的裝置端
辨識照舊。其餘(訂閱狀態同步、名片交換 deeplink、登出隱私、備份提醒時機、後端修正等)
都是「本來就該正常運作」的內部改進,**不寫進 What's New**。

- Plus:US$0.99/月,每月 20 次雲端辨識 · `secbizcard_plus_monthly`
- Pro:US$2.99/月,每月 100 次雲端辨識 · `secbizcard_pro_monthly`
- 同一 subscription group「SecBizCard Cloud Scans」。VIP 是後端 email 允許清單,非商店產品。

---

## What's New(使用者看的,只講有感的)

字數遠低於 App Store(~4000)/ Play(500)上限。5 語:en / zh-Hant / zh-Hans / ja / ko。

> ⚠️ 每個語言就是**一整段、不要硬換行**。直接整段複製貼進商店的 What's New 欄位。
> 下面 code block 內故意不折行(顯示會超出畫面,那是正常的)。

### en-US
```
Introducing Plus and Pro — optional monthly subscriptions that give you more cloud-powered AI business-card scans (20 or 100 per month). Free on-device recognition stays free, and you can still bring your own cloud key. Manage or restore your subscription anytime. Thanks for using SecBizCard!
```

### zh-Hant
```
推出 Plus 與 Pro —— 選用的月訂閱,讓你每月享有更多雲端 AI 名片辨識(20 或 100 次)。裝置端的免費辨識照舊,也仍可自備雲端金鑰。可隨時管理或還原訂閱。感謝您使用 SecBizCard!
```

### zh-Hans
```
推出 Plus 与 Pro —— 可选的月订阅,让你每月享有更多云端 AI 名片识别(20 或 100 次)。设备端的免费识别照旧,也仍可自备云端密钥。可随时管理或恢复订阅。感谢您使用 SecBizCard!
```

### ja
```
Plus と Pro が登場 —— 毎月のクラウド AI 名刺スキャンを増やせる、任意の月額サブスク(月 20 回または 100 回)です。端末内の無料認識は引き続き無料で、自分のクラウドキーも使えます。サブスクはいつでも管理・復元できます。SecBizCard をご利用ありがとうございます!
```

### ko
```
Plus와 Pro 출시 —— 매월 클라우드 AI 명함 스캔을 더 많이 사용할 수 있는 선택형 월간 구독(월 20회 또는 100회)입니다. 기기 내 무료 인식은 계속 무료이며, 자신의 클라우드 키도 사용할 수 있습니다. 구독은 언제든지 관리하거나 복원할 수 있습니다. SecBizCard를 이용해 주셔서 감사합니다!
```

---

## App Store Connect — App Review Notes(給審核員,英文)

貼進 App Review Information → Notes for Reviewer。整段複製即可(段落間的換行是刻意的,審核員看的說明文,不是 What's New)。

```
1.6.1 introduces OPTIONAL auto-renewable subscriptions. Core functionality
(scan, store, exchange business cards) remains fully usable for free.

== WHAT'S NEW (1.6.1) ==
- Two auto-renewable subscriptions in the group "SecBizCard Cloud Scans":
  Plus (secbizcard_plus_monthly, US$0.99/mo, 20 cloud scans) and
  Pro  (secbizcard_pro_monthly, US$2.99/mo, 100 cloud scans).
- Managed via RevenueCat + StoreKit. Restore is provided.

WHERE TO FIND THE PAYWALL
- Open the app → menu → "AI Recognition". The plan card at the top shows the
  current tier; tap "Subscribe" (Basic) or "Upgrade to Pro" (Plus) to open the
  paywall. It shows plans, prices, auto-renewal terms, and links to the Privacy
  Policy and Terms of Use. "Restore purchases" appears there for non-subscribers.

WHAT THE SUBSCRIPTION UNLOCKS
- A larger monthly quota of CLOUD business-card recognitions (Google Cloud
  Vision, server-side). Without a subscription users get a free monthly cloud
  allowance plus unlimited on-device recognition, so the app is fully functional
  for free.

== OCR FEEDBACK (optional "report bad recognition") ==
- Strictly opt-in and confirmed on every submission. Nothing is sent unless the
  user explicitly agrees on that specific card.
- On consent, we upload the card photo plus the recognized text and result,
  used ONLY to reproduce and improve OCR accuracy. Not used for tracking or
  advertising, and not sold.
- Encrypted in transit and at rest, stored in the user's own uid-scoped path,
  and deleted within 30 days.
- A full consent screen is shown in-app (all 5 languages). Details in our
  Privacy Policy: https://ixo.app/privacy
- To review it: scan a card, then on the review screen tap Back; if the result
  looks poor you'll be offered the optional feedback prompt.

== PRIVACY ==
- Subscription state is handled by RevenueCat keyed on the user's account id.
  The app collects no payment/card data (Apple handles billing); App Privacy
  declares a "Purchases" data type. No analytics/ads/tracking SDKs; no ATT.
- App Privacy also covers Contact Info, User Content / Photos, and User ID —
  all "App Functionality", linked, NOT used for tracking.
- Account & data deletion instructions: https://ixo.app/privacy#delete-account

== TESTING ==
Subscriptions
- Sign in with any Google or Apple account (no demo account required).
- Use a Sandbox Apple ID to test purchase/restore. The paywall fetches live
  products from the "default" offering.

Phone verification
- Release regions: US, Canada, Taiwan, Hong Kong, Japan, South Korea, China.
  Use your own number within these regions, or the test credentials below:
  Test phone number: +886987654321
  Verification code: 654321

Sign in with Google
- To test "Sign in with Google" on the login screen, use the provided demo
  credentials (see the demo account fields below / attached).

QR code exchange
- Works best with two devices. With only one device, test the full exchange
  flow via our demo page: https://ixo.app/demo
- Even with a single device you can explore full functionality: create/edit your
  profile, view your QR code, scan physical business cards with the camera (OCR),
  edit a contact's photo, and manage contacts.
- Card scanning tip: for best edge detection, place the card on a plain,
  non-patterned background.

Thank you, and have a great day.
```

## Play Console — release notes(單一欄位,tag blocks)
```
<en-US>
Introducing Plus and Pro — optional monthly subscriptions that give you more cloud-powered AI business-card scans (20 or 100 per month). Free on-device recognition stays free. Manage or restore your subscription anytime from Google Play. Thanks for using SecBizCard!
</en-US>
<zh-TW>
推出 Plus 與 Pro —— 選用的月訂閱,讓你每月享有更多雲端 AI 名片辨識(20 或 100 次)。裝置端的免費辨識照舊。可隨時從 Google Play 管理或還原訂閱。感謝您使用 SecBizCard!
</zh-TW>
<zh-CN>
推出 Plus 与 Pro —— 可选的月订阅,让你每月享有更多云端 AI 名片识别(20 或 100 次)。设备端的免费识别照旧。可随时从 Google Play 管理或恢复订阅。感谢您使用 SecBizCard!
</zh-CN>
<ja-JP>
Plus と Pro が登場 —— 毎月のクラウド AI 名刺スキャンを増やせる任意の月額サブスク(月 20 回または 100 回)です。端末内の無料認識は引き続き無料。サブスクはいつでも Google Play から管理・復元できます。SecBizCard をご利用いただきありがとうございます!
</ja-JP>
<ko-KR>
Plus와 Pro 출시 —— 매월 클라우드 AI 명함 스캔을 더 많이 사용할 수 있는 선택형 월간 구독(월 20회 또는 100회)입니다. 기기 내 무료 인식은 계속 무료입니다. 구독은 언제든지 Google Play에서 관리하거나 복원할 수 있습니다. SecBizCard를 이용해 주셔서 감사합니다!
</ko-KR>
```

---

## 隱私標籤 / Data safety — 這版有變(已完成)
- **Apple App Privacy**:已新增 **Purchases** + **Device ID**(App Functionality、
  linked、無追蹤)。記得 Publish。
- **Play Data safety**:已新增 **Purchase history** + **Device or other IDs**。記得 Submit。
- 詳細對照見 `privacy_labels_guide.md`。隱私政策 + EULA 已更新訂閱條款並上線。

## 送審 gotcha(兩平台)
- **Apple**:group 內第一個訂閱必須**與 app 版本一起送審**。在 App Store Connect
  把兩個訂閱附到 1.6.1 版本一起提交。
- **Play**:訂閱已 Active,app release rollout 到 track 即可;正式版在內測通過後 promote。

## 送審前檢查(細項見 submission_checklist.md)
1. 用乾淨 sandbox 帳號在最新 build 完整跑一輪(訂閱/升級/取消/restore)。
2. iOS 取消→到期降級(後端邏輯與 Android 共用、已驗證;iOS 仍建議實測一次)。
3. 隱私標籤 Publish / Submit。
4. 送審:Apple 把 2 個訂閱附到版本一起送;Play promote。
