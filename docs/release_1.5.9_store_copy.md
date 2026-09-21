# Release 1.5.9 — Store submission copy

Version `1.5.9+169`. This release fixes an **iOS/iPadOS launch crash** (UIScene
lifecycle adoption required by iOS 26+, incl. iOS 27), improves business-card
**name recognition**, and adds a **backup-overwrite guard** (warns before an
older device overwrites a newer Google Drive backup). All processing stays
on-device / uses the already-declared Google Drive flow, so **store privacy
labels are UNCHANGED from 1.5.5–1.5.8** (no new data types collected — see the
compliance note at the bottom).

ja/ko are machine-translated (owner skips native review; en/zh-TW authoritative),
consistent with prior releases.

> **Platform difference:** the iOS launch-crash fix line appears **only** in the
> App Store What's New. Android does not have this issue, so the Play notes omit
> it (avoids confusing Play review).

> Tags `ios/v1.5.9` + `android/v1.5.9` are on release commit `93cd1fe`.

---

## App Store Connect — What's New (per locale)

**en-US**
```
• Fixed a crash that closed the app immediately on launch on iOS 26 / iPadOS 26 and later (including iOS 27). The app now launches normally on the latest iOS and iPadOS.
• Improved business-card name recognition, so the real name is picked more reliably instead of a slogan or job title.
• Backup safety: before backing up, the app checks whether the copy in your Google Drive is newer than this device (for example a backup made from another device) and asks for confirmation before overwriting it.
Thanks for using SecBizCard!
```

**zh-Hant**
```
• 修正在 iOS 26／iPadOS 26 及以上(含 iOS 27)一開啟就閃退的問題,App 現在可在最新的 iOS 與 iPadOS 正常啟動。
• 改善名片姓名辨識,更能正確挑出真正的姓名,而非標語或職稱。
• 備份保護:備份前會先檢查 Google 雲端硬碟上的備份是否比這台裝置更新(例如來自另一台裝置的備份),若是則會先提醒並要你確認才覆蓋。
感謝您使用 SecBizCard!
```

**zh-Hans**
```
• 修正在 iOS 26／iPadOS 26 及以上(含 iOS 27)一打开就闪退的问题,App 现在可在最新的 iOS 与 iPadOS 正常启动。
• 改善名片姓名识别,更能正确挑出真正的姓名,而非标语或职称。
• 备份保护:备份前会先检查 Google 云端硬盘上的备份是否比这台设备更新(例如来自另一台设备的备份),若是则会先提醒并要你确认才覆盖。
感谢您使用 SecBizCard!
```

**ja**
```
• iOS 26 / iPadOS 26 以降(iOS 27 を含む)で、起動直後にアプリが落ちる不具合を修正しました。最新の iOS・iPadOS で正常に起動します。
• 名刺の氏名認識を改善し、キャッチコピーや役職ではなく本当の氏名をより確実に選ぶようになりました。
• バックアップの保護:バックアップ前に、Google ドライブ上のバックアップがこの端末より新しいか(例:別の端末で作成したバックアップ)を確認し、上書きする前に確認を求めます。
SecBizCard をご利用いただきありがとうございます。
```

**ko**
```
• iOS 26 / iPadOS 26 이상(iOS 27 포함)에서 실행 직후 앱이 종료되던 문제를 수정했습니다. 최신 iOS 및 iPadOS에서 정상적으로 실행됩니다.
• 명함 이름 인식을 개선하여, 슬로건이나 직함이 아닌 실제 이름을 더 정확하게 선택합니다.
• 백업 보호: 백업하기 전에 Google 드라이브의 백업이 이 기기보다 최신인지(예: 다른 기기에서 만든 백업) 확인하고, 덮어쓰기 전에 확인을 요청합니다.
SecBizCard를 이용해 주셔서 감사합니다.
```

---

## App Store Connect — App Review notes (English)
```
1.5.9 is a maintenance release. No new account requirements and no new data
collection versus 1.5.8.

- iOS launch-crash fix: migrated the app to the UIScene lifecycle (SceneDelegate
  + UIApplicationSceneManifest in Info.plist + FlutterImplicitEngineDelegate in
  AppDelegate), required by iOS 26+ (incl. iOS 27). Previously the app was
  terminated at scene creation on launch.
- Scan: improved name selection so a confidently mis-picked line (slogan/title)
  is corrected in favor of the real name. On-device.
- Backup guard: before uploading, the app compares the existing Google Drive
  backup's server-side modifiedTime against this device's last local change and
  asks for confirmation if the cloud copy is newer. Uses the existing,
  already-declared Google Drive scope; no new data collection.

Google sign-in works with any Google account; no demo account is required.
```

---

## Play Console — release notes (single field, tag blocks)

> Android does NOT include the iOS launch-crash line.
```
<en-US>
• Improved business-card name recognition, so the real name is picked more reliably instead of a slogan or job title.
• Backup safety: before backing up, the app checks whether the copy in your Google Drive is newer than this device (for example a backup made from another device) and asks for confirmation before overwriting it.
Thanks for using SecBizCard!
</en-US>
<zh-TW>
• 改善名片姓名辨識,更能正確挑出真正的姓名,而非標語或職稱。
• 備份保護:備份前會先檢查 Google 雲端硬碟上的備份是否比這台裝置更新(例如來自另一台裝置的備份),若是則會先提醒並要你確認才覆蓋。
感謝您使用 SecBizCard!
</zh-TW>
<zh-CN>
• 改善名片姓名识别,更能正确挑出真正的姓名,而非标语或职称。
• 备份保护:备份前会先检查 Google 云端硬盘上的备份是否比这台设备更新(例如来自另一台设备的备份),若是则会先提醒并要你确认才覆盖。
感谢您使用 SecBizCard!
</zh-CN>
<ja-JP>
• 名刺の氏名認識を改善し、キャッチコピーや役職ではなく本当の氏名をより確実に選ぶようになりました。
• バックアップの保護:バックアップ前に、Google ドライブ上のバックアップがこの端末より新しいか(例:別の端末で作成したバックアップ)を確認し、上書きする前に確認を求めます。
SecBizCard をご利用いただきありがとうございます。
</ja-JP>
<ko-KR>
• 명함 이름 인식을 개선하여, 슬로건이나 직함이 아닌 실제 이름을 더 정확하게 선택합니다.
• 백업 보호: 백업하기 전에 Google 드라이브의 백업이 이 기기보다 최신인지(예: 다른 기기에서 만든 백업) 확인하고, 덮어쓰기 전에 확인을 요청합니다.
SecBizCard를 이용해 주셔서 감사합니다.
</ko-KR>
```

---

## Store privacy labels — UNCHANGED (compliance note)

1.5.9 introduces **no new data collection**:
- The iOS UIScene migration is a lifecycle/plumbing change only; no data
  behavior changes.
- The name-recognition improvement runs on-device.
- The backup guard only reads the existing backup file's server-side
  `modifiedTime` from the user's own Google Drive (already-declared
  `drive.file` scope) before uploading; it collects nothing new and never
  backs up automatically.

Therefore **do not change** the Apple App Privacy labels or the Play Data safety
form — they remain as published for 1.5.5–1.5.8. No "send for review" of the
data-safety form is needed for this version.

---

## Release checklist
1. Tags `android/v1.5.9` (GitHub Actions) + `ios/v1.5.9` (Xcode Cloud) are on
   release commit `93cd1fe` and already pushed.
2. Confirm Android CI green; confirm iOS build via Xcode → Report Navigator →
   Cloud (product lands in TestFlight).
3. App Store Connect: paste per-locale What's New (includes the iOS 27 fix line);
   submit.
4. Play Console: paste the tag-block release notes (no iOS line); roll out.
5. Store labels: leave as-is (see compliance note).
