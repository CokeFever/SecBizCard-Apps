# Release 1.6.4 — 送審文案(What's New + App Review 說明)

> 排版檢視:Kiro/VS Code 開此檔按 `Cmd+Shift+V`。1.6.4 上架後,可刪除
> `release_1.6.3_store_copy.md`(保持「只留當前版本一份」)。
> **本檔送審版本 `1.6.4+191`**(含 189 的 App Check client 初始化 + Backup/Web-Editor 揭露區塊,
> 191 的 "Secured Web Editor" 改名 + 區塊移到動作按鈕下方)。注意 build **190 跳過**。
>
> 送審版本:**`1.6.4+191`**。tag `android/v1.6.4+191`(→ Cloud Build → Play internal)、
> `ios/v1.6.4+191`(→ Xcode Cloud → TestFlight)。
> ⚠️ 之前誤打過不帶 build number 的 `android/v1.6.4` / `ios/v1.6.4`(指向舊的 +189 commit
> 2124ab1),那是異常;正式送審用帶 build number 的 `+191` tag(符合歷史慣例如
> `v1.6.3+188`)。舊的無 build-number tag 留著無害。

1.6.4 **沒有新的訂閱/IAP 變動**(訂閱沿用 1.6.1 已上架的 Plus/Pro)。這版對使用者
**有感**的是:
1. **電腦版網頁編輯器揭露(Secured Web Editor)**:Backup & Restore 頁新增一個預設收起的
   說明區塊,介紹可在電腦瀏覽器(ixo.app/editor)大量整理/編輯/合併名片;點網址即複製到
   剪貼簿(不開瀏覽器,因為是給電腦用的)。
2. **Backup 頁版面精簡**:移除頂部放大的雲端圖示與重複標題,保留說明;Web Editor 區塊移到
   「立即備份 / 還原」兩顆按鈕下方,讓主要操作更突出。
3. **幕後:App Check(Play Integrity / App Attest)初始化**(fail-open,不影響任何現有功能;
   後端尚未 enforce)。

> **幕後但重要(不列進 What's New,但內部須知):** 189 已加入 Firebase App Check client 初始化。
> 這是「鎖定後端只給自家 app」的第一步,目前**只在 client 送 attestation、後端不 enforce**,
> 對使用者零影響。後端 enforce 要等新版普及 + 強更後才翻(見
> `.kiro/steering/backend-protection.md` 的 5 步前置鐵律)。

---

## What's New(使用者看的,只講有感的)

字數遠低於 App Store(~4000)/ Play(500)上限。5 語:en / zh-Hant / zh-Hans / ja / ko。

> ⚠️ 每個語言就是**一整段、不要硬換行**。直接整段複製貼進商店的 What's New 欄位。

### en-US
```
Organize on a bigger screen: the Backup & Restore screen now points you to the Secured Web Editor — a companion tool at ixo.app/editor that opens in a desktop browser so you can clean up, edit, and merge a large collection of contacts far faster than on a phone. Your backup is decrypted inside your browser; your data never reaches our servers. We also tidied up the Backup screen layout. Thanks for using SecBizCard!
```

### zh-Hant
```
在大螢幕上整理名片:Backup & Restore 頁面現在會指引你使用 Secured Web Editor —— 一個在電腦瀏覽器開啟的輔助工具(ixo.app/editor),可以比在手機上更快地整理、編輯、合併大量名片。備份會在你的瀏覽器內解密,資料不會傳到我們的伺服器。我們也精簡了備份頁面的版面。感謝您使用 SecBizCard!
```

### zh-Hans
```
在大屏幕上整理名片:Backup & Restore 页面现在会引导你使用 Secured Web Editor —— 一个在电脑浏览器打开的辅助工具(ixo.app/editor),可以比在手机上更快地整理、编辑、合并大量名片。备份会在你的浏览器内解密,数据不会传到我们的服务器。我们也精简了备份页面的版面。感谢您使用 SecBizCard!
```

### ja
```
大きな画面で整理:Backup & Restore 画面から Secured Web Editor をご案内するようになりました。これは ixo.app/editor でデスクトップのブラウザで開く補助ツールで、多数の連絡先をスマートフォンよりずっと速く整理・編集・統合できます。バックアップはブラウザ内で復号され、データが当社のサーバーに届くことはありません。バックアップ画面のレイアウトも整理しました。SecBizCard をご利用いただきありがとうございます!
```

### ko
```
큰 화면에서 정리하기: Backup & Restore 화면에서 이제 Secured Web Editor를 안내합니다. ixo.app/editor에서 데스크톱 브라우저로 여는 보조 도구로, 많은 연락처를 휴대폰보다 훨씬 빠르게 정리·편집·병합할 수 있습니다. 백업은 브라우저 안에서 복호화되며 데이터가 당사 서버에 전달되지 않습니다. 백업 화면 레이아웃도 정리했습니다. SecBizCard를 이용해 주셔서 감사합니다!
```

---

## App Store Connect — App Review Notes(給審核員,英文)

貼進 App Review Information → Notes for Reviewer。整段複製即可(段落換行是刻意的說明文)。

```
1.6.4 is a minor feature + maintenance update. NO changes to in-app purchases or
subscriptions in this version (the Plus/Pro subscriptions were already reviewed
and approved in 1.6.1 and are unchanged). Core functionality (scan, store,
exchange business cards) remains fully usable for free.

WHAT'S NEW (1.6.4)
- Secured Web Editor disclosure: the Backup & Restore screen now shows a
  collapsible section describing a companion desktop-browser tool
  (https://ixo.app/editor) for bulk-organizing/editing/merging contacts. The URL
  is copy-to-clipboard only (it does not open a browser from the app, since the
  editor is meant for a computer). The web editor decrypts the user's own Google
  Drive backup entirely in their browser (drive.file scope); no contact data is
  sent to our servers.
- Backup screen layout tidy-up: removed a redundant hero icon/title, kept the
  description, and moved the web-editor section below the primary action buttons.
- Behind the scenes: the app now initializes Firebase App Check (Play Integrity /
  App Attest). This only attaches attestation tokens; it is fail-open and does not
  gate or change any user-facing functionality.

GOOGLE CONTACTS PERMISSION (unchanged from 1.6.3, still relevant)
- The app offers an OPTIONAL, user-initiated "Save to Google Contacts" action,
  using the Contacts scope (https://www.googleapis.com/auth/contacts). It is fully
  SEPARATE from the Google Drive backup authorization (two independent Google
  Sign-In clients). The app writes ONLY the contacts the user explicitly chooses
  to save (People API createContact); it does not bulk-read, sell, or share
  contacts, and does not use contacts data for advertising.

BACKUP & PRIVACY (Google Drive) — unchanged
- Backup/restore is OPTIONAL and user-initiated. It stores an encrypted ZIP of the
  user's own contacts/profile/settings in the USER'S OWN Google Drive (drive.file
  scope only — the app can access only files it created). No backup data is sent
  to our servers.
- The optional "magic word" derives the encryption key on-device (PBKDF2 →
  AES-256-GCM). When set, the key never leaves the device and we cannot access the
  backup. The Secured Web Editor uses the same magic word to decrypt in-browser.
- No new data types collected vs 1.6.3. App Privacy is unchanged.

HOW TO TEST (no special setup)
- Sign in with any Google or Apple account (no demo account required).
- Phone verification: release regions are US, Canada, Taiwan, Hong Kong, Japan,
  South Korea, China. Use a number in these regions, or the test credentials:
  Test phone number: +886987654321
  Verification code: 654321
- Sign in with Google: use the provided demo credentials (see the demo account
  fields / attached).
- Secured Web Editor (optional, informational): open the Backup & Restore screen
  to see the new collapsible section; tapping the URL copies it to the clipboard.
  To try the editor itself, open https://ixo.app/editor in a desktop browser,
  authorize Google Drive, pick a backup, and enter the magic word.
- Business-card scanning: tap scan, point at a single card on a plain background.
- QR exchange works best with two devices; with one device, try the demo page:
  https://ixo.app/demo

Thank you, and have a great day.
```

## Play Console — release notes(單一欄位,tag blocks)
```
<en-US>
Organize on a bigger screen: the Backup & Restore screen now points you to the Secured Web Editor — a companion tool at ixo.app/editor that opens in a desktop browser so you can clean up, edit, and merge a large collection of contacts far faster than on a phone. Your backup is decrypted inside your browser; your data never reaches our servers. We also tidied up the Backup screen layout. Thanks for using SecBizCard!
</en-US>
<zh-TW>
在大螢幕上整理名片:Backup & Restore 頁面現在會指引你使用 Secured Web Editor —— 一個在電腦瀏覽器開啟的輔助工具(ixo.app/editor),可以比在手機上更快地整理、編輯、合併大量名片。備份會在你的瀏覽器內解密,資料不會傳到我們的伺服器。我們也精簡了備份頁面的版面。感謝您使用 SecBizCard!
</zh-TW>
<zh-CN>
在大屏幕上整理名片:Backup & Restore 页面现在会引导你使用 Secured Web Editor —— 一个在电脑浏览器打开的辅助工具(ixo.app/editor),可以比在手机上更快地整理、编辑、合并大量名片。备份会在你的浏览器内解密,数据不会传到我们的服务器。我们也精简了备份页面的版面。感谢您使用 SecBizCard!
</zh-CN>
<ja-JP>
大きな画面で整理:Backup & Restore 画面から Secured Web Editor をご案内するようになりました。これは ixo.app/editor でデスクトップのブラウザで開く補助ツールで、多数の連絡先をスマートフォンよりずっと速く整理・編集・統合できます。バックアップはブラウザ内で復号され、データが当社のサーバーに届くことはありません。バックアップ画面のレイアウトも整理しました。SecBizCard をご利用いただきありがとうございます!
</ja-JP>
<ko-KR>
큰 화면에서 정리하기: Backup & Restore 화면에서 이제 Secured Web Editor를 안내합니다. ixo.app/editor에서 데스크톱 브라우저로 여는 보조 도구로, 많은 연락처를 휴대폰보다 훨씬 빠르게 정리·편집·병합할 수 있습니다. 백업은 브라우저 안에서 복호화되며 데이터가 당사 서버에 전달되지 않습니다. 백업 화면 레이아웃도 정리했습니다. SecBizCard를 이용해 주셔서 감사합니다!
</ko-KR>
```

---

## 送審備註(與 1.6.3 的差異)
- **本版無 IAP/訂閱變動** → 不需把訂閱附到版本一起送(訂閱已於 1.6.1 核准)。
- **新揭露:Secured Web Editor**。純粹是 Backup 頁的一段說明 + 複製網址,**app 本身不開瀏覽器、
  不新增任何權限、不新增資料收集**。web editor 本身只用 `drive.file`、在瀏覽器內解密,與 app
  的隱私宣稱一致。reviewer notes 已說明。
- **App Check(189 起)**:client 初始化,fail-open,**後端未 enforce**,對使用者/審核零影響。
  不需在 What's New 提;reviewer notes 已輕描淡寫帶過(「attaches attestation tokens, fail-open」)。
- **App Privacy / Data safety**:相較 1.6.3 **無新增資料類型**,維持不變。
- **build 190 跳過**:build number 由 189 直接跳 191(190 未使用)。

## OAuth contacts「未驗證應用程式」退審彈藥(內部備註,預設不主動提)
策略同 1.6.3:**不主動在 reviewer notes 提 contacts OAuth verification 仍在審**。只有審核員
實際遇到「未驗證應用程式」畫面並以此退審/提問時才回覆。備好的英文回覆:
> The "Save to Google Contacts" feature is OPTIONAL and user-initiated. It uses the
> Google Contacts scope, which is currently in Google's OAuth verification review.
> While that review is in progress, Google shows a standard "unverified app" screen
> that the user can pass via "Advanced → continue"; this is Google's own flow, not
> an app defect, and it does not affect any core functionality.
備註:可在送審前把示範帳號**預先授權過 contacts**(已授權帳號不跳警告),填進 demo 帳號欄。
詳見 `docs/oauth_verification.md`。

## 文案宣稱注意(沿用,仍適用)
- "we cannot access the backup" 這類最強隱私宣稱,**只適用於「使用者有設 magic word」**。
  預設(未設密語)仍以帳號衍生金鑰加密。reviewer notes 的 "When set … we cannot access" 措辭
  已限定分狀態,勿對所有使用者宣稱。
