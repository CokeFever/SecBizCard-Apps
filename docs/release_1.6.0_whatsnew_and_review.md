# 1.6.0 — What's New(商店文案)+ App Review 送審說明

> 排版檢視:在 Kiro/VS Code 開此檔按 `Cmd+Shift+V`。

上一個上架版本是 1.5.9。這裡的 What's New 只寫**使用者有感**的改變 —— 後端修正、
狀態同步、翻譯補齊、QR 自癒等「本來就該正常運作」的內部工作不列給使用者看。

1.6.0 對使用者真正有感的變化就一件事:**新增付費訂閱(Plus / Pro)**,解鎖更多
雲端 AI 名片辨識額度。

---

## What's New(5 語)

商店的 What's New 有字數上限(App Store 約 4000 字、Play 500 字),下面都遠低於上限。

### English
```
Introducing SecBizCard Plus and Pro — optional monthly subscriptions that give
you more cloud-powered AI business-card scans:
• Plus: 20 cloud scans per month
• Pro: 100 cloud scans per month
Manage or restore your subscription anytime from the AI Recognition screen.
Free on-device recognition is always available.
```

### 繁體中文(Chinese, Traditional)
```
推出 SecBizCard Plus 與 Pro —— 選用的月訂閱方案,讓你享有更多雲端 AI 名片辨識:
• Plus:每月 20 次雲端辨識
• Pro:每月 100 次雲端辨識
可隨時在「AI 辨識」畫面管理訂閱或還原購買。
裝置端的免費辨識隨時都能使用。
```

### 簡體中文(Chinese, Simplified)
```
推出 SecBizCard Plus 与 Pro —— 可选的月订阅方案,让你享有更多云端 AI 名片识别:
• Plus:每月 20 次云端识别
• Pro:每月 100 次云端识别
可随时在“AI 识别”界面管理订阅或恢复购买。
设备端的免费识别随时都能使用。
```

### 日本語(Japanese)
```
SecBizCard Plus と Pro が登場 —— クラウドの AI 名刺スキャンをもっと使える、月額の
サブスクリプション(任意)です。
• Plus:毎月 20 回のクラウドスキャン
• Pro:毎月 100 回のクラウドスキャン
「AI 認識」画面でいつでもサブスクの管理・購入の復元ができます。
端末内での無料認識は常にご利用いただけます。
```

### 한국어(Korean)
```
SecBizCard Plus와 Pro 출시 —— 클라우드 AI 명함 스캔을 더 많이 사용할 수 있는
선택형 월간 구독입니다.
• Plus: 매월 클라우드 스캔 20회
• Pro: 매월 클라우드 스캔 100회
'AI 인식' 화면에서 언제든지 구독을 관리하거나 구매를 복원할 수 있습니다.
기기 내 무료 인식은 항상 사용할 수 있습니다.
```

---

## App Review 送審說明(App Store Connect → App Review Information → Notes)

貼進 App Store Connect 送審提交的「Notes for Reviewer」欄位。用英文(審核員讀英文)。

```
WHAT'S NEW IN THIS VERSION
This release adds optional auto-renewable subscriptions that unlock more
cloud-based AI business-card scans:
- SecBizCard Plus: 20 cloud scans/month (secbizcard_plus_monthly)
- SecBizCard Pro: 100 cloud scans/month (secbizcard_pro_monthly)
Both are in the subscription group "SecBizCard Cloud Scans". Free on-device
recognition (ML Kit) is always available without a subscription.

HOW TO REACH THE SUBSCRIPTION
1. Sign in (Google or Apple).
2. Open the menu → "AI Recognition" (or the OCR settings screen).
3. Tap "Subscribe" (Basic) or "Upgrade to Pro" (Plus) to open the paywall,
   which shows the plans, prices, auto-renewal terms, and links to the
   Privacy Policy and Terms of Use.

MANAGE / RESTORE
- Paid users see "Manage subscription" (opens the App Store subscription
  page) on the AI Recognition screen.
- "Restore purchases" is available on the paywall for users without an
  active subscription.

NOTES
- Auto-renewal disclosure, Privacy Policy (https://ixo.app/privacy) and Terms
  of Use / EULA (https://ixo.app/eula) are shown on the paywall before purchase.
- No account is required to browse, but sign-in is required to subscribe (the
  subscription is tied to the account so it works across the user's devices).
- No ads, no analytics/tracking SDKs; the app does not track users.

DEMO / TEST
- You can sign in with a Google or Apple account to test.
- (If a demo account is needed, provide credentials here.)
```

---

## 注意
- What's New 各語言請貼到對應的 store localization(App Store 的 Simplified/Traditional
  Chinese、Play 的 zh-CN/zh-TW 等)。
- 送審說明的 DEMO/TEST 段:如果審核需要登入才能測訂閱,建議準備一組可用的測試帳號填進去
  (Apple 常要求能實際走到付費頁)。
- 這次「使用者有感」就是訂閱;其餘修正不列入 What's New。
