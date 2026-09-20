# Release 1.5.8 — Store submission copy

Version `1.5.8+168`. This release adds AI-assisted batch import/export and a
backup reminder; all processing stays on-device, so **store privacy labels are
UNCHANGED from 1.5.5–1.5.7** (no new data types collected — see the compliance
note at the bottom).

ja/ko are machine-translated (owner skips native review; en/zh-TW authoritative),
consistent with prior releases.

> NOT tagged yet — tags `ios/v1.5.8` + `android/v1.5.8` are held pending
> explicit owner approval.

---

## App Store Connect — What's New (per locale)

**en-US**
```
This update makes it easy to move a whole stack of cards in and out of SecBizCard:
• Import a batch with AI: alongside a vCard (.vcf), you can now import a .zip that also contains the cropped card images, so contacts arrive with their photos.
• More export choices: share a contact or a whole selection as a text-only vCard, a .zip that includes the card images (and can be re-imported), or straight to Google Contacts.
• Backup reminder: since your data lives on your device, the app now gives a gentle reminder to back up to your own Google Drive when you have unsaved changes — never automatic, and you can turn it off for the month.
• Contacts can now keep front and back card photos, edited on the contact screen.
Thanks for using SecBizCard!
```

**zh-Hant**
```
本次更新讓整批名片的匯入與匯出更輕鬆：
• 用 AI 批次匯入：除了 vCard（.vcf），現在也能匯入含裁切名片圖的 .zip，聯絡人會連同照片一起帶進來。
• 更多匯出選擇：把單筆或整批聯絡人匯出成純文字 vCard、含名片圖且可再匯入的 .zip，或直接存到 Google 聯絡人。
• 備份提醒：由於資料存在你的裝置上，當有尚未備份的變更時，app 會溫和提醒你備份到自己的 Google 雲端硬碟 —— 絕不自動備份,也可當月關閉。
• 聯絡人現在可保存名片正反面照片，在聯絡人畫面編輯。
感謝您使用 SecBizCard！
```

**zh-Hans**
```
本次更新让整批名片的导入与导出更轻松：
• 用 AI 批量导入：除了 vCard（.vcf），现在也能导入含裁切名片图的 .zip，联系人会连同照片一起带进来。
• 更多导出选择：把单条或整批联系人导出成纯文本 vCard、含名片图且可再导入的 .zip，或直接保存到 Google 通讯录。
• 备份提醒：由于数据存在你的设备上，当有尚未备份的更改时，app 会温和提醒你备份到自己的 Google 云端硬盘 —— 绝不自动备份，也可当月关闭。
• 联系人现在可保存名片正反面照片，在联系人界面编辑。
感谢您使用 SecBizCard！
```

**ja**
```
今回のアップデートで、名刺をまとめて取り込み・書き出しできるようになりました：
• AI でまとめて取り込み：vCard（.vcf）に加え、切り抜いた名刺画像を含む .zip も取り込めるようになり、連絡先が写真付きで追加されます。
• 書き出しの選択肢が増加：連絡先や選択した全件を、テキストのみの vCard、名刺画像付きで再取り込みできる .zip、または Google 連絡先へ直接書き出せます。
• バックアップのお知らせ：データは端末内に保存されるため、未保存の変更があると自分の Google ドライブへのバックアップをそっとお知らせします。自動では行わず、その月は非表示にもできます。
• 連絡先に名刺の表面・裏面の写真を保存できるようになりました（連絡先画面で編集）。
SecBizCard をご利用いただきありがとうございます。
```

**ko**
```
이번 업데이트로 명함을 한꺼번에 가져오고 내보내기가 쉬워졌습니다:
• AI로 한꺼번에 가져오기: vCard(.vcf)와 함께, 잘라낸 명함 이미지가 포함된 .zip도 가져올 수 있어 연락처가 사진과 함께 추가됩니다.
• 더 많은 내보내기 선택: 연락처 하나 또는 선택한 전체를 텍스트 전용 vCard, 명함 이미지가 포함되어 다시 가져올 수 있는 .zip, 또는 Google 주소록으로 바로 내보낼 수 있습니다.
• 백업 알림: 데이터가 기기에 저장되므로, 저장하지 않은 변경이 있으면 본인 Google 드라이브에 백업하도록 부드럽게 알려줍니다. 자동으로 하지 않으며, 그 달 동안 끌 수 있습니다.
• 연락처에 명함 앞뒤 사진을 저장할 수 있습니다(연락처 화면에서 편집).
SecBizCard를 이용해 주셔서 감사합니다.
```

---

## App Store Connect — App Review notes (English)
```
1.5.8 adds on-device batch import/export and a backup reminder. No new account
requirements and no new data collection versus 1.5.7.

- Import: on the Import screen, choose a .vcf (text) or a .zip package
  (manifest.json + cropped card images). Parsing happens entirely on-device.
- Export: from a contact's overflow menu or the multi-select bar, choose
  text-only vCard, a .zip with card images, or Save to Google Contacts.
- Backup reminder: a local, timestamp-based prompt to back up to the user's own
  Google Drive when there are unsaved changes; it makes no network/Drive calls
  itself and never backs up automatically.

Google sign-in works with any Google account; no demo account is required.
```

---

## Play Console — release notes (single field, tag blocks)
```
<en-US>
This update makes it easy to move a whole stack of cards in and out of SecBizCard:
• Import a batch with AI: alongside a vCard (.vcf), you can now import a .zip that also contains the cropped card images, so contacts arrive with their photos.
• More export choices: share a contact or a whole selection as a text-only vCard, a .zip that includes the card images (and can be re-imported), or straight to Google Contacts.
• Backup reminder: a gentle reminder to back up to your own Google Drive when you have unsaved changes — never automatic, and you can turn it off for the month.
• Contacts can now keep front and back card photos.
Thanks for using SecBizCard!
</en-US>
<zh-TW>
本次更新讓整批名片的匯入與匯出更輕鬆：
• 用 AI 批次匯入：除了 vCard（.vcf），現在也能匯入含裁切名片圖的 .zip，聯絡人會連同照片一起帶進來。
• 更多匯出選擇：純文字 vCard、含名片圖且可再匯入的 .zip，或直接存到 Google 聯絡人。
• 備份提醒：有尚未備份的變更時，溫和提醒你備份到自己的 Google 雲端硬碟 —— 絕不自動備份，也可當月關閉。
• 聯絡人現在可保存名片正反面照片。
感謝您使用 SecBizCard！
</zh-TW>
<zh-CN>
本次更新让整批名片的导入与导出更轻松：
• 用 AI 批量导入：除了 vCard（.vcf），现在也能导入含裁切名片图的 .zip，联系人会连同照片一起带进来。
• 更多导出选择：纯文本 vCard、含名片图且可再导入的 .zip，或直接保存到 Google 通讯录。
• 备份提醒：有尚未备份的更改时，温和提醒你备份到自己的 Google 云端硬盘 —— 绝不自动备份，也可当月关闭。
• 联系人现在可保存名片正反面照片。
感谢您使用 SecBizCard！
</zh-CN>
<ja-JP>
今回のアップデートで、名刺をまとめて取り込み・書き出しできるようになりました：
• AI でまとめて取り込み：vCard（.vcf）に加え、切り抜いた名刺画像を含む .zip も取り込め、連絡先が写真付きで追加されます。
• 書き出しの選択肢が増加：テキストのみの vCard、名刺画像付きで再取り込みできる .zip、または Google 連絡先へ直接。
• バックアップのお知らせ：未保存の変更があると自分の Google ドライブへのバックアップをそっとお知らせします。自動では行わず、その月は非表示にできます。
• 連絡先に名刺の表面・裏面の写真を保存できるようになりました。
SecBizCard をご利用いただきありがとうございます。
</ja-JP>
<ko-KR>
이번 업데이트로 명함을 한꺼번에 가져오고 내보내기가 쉬워졌습니다:
• AI로 한꺼번에 가져오기: vCard(.vcf)와 함께, 잘라낸 명함 이미지가 포함된 .zip도 가져올 수 있어 연락처가 사진과 함께 추가됩니다.
• 더 많은 내보내기 선택: 텍스트 전용 vCard, 명함 이미지가 포함되어 다시 가져올 수 있는 .zip, 또는 Google 주소록으로 바로.
• 백업 알림: 저장하지 않은 변경이 있으면 본인 Google 드라이브에 백업하도록 부드럽게 알려줍니다. 자동으로 하지 않으며, 그 달 동안 끌 수 있습니다.
• 연락처에 명함 앞뒤 사진을 저장할 수 있습니다.
SecBizCard를 이용해 주셔서 감사합니다.
</ko-KR>
```

---

## Store privacy labels — UNCHANGED (compliance note)

1.5.8 introduces **no new data collection**:
- `.zip` import/export is processed entirely on-device; nothing is uploaded to a
  backend.
- The backup reminder is a purely local, timestamp-based prompt — it makes no
  network or Google Drive calls to decide whether to show. Actual backup (when
  the user taps "Back up now") uses the existing, already-declared Google Drive
  flow.
- Card images (front/back/original) are stored locally, same as before.

Therefore **do not change** the Apple App Privacy labels or the Play Data safety
form — they remain as published for 1.5.5–1.5.7. No "send for review" of the
data-safety form is needed for this version.

---

## Release checklist (when tagging is approved)
1. Push tags `android/v1.5.8` (GitHub Actions) + `ios/v1.5.8` (Xcode Cloud),
   both on the release commit `ab690b7` — ONLY after explicit owner approval.
2. Confirm Android CI green; confirm iOS build via Xcode → Report Navigator →
   Cloud (product lands in TestFlight).
3. App Store Connect: paste per-locale What's New; submit.
4. Play Console: paste the tag-block release notes; roll out.
5. Store labels: leave as-is (see compliance note).
