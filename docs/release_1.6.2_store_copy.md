# Release 1.6.2 — 送審文案(What's New + App Review 說明)

> 排版檢視:Kiro/VS Code 開此檔按 `Cmd+Shift+V`。1.6.2 上架後,可刪除
> `release_1.6.1_store_copy.md`(保持「只留當前版本一份」)。

1.6.2 **沒有新的訂閱/IAP 變動**(訂閱沿用 1.6.1 已上架的 Plus/Pro)。這版對使用者
**有感**的只有兩點:
1. **掃描提示**:名片掃描畫面提示「一次辨識一張名片」,避免對名片簿/多張同框導致辨識錯亂。
2. **備份密語(magic word)**:可為 Google Drive 備份設定只有自己知道的密語加密(進階、選用)。

其餘(備份改存 `My Drive/SecBizCard/` 固定資料夾 + 舊檔遷移、備份提醒時機、登出清除
本機密語/金鑰、備份加密升級為 PBKDF2+AES-GCM 等)都是幕後改進,**不寫進 What's New**。

---

## What's New(使用者看的,只講有感的)

字數遠低於 App Store(~4000)/ Play(500)上限。5 語:en / zh-Hant / zh-Hans / ja / ko。

> ⚠️ 每個語言就是**一整段、不要硬換行**。直接整段複製貼進商店的 What's New 欄位。
> 下面 code block 內故意不折行(顯示會超出畫面,那是正常的)。

### en-US
```
Scanning tips: a gentle reminder to scan one card at a time for cleaner results. Backups now support an optional secret phrase, so only you can unlock your Google Drive backup. Plus the usual reliability fixes. Thanks for using SecBizCard!
```

### zh-Hant
```
掃描提示:輕巧提醒你一次辨識一張名片,辨識更乾淨。備份新增選用的專屬密語,只有你能解開自己的 Google Drive 備份。另有例行的穩定性修正。感謝您使用 SecBizCard!
```

### zh-Hans
```
扫描提示:轻巧提醒你一次识别一张名片,识别更干净。备份新增可选的专属密语,只有你能解开自己的 Google Drive 备份。另有例行的稳定性修正。感谢您使用 SecBizCard!
```

### ja
```
スキャンのヒント:一度に 1 枚ずつスキャンするようやさしくお知らせし、認識をよりクリアに。バックアップに任意の合言葉を追加し、ご自身の Google ドライブのバックアップはあなただけが開けます。あわせて通常の安定性改善も。SecBizCard をご利用いただきありがとうございます!
```

### ko
```
스캔 팁: 한 번에 명함 한 장씩 스캔하도록 부드럽게 안내해 인식이 더 깔끔해집니다. 백업에 선택형 비밀 문구를 추가해, 본인만 자신의 Google 드라이브 백업을 열 수 있습니다. 그 외 일반적인 안정성 개선도 포함되었습니다. SecBizCard를 이용해 주셔서 감사합니다!
```

---

## App Store Connect — App Review Notes(給審核員,英文)

貼進 App Review Information → Notes for Reviewer。整段複製即可(段落換行是刻意的說明文)。

```
1.6.2 is a maintenance + privacy update. NO changes to in-app purchases or
subscriptions in this version (the Plus/Pro subscriptions were already reviewed
and approved in 1.6.1 and are unchanged). Core functionality (scan, store,
exchange business cards) remains fully usable for free.

WHAT'S NEW (1.6.2)
- Scan screen now shows a hint to capture one business card at a time (the OCR is
  single-card by design; this prevents a garbled result when several cards are in
  one frame, e.g. a card-binder page).
- Optional backup "magic word": users can set a secret phrase that encrypts their
  Google Drive backup, so only they can unlock it (see BACKUP & PRIVACY below).
- Backup files moved to a fixed "SecBizCard" folder in the user's own Google Drive,
  with automatic migration of any existing backup. Plus reliability fixes.

BACKUP & PRIVACY (Google Drive)
- Backup/restore is OPTIONAL and user-initiated. It stores an encrypted ZIP of the
  user's own contacts/profile/settings in the USER'S OWN Google Drive (drive.file
  scope only — the app can access only files it created, not the user's other
  Drive content). No backup data is sent to our servers.
- The optional "magic word" derives the encryption key on-device (PBKDF2 →
  AES-256-GCM). When set, the key never leaves the device and we cannot access the
  backup. Default (no magic word) encrypts with an account-derived key for
  seamless same-account restore. This is all client-side; no server involvement.
- No new data types collected vs 1.6.1. App Privacy is unchanged.

HOW TO TEST (no special setup; same as before)
- Sign in with any Google or Apple account (no demo account required).
- Phone verification: release regions are US, Canada, Taiwan, Hong Kong, Japan,
  South Korea, China. Use a number in these regions, or the test credentials:
  Test phone number: +886987654321
  Verification code: 654321
- Sign in with Google: use the provided demo credentials (see the demo account
  fields / attached).
- Business-card scanning: tap scan, point at a single card. Tip for best edge
  detection: place the card on a plain, non-patterned background.
- QR exchange works best with two devices; with one device, try the demo page:
  https://ixo.app/demo

Thank you, and have a great day.
```

## Play Console — release notes(單一欄位,tag blocks)
```
<en-US>
Scanning tips: a gentle reminder to scan one card at a time for cleaner results. Backups now support an optional secret phrase, so only you can unlock your Google Drive backup. Plus the usual reliability fixes. Thanks for using SecBizCard!
</en-US>
<zh-TW>
掃描提示:輕巧提醒你一次辨識一張名片,辨識更乾淨。備份新增選用的專屬密語,只有你能解開自己的 Google Drive 備份。另有例行的穩定性修正。感謝您使用 SecBizCard!
</zh-TW>
<zh-CN>
扫描提示:轻巧提醒你一次识别一张名片,识别更干净。备份新增可选的专属密语,只有你能解开自己的 Google Drive 备份。另有例行的稳定性修正。感谢您使用 SecBizCard!
</zh-CN>
<ja-JP>
スキャンのヒント:一度に 1 枚ずつスキャンするようやさしくお知らせし、認識をよりクリアに。バックアップに任意の合言葉を追加し、ご自身の Google ドライブのバックアップはあなただけが開けます。あわせて通常の安定性改善も。SecBizCard をご利用いただきありがとうございます!
</ja-JP>
<ko-KR>
스캔 팁: 한 번에 명함 한 장씩 스캔하도록 부드럽게 안내해 인식이 더 깔끔해집니다. 백업에 선택형 비밀 문구를 추가해, 본인만 자신의 Google 드라이브 백업을 열 수 있습니다. 그 외 일반적인 안정성 개선도 포함되었습니다. SecBizCard를 이용해 주셔서 감사합니다!
</ko-KR>
```

---

## 送審備註(與 1.6.1 的差異)
- **本版無 IAP/訂閱變動** → 不需把訂閱附到版本一起送(訂閱已於 1.6.1 核准)。
- **新增說明重點**:備份用 **Google Drive(drive.file)**。主動在 reviewer notes 說明資料流向
  (存在使用者自己的 Drive、不經我方伺服器、magic word 本機加密),避免審核員對「資料上傳
  Google Drive」有疑慮而退件。
- **App Privacy / Data safety**:相較 1.6.1 **無新增資料類型**,維持不變。
  (Google Drive 存的是使用者自己的資料到使用者自己的雲端硬碟,非我方收集。)

## 文案宣稱注意(重要)
- "we never have access" 這類**最強隱私**宣稱,**只適用於「使用者有設 magic word」的備份**。
  預設(未設密語)仍以帳號衍生金鑰加密,我方理論上可解。因此:
  - What's New / reviewer notes 的措辭已限定在「設了密語 → 只有你能解開」,**沒有**對所有
    使用者宣稱 we never have access。保持這個分狀態措辭。
  - 隱私政策若要同步加「設定密語後我方無法存取」的描述,請明確綁定「啟用密語時」。
