# Release 1.6.3 — 送審文案(What's New + App Review 說明)

> 排版檢視:Kiro/VS Code 開此檔按 `Cmd+Shift+V`。1.6.3 上架後,可刪除
> `release_1.6.2_store_copy.md`(保持「只留當前版本一份」)。
>
> 版本:**`1.6.3+186`**。tag `android/v1.6.3+186`(→ Cloud Build → Play internal)、
> `ios/v1.6.3+186`(→ Xcode Cloud → TestFlight)。

1.6.3 **沒有新的訂閱/IAP 變動**(訂閱沿用 1.6.1 已上架的 Plus/Pro)。這版對使用者
**有感**的是:
1. **掃描更準**:名片掃描前先用畫面導引框做預裁切(native),邊緣偵測更穩;橫向名片
   有專屬提示。
2. **分享更穩**:離線時產生分享 QR 會顯示清楚的「請連網」提示,不再是看不懂的錯誤碼。
3. **UI 小修**:匯入/上傳改用正確的「上傳」圖示(原本是下載樣式的向下箭頭)。

其餘(備份 magic word 模式重新設計 = 設密語不再立即重打包、三動作解耦;修正「存到
Google 聯絡人」在未授權帳號上的 403;備份安全防護字串等)多為幕後改進或行為修正,
**原則上不寫進 What's New**,但 reviewer notes 要說明 Contacts 權限那段(見下)。

---

## What's New(使用者看的,只講有感的)

字數遠低於 App Store(~4000)/ Play(500)上限。5 語:en / zh-Hant / zh-Hans / ja / ko。

> ⚠️ 每個語言就是**一整段、不要硬換行**。直接整段複製貼進商店的 What's New 欄位。

### en-US
```
Sharper scanning: the camera now uses the on-screen guide to pre-crop your card before edge detection, so it locks on more reliably — with a dedicated hint for landscape cards. Sharing is steadier too: if you're offline, the share QR now shows a clear "connect to the internet" message instead of a cryptic error. Plus a cleaner upload icon and the usual reliability fixes. Thanks for using SecBizCard!
```

### zh-Hant
```
掃描更準:相機會先用畫面上的導引框預裁切名片,再做邊緣偵測,鎖定更穩定,橫向名片也有專屬提示。分享也更穩:離線時分享 QR 會顯示清楚的「請連接網路」提示,不再是看不懂的錯誤碼。另有更合適的上傳圖示與例行穩定性修正。感謝您使用 SecBizCard!
```

### zh-Hans
```
扫描更准:相机会先用画面上的引导框预裁切名片,再做边缘检测,锁定更稳定,横向名片也有专属提示。分享也更稳:离线时分享 QR 会显示清楚的「请连接网络」提示,不再是看不懂的错误码。另有更合适的上传图标与例行稳定性修正。感谢您使用 SecBizCard!
```

### ja
```
スキャンがより正確に:カメラが画面上のガイド枠でカードを先に切り抜いてからエッジ検出するため、より確実に捉えられます。横向きのカード用のヒントも追加。共有も安定:オフライン時は共有 QR に分かりにくいエラーの代わりに「インターネットに接続してください」と明確に表示します。さらに分かりやすいアップロードアイコンと通常の安定性改善も。SecBizCard をご利用いただきありがとうございます!
```

### ko
```
더 정확한 스캔: 카메라가 화면의 안내 틀로 명함을 먼저 잘라낸 뒤 가장자리를 인식해 더 안정적으로 잡아냅니다. 가로 명함용 안내도 추가되었습니다. 공유도 더 안정적입니다: 오프라인일 때 공유 QR이 알 수 없는 오류 대신 "인터넷에 연결하세요"라고 명확히 안내합니다. 여기에 더 알맞은 업로드 아이콘과 일반적인 안정성 개선도 포함되었습니다. SecBizCard를 이용해 주셔서 감사합니다!
```

---

## App Store Connect — App Review Notes(給審核員,英文)

貼進 App Review Information → Notes for Reviewer。整段複製即可(段落換行是刻意的說明文)。

```
1.6.3 is a maintenance + reliability update. NO changes to in-app purchases or
subscriptions in this version (the Plus/Pro subscriptions were already reviewed
and approved in 1.6.1 and are unchanged). Core functionality (scan, store,
exchange business cards) remains fully usable for free.

WHAT'S NEW (1.6.3)
- Sharper scanning: the camera pre-crops the card using the on-screen guide frame
  before edge detection (native implementation), improving lock-on; a dedicated
  hint is shown for landscape-oriented cards.
- Steadier sharing: when the device is offline, the share-QR screen now shows a
  clear, localized "connect to the internet" message instead of a raw error code.
- Cleaner upload icon; plus reliability fixes.
- Backup "magic word" flow was redesigned so setting a passphrase no longer
  re-packs the cloud backup immediately (it takes effect on the next backup).
  This is a behavior/UX fix; backup encryption format is unchanged.

GOOGLE CONTACTS PERMISSION (important for this review)
- The app offers an OPTIONAL, user-initiated "Save to Google Contacts" action.
  This version fixes a bug where that action could fail with a 403 for accounts
  that had not previously granted the Contacts permission: the app now explicitly
  requests the Contacts scope (https://www.googleapis.com/auth/contacts) before
  writing, so the Google consent screen is shown as expected.
- The app writes ONLY the contacts the user explicitly chooses to save (via the
  People API createContact). It does not bulk-read, sell, or share the user's
  contacts, and does not use contacts data for advertising.

BACKUP & PRIVACY (Google Drive) — unchanged from 1.6.2
- Backup/restore is OPTIONAL and user-initiated. It stores an encrypted ZIP of the
  user's own contacts/profile/settings in the USER'S OWN Google Drive (drive.file
  scope only — the app can access only files it created, not the user's other
  Drive content). No backup data is sent to our servers.
- The optional "magic word" derives the encryption key on-device (PBKDF2 →
  AES-256-GCM). When set, the key never leaves the device and we cannot access the
  backup. Default (no magic word) encrypts with an account-derived key for
  seamless same-account restore. All client-side; no server involvement.
- No new data types collected vs 1.6.2. App Privacy is unchanged.

HOW TO TEST (no special setup; same as before)
- Sign in with any Google or Apple account (no demo account required).
- Phone verification: release regions are US, Canada, Taiwan, Hong Kong, Japan,
  South Korea, China. Use a number in these regions, or the test credentials:
  Test phone number: +886987654321
  Verification code: 654321
- Sign in with Google: use the provided demo credentials (see the demo account
  fields / attached).
- Business-card scanning: tap scan, point at a single card. Tip for best edge
  detection: place the card on a plain, non-patterned background. Try both
  portrait and landscape cards to see the pre-crop + landscape hint.
- Save to Google Contacts: open a saved card, choose "Save to Google Contacts" —
  the Google consent screen for the Contacts scope will appear on first use.
- QR exchange works best with two devices; with one device, try the demo page:
  https://ixo.app/demo

Thank you, and have a great day.
```

## Play Console — release notes(單一欄位,tag blocks)
```
<en-US>
Sharper scanning: the camera now uses the on-screen guide to pre-crop your card before edge detection, so it locks on more reliably — with a dedicated hint for landscape cards. Sharing is steadier too: if you're offline, the share QR now shows a clear "connect to the internet" message instead of a cryptic error. Plus a cleaner upload icon and the usual reliability fixes. Thanks for using SecBizCard!
</en-US>
<zh-TW>
掃描更準:相機會先用畫面上的導引框預裁切名片,再做邊緣偵測,鎖定更穩定,橫向名片也有專屬提示。分享也更穩:離線時分享 QR 會顯示清楚的「請連接網路」提示,不再是看不懂的錯誤碼。另有更合適的上傳圖示與例行穩定性修正。感謝您使用 SecBizCard!
</zh-TW>
<zh-CN>
扫描更准:相机会先用画面上的引导框预裁切名片,再做边缘检测,锁定更稳定,横向名片也有专属提示。分享也更稳:离线时分享 QR 会显示清楚的「请连接网络」提示,不再是看不懂的错误码。另有更合适的上传图标与例行稳定性修正。感谢您使用 SecBizCard!
</zh-CN>
<ja-JP>
スキャンがより正確に:カメラが画面上のガイド枠でカードを先に切り抜いてからエッジ検出するため、より確実に捉えられます。横向きのカード用のヒントも追加。共有も安定:オフライン時は共有 QR に分かりにくいエラーの代わりに「インターネットに接続してください」と明確に表示します。さらに分かりやすいアップロードアイコンと通常の安定性改善も。SecBizCard をご利用いただきありがとうございます!
</ja-JP>
<ko-KR>
더 정확한 스캔: 카메라가 화면의 안내 틀로 명함을 먼저 잘라낸 뒤 가장자리를 인식해 더 안정적으로 잡아냅니다. 가로 명함용 안내도 추가되었습니다. 공유도 더 안정적입니다: 오프라인일 때 공유 QR이 알 수 없는 오류 대신 "인터넷에 연결하세요"라고 명확히 안내합니다. 여기에 더 알맞은 업로드 아이콘과 일반적인 안정성 개선도 포함되었습니다. SecBizCard를 이용해 주셔서 감사합니다!
</ko-KR>
```

---

## 送審備註(與 1.6.2 的差異)
- **本版無 IAP/訂閱變動** → 不需把訂閱附到版本一起送(訂閱已於 1.6.1 核准)。
- **Contacts(People API)權限是本版 reviewer notes 的新重點**:1.6.3 修了「存到 Google
  聯絡人」在未授權帳號上的 403(現在會先 `requestScopes(contacts)`,正確觸發同意畫面)。
  reviewer notes 已主動說明用途與界線(只寫使用者明確選的、不批次讀、不販售、不做廣告),
  對應正在進行的 **OAuth app verification**(sensitive scope `contacts`,見
  `docs/oauth_verification.md`)。
- **預裁切是 native(Kotlin+Swift)**:上架前務必真機測各 form factor(見
  `docs/card_detection_scoring.md` / handoff 紅字)。reviewer「HOW TO TEST」已請審核員
  試 portrait + landscape。
- **App Privacy / Data safety**:相較 1.6.2 **無新增資料類型**,維持不變。Contacts 權限
  本來就已存在(非本版新增的資料收集),僅修正其授權流程。

## 文案宣稱注意(沿用 1.6.2,仍適用)
- "we cannot access the backup" 這類**最強隱私**宣稱,**只適用於「使用者有設 magic word」**。
  預設(未設密語)仍以帳號衍生金鑰加密,我方理論上可解。reviewer notes 的措辭已限定在
  「When set … we cannot access」,保持這個分狀態措辭,勿對所有使用者宣稱。
