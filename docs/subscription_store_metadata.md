# Subscription Store Metadata (App Store + Play Store)

Copy-paste metadata for the two subscription products, in the five supported
UI languages (en / zh-TW / zh / ja / ko). Wording matches the in-app paywall
(`ocrPaywallPlanPlus/Pro`, `ocrPlanPlusDesc/ProDesc`) so the store and the app
stay consistent.

Products (same IDs on both stores):
- `secbizcard_plus_monthly` — Plus, US$0.99/mo (≈ NT$30), 20 cloud scans/month
- `secbizcard_pro_monthly`  — Pro,  US$2.99/mo (≈ NT$90), 100 cloud scans/month

Both live in the subscription group **SecBizCard Cloud Scans** (Pro ranks above
Plus). VIP is internal (backend email allow-list), NOT a store product.

---

## Apple App Store Connect

Per language, each subscription needs a **Display Name** (≤ 30 chars) and a
**Description** (≤ 45 chars). Set under Subscriptions → <product> → Localizations.

### Plus (`secbizcard_plus_monthly`)

| Language | Display Name | Description |
|----------|--------------|-------------|
| English (U.S.) | SecBizCard Plus | 20 cloud business-card scans per month |
| Chinese (Traditional) | SecBizCard Plus | 每月 20 次雲端名片辨識 |
| Chinese (Simplified) | SecBizCard Plus | 每月 20 次云端名片识别 |
| Japanese | SecBizCard Plus | 毎月 20 回のクラウド名刺スキャン |
| Korean | SecBizCard Plus | 매월 명함 클라우드 스캔 20회 |

### Pro (`secbizcard_pro_monthly`)

| Language | Display Name | Description |
|----------|--------------|-------------|
| English (U.S.) | SecBizCard Pro | 100 cloud business-card scans per month |
| Chinese (Traditional) | SecBizCard Pro | 每月 100 次雲端名片辨識 |
| Chinese (Simplified) | SecBizCard Pro | 每月 100 次云端名片识别 |
| Japanese | SecBizCard Pro | 毎月 100 回のクラウド名刺スキャン |
| Korean | SecBizCard Pro | 매월 명함 클라우드 스캔 100회 |

Char counts (all within Apple's 45-char description limit):
- EN Plus 38 / Pro 39 · zh-TW Plus 11 / Pro 12 · JA Plus ~17 / Pro ~18 · KO ~14/15

Also required per subscription:
- **App Review Screenshot**: `~/Desktop/iap_review_out/iap_plus_review.jpg` and
  `iap_pro_review.jpg` (1640×2360, JPEG, no alpha — iPad mini portrait spec).
- Subscription duration: 1 month; price already set (US$0.99 / US$2.99).

---

## Google Play Console

Play uses a **subscription name** + **benefit/description** per base plan/offer.
Same wording:

### Plus (`secbizcard_plus_monthly`)
- Name: SecBizCard Plus
- Benefit / description (en): 20 cloud business-card scans per month
- zh-TW: 每月 20 次雲端名片辨識 · zh: 每月 20 次云端名片识别 · ja: 毎月 20 回のクラウド名刺スキャン · ko: 매월 명함 클라우드 스캔 20회

### Pro (`secbizcard_pro_monthly`)
- Name: SecBizCard Pro
- Benefit / description (en): 100 cloud business-card scans per month
- zh-TW: 每月 100 次雲端名片辨識 · zh: 每月 100 次云端名片识别 · ja: 毎月 100 回のクラウド名刺スキャン · ko: 매월 명함 클라우드 스캔 100회

Play doesn't require a per-product review screenshot the way Apple does, but the
subscription must be Active and included with an app release for review.

---

## Notes / gotchas
- Keep Display Name ≤ 30 chars, Description ≤ 45 chars (Apple truncates).
- Don't put the price in the name/description — the store shows the live price.
- The in-app paywall shows the live store price via `storeProduct.priceString`;
  the static fallback copy (`ocrPlanProPrice` etc.) is only for offline.
