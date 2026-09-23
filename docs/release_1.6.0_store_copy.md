# Release 1.6.0 — Store submission copy

Version `1.6.0+170`. This release introduces **optional paid subscriptions**
(Plus / Pro) that add **monthly cloud AI-recognition scans**, integrated via
**RevenueCat** + StoreKit / Google Play Billing. The free tier is unchanged:
on-device recognition stays free/unlimited, and the existing shared cloud quota
+ BYOK (bring-your-own Cloud Vision key) paths remain.

ja/ko are machine-translated (owner skips native review; en/zh-TW authoritative),
consistent with prior releases.

> **Tiers sold:** Plus US$0.99/mo (20 cloud scans), Pro US$4.99/mo (100 cloud
> scans). Auto-renewable monthly. Product IDs `secbizcard_plus_monthly` /
> `secbizcard_pro_monthly` (both stores). VIP is internal (backend email
> allow-list), NOT a store product.

> **⚠️ Privacy labels / data-safety DO change this release** — a purchase adds a
> Purchases (subscription) data type + the RevenueCat SDK. See the compliance
> section; this is the main difference vs 1.5.x maintenance releases.

> Tags `ios/v1.6.0` + `android/v1.6.0` on commit `ee85984`.

---

## App Store Connect — What's New (per locale)

**en-US**
```
• Free on-device recognition stays free, and power users can still bring their own cloud key (BYOK). New optional Plus and Pro subscriptions simply add more monthly cloud scans — the hassle-free way to get sharper recognition without setting up a key.
• Restore, manage, or cancel anytime from your App Store account.
Thanks for using SecBizCard!
```

**zh-Hant**
```
• 裝置端辨識仍然免費,進階使用者也能自備雲端金鑰(BYOK)。新增的 Plus 與 Pro 訂閱只是提供每月更多雲端辨識次數——不必自行設定金鑰,省事又精準。
• 可隨時從 App Store 帳戶還原、管理或取消訂閱。
感謝您使用 SecBizCard!
```

**zh-Hans**
```
• 设备端识别仍然免费,进阶使用者也能自备云端密钥(BYOK)。新增的 Plus 与 Pro 订阅只是提供每月更多云端识别次数——不必自行设置密钥,省事又精准。
• 可随时从 App Store 账户恢复、管理或取消订阅。
感谢您使用 SecBizCard!
```

**ja**
```
• オンデバイス認識は引き続き無料で、上級者は自分のクラウドキー(BYOK)も使えます。新しい任意の Plus / Pro サブスクリプションは、毎月のクラウド認識回数を増やすだけ——キー設定不要で、手軽に認識精度を高められます。
• App Store アカウントからいつでも復元・管理・解約できます。
SecBizCard をご利用いただきありがとうございます。
```

**ko**
```
• 온디바이스 인식은 계속 무료이며, 고급 사용자는 자신의 클라우드 키(BYOK)도 사용할 수 있습니다. 새로운 선택형 Plus / Pro 구독은 매월 클라우드 인식 횟수를 늘려줄 뿐입니다 — 키 설정 없이 손쉽게 인식 정확도를 높이는 방법입니다.
• App Store 계정에서 언제든지 복원, 관리 또는 해지할 수 있습니다.
SecBizCard를 이용해 주셔서 감사합니다.
```

---

## App Store Connect — App Review notes (English)

> This release adds IAP, so review will look at the paywall + restore. Be
> explicit about where the paywall is, that it's optional, and how to test.
```
1.6.0 introduces OPTIONAL auto-renewable subscriptions. Core functionality
(scan, store, exchange business cards) remains fully usable for free without
any subscription.

WHAT'S NEW
- Two auto-renewable subscriptions (same subscription group "SecBizCard Cloud
  Scans"): Plus (secbizcard_plus_monthly, US$0.99/mo, 20 cloud scans) and Pro
  (secbizcard_pro_monthly, US$4.99/mo, 100 cloud scans).
- Purchases are managed through RevenueCat + StoreKit. Restore Purchases is
  provided.

WHERE TO FIND THE PAYWALL
- Open the app → Settings → "AI Recognition" screen → the plan card at the top
  shows the current tier; tap "Subscribe" (or "Upgrade to Pro") to open the
  purchase sheet. "Restore purchases" is in that sheet.

WHAT THE SUBSCRIPTION UNLOCKS
- A larger monthly quota of CLOUD business-card recognitions (Google Cloud
  Vision, server-side). Without a subscription, users get a free monthly cloud
  allowance and unlimited on-device recognition, so the app is fully functional
  for free.

TESTING
- Sign in with any Google or Apple account (no demo account required).
- Use a Sandbox Apple ID to test purchase/restore. The paywall fetches live
  products from the "default" offering.

PRIVACY
- Subscription state is handled by RevenueCat keyed on the user's account id.
  No payment/card data is collected by the app (Apple handles billing). See the
  updated App Privacy: a "Purchases" data type is now declared.
```

---

## Play Console — release notes (single field, tag blocks)
```
<en-US>
• Free on-device recognition stays free, and power users can still bring their own cloud key (BYOK). New optional Plus and Pro subscriptions simply add more monthly cloud scans — the hassle-free way to get sharper recognition without setting up a key.
• Restore or manage your subscription anytime from Google Play.
Thanks for using SecBizCard!
</en-US>
<zh-TW>
• 裝置端辨識仍然免費,進階使用者也能自備雲端金鑰(BYOK)。新增的 Plus 與 Pro 訂閱只是提供每月更多雲端辨識次數——不必自行設定金鑰,省事又精準。
• 你可以隨時從 Google Play 還原或管理訂閱。
感謝您使用 SecBizCard!
</zh-TW>
<zh-CN>
• 设备端识别仍然免费,进阶使用者也能自备云端密钥(BYOK)。新增的 Plus 与 Pro 订阅只是提供每月更多云端识别次数——不必自行设置密钥,省事又精准。
• 你可以随时从 Google Play 恢复或管理订阅。
感谢您使用 SecBizCard!
</zh-CN>
<ja-JP>
• オンデバイス認識は引き続き無料で、上級者は自分のクラウドキー(BYOK)も使えます。新しい任意の Plus / Pro サブスクリプションは、毎月のクラウド認識回数を増やすだけ——キー設定不要で、手軽に認識精度を高められます。
• サブスクリプションはいつでも Google Play から復元・管理できます。
SecBizCard をご利用いただきありがとうございます。
</ja-JP>
<ko-KR>
• 온디바이스 인식은 계속 무료이며, 고급 사용자는 자신의 클라우드 키(BYOK)도 사용할 수 있습니다. 새로운 선택형 Plus / Pro 구독은 매월 클라우드 인식 횟수를 늘려줄 뿐입니다 — 키 설정 없이 손쉽게 인식 정확도를 높이는 방법입니다.
• 구독은 언제든지 Google Play에서 복원하거나 관리할 수 있습니다.
SecBizCard를 이용해 주셔서 감사합니다.
</ko-KR>
```

---

## Store privacy labels / data-safety — CHANGED this release (action required)

> **⏳ TODO TIMING (decided 2026-09-23): NOT done yet — doing purchase testing
> first.** Privacy labels are only needed before the PRODUCTION submission, not
> for internal-testing/sandbox purchase tests. Plan:
> - **Apple App Privacy** → can change anytime (no re-review, instant, doesn't
>   affect the live 1.5.9). Add "Purchases" whenever — recommended before/at
>   1.6.0 submission.
> - **Play Data safety** → change WITH the 1.6.0 production rollout (it needs a
>   Google review and applies to the live version, so align it with 1.6.0).
> - Neither is required to sandbox-test purchases now.


Unlike 1.5.x, 1.6.0 DOES change the privacy disclosures because it adds IAP +
the RevenueCat SDK. Update BEFORE (or with) submission:

### Apple — App Privacy
- Add data type **Purchases** (purchase history) — used for App Functionality.
  RevenueCat receives the transaction + an app-user id (the Firebase uid) to
  track entitlement state.
- Linkage: RevenueCat keys entitlements on the account id, so Purchases is
  "Linked to the user".
- No payment card / financial-account data is collected by the app (Apple/Google
  process payment).
- Everything else stays as previously published (1.5.5–1.5.9).

### Google Play — Data safety
- Under Data types, declare **Purchase history** (App functionality; linked to
  the user; not shared for ads).
- The RevenueCat Android SDK + Play Billing handle the transaction.
- Keep the rest of the form unchanged.

> If unsure about exact wording, err toward disclosing the Purchases/Purchase-
> history type — under-declaring IAP is a common rejection reason.

---

## First-subscription review gotcha (both stores)

- **Apple:** the FIRST subscription in a group must be submitted **together with
  an app version**. So the 1.6.0 build + the two subscriptions (currently
  "Prepare for Submission") get submitted in the same review. Attach the
  subscriptions to the 1.6.0 version in App Store Connect before submitting.
- **Play:** subscriptions are already active; the app release just needs to roll
  out to a track. For production, promote after internal testing passes.

---

## Release checklist (1.6.0)
1. Tags `android/v1.6.0` + `ios/v1.6.0` on commit `ee85984` — pushed; builds
   green (Cloud Build → Play internal testing; Xcode Cloud → TestFlight).
2. **Sandbox-test purchases first** (Plus/Pro buy, upgrade/downgrade, restore →
   entitlement writes → tier shows, quota unlocks). Do NOT submit for production
   until this passes.
3. Backend is DEPLOYED (functions live) + RevenueCat webhook set (test event
   200). This is required for entitlements to work.
4. Update privacy labels / data-safety (see above) — REQUIRED this release.
5. When ready for production:
   - Apple: attach the 2 subscriptions to the 1.6.0 version, paste What's New,
     submit app + subscriptions together.
   - Play: promote the internal-testing release toward production; paste notes.
