# Magic Word 模式重新設計 — Design Note

狀態:**設計定案中(待唯讀調查補程式細節後發實作 workflow)**
日期:2026-10-05
背景:1.6.2 是 magic word 功能首次面對一般使用者。開發/測試過程中發現現有
「設定 magic word 會自動 repack+backup」的模式有兩個嚴重問題,決定重新設計把三個
動作徹底解耦。**非緊急**(真實首次使用者不會有「舊密語加密的雲端檔」前提,踩到原
bug 的機率低),目標是把模式修對,不趕 build。

---

## 促成重新設計的三個問題

1. **設密語時解不開舊檔 → repack 失敗 + 密語被 rollback。**
   `setMagicWordAndRepack` 會下載舊雲端檔、用本機舊密語解密再重加密。若雲端檔是用
   「別的密語」加密的,本機密語解不開 → `WrongMagicWordFailure('Magic word
   required for this backup')` → 整個流程炸掉並 rollback 剛設的密語。
   (開發者實測:刪掉 Drive 的 zip 後重設密語就正常,因為走到了 `sourceId==null`
   的 `backup(force:true)` 正確分支。)

2. **重裝後「設密語自動備份」會覆寫掉要還原的檔(資料遺失風險)。**
   重裝/登出後本機密語被清、本機資料也空。若使用者先去「Set Magic Word」想把密語
   設回來以便 restore,設完會自動 `backup(force:true)` 用**空的本機資料**覆寫雲端,
   把原本要還原的備份蓋掉。

3. **根因:**「設定 magic word」被綁上了「立即用本機資料覆寫雲端」的副作用。這個
   假設只在「本機有資料、要往上覆寫」時成立;在「本機空、要還原」時是破壞性的。

---

## 核心原則:三個動作完全獨立,各自只做一件事

| 動作 | 做什麼 | 絕不做 |
|---|---|---|
| **設定 magic word** | 驗證 + 存本機偏好(加密用密語)到 secure storage | 不碰 Drive、不備份、不解密任何東西 |
| **Back Up Now** | 用本機資料 + 當前密語(有則 magicword,無則 uid)打包覆寫雲端 | 不解密舊檔 |
| **Restore** | 下載 → 用密語解密 → 寫回本機 | 不寫雲端;密語不吻合就要求重輸 |

密語語意 = 「**下次我寫檔要用的鑰匙(本機偏好)**」,不是「這份雲端檔的鑰匙」。
雲端每份檔案的 header 自帶 `encMode`,解密以 header 為準。

---

## 已拍板的設計決策

1. **(決策 1)設定 magic word 不自動備份。** 只存本機偏好。密語在下次使用者主動
   按「Back Up Now」時才生效。
   - UI:設密語成功後顯示狀態提示,例如「雲端備份尚未用新密語更新,按『立即備份』
     以套用」。讓使用者知道雲端此刻尚未用新密語保護(避免誤以為已加密上傳)。

2. **(決策 2)restore 遇密語不吻合 → 跳提示讓使用者輸入/更換正確密語並重試。**
   - 僅 magicword 模式適用;uid / legacy 檔不需密語,不提示。
   - restore 嚴格只讀,解密失敗/重輸期間都不寫雲端。

3. **(決策 3,restore 後)restore 用正確密語解開後,詢問使用者「要不要把這個密語
   存成本機密語」。** 不自動存,給選擇。
   - 理由:若不存,restore 後第一次備份會退回 uid 模式,把加密降級;存起來則延續
     magicword。但尊重使用者選擇,所以用「詢問」而非「自動」。

4. **(決策 4)「本機有密語、雲端是 uid 檔」要正確處理。** restore 時 codec 看雲端
   header 是 uid 模式就直接用 uid 解,**不可**因為「本機有密語」就錯誤要求輸入密語。

4a. **(決策 2 修正)restore 密語提示要三分狀態**(現在只有兩套、且會在「已設但
   不吻合」時用錯訊息,`backup_screen.dart:216` 一律當「無密語」處理):
   - 本機無密語 → 「請輸入備份密語」(新裝置/重裝)。
   - 本機有密語但解不開 → 「本機密語無法解開此備份,請改用正確密語」(明確是密語
     錯,不是沒設)。
   - 本機有密語且吻合 → 直接解,不跳。
   需在 restore 失敗時依「本機當時有無密語」選訊息。

4b. **(決策 3 修正)輸入的密語改成「解密成功後才詢問是否儲存」。**
   現在 `_promptMagicWordAndRetryRestore` @ `backup_screen.dart:248` 是**重試前就
   自動 `setMagicWord`**。改為:輸入的密語只用於本次解密(先不存);restore 成功
   後跳「要不要在這台裝置記住這個密語?」詢問,選「記住」才 `setMagicWord`。

5. **(文案)** `docs/release_1.6.2_store_copy.md` 與 `magicWordSaved` l10n 字串目前
   寫「加密備份已上傳到 Google Drive」。解耦後設密語不再上傳 → 此句不實,需改為
   「密語已設定,下次備份時生效」語意(5 語)。送審 reviewer notes 那段對外描述
   不受影響(只說 magic word 是選用加密)。等 app 內訊息定稿再一起同步。

8. **(決策 8,定稿)本機空(沒有 contact)→ 直接 DISABLE 備份,不是警示+中斷。**
   全新安裝 / 重裝 / 本機無資料時,備份相關動作(Back Up Now、以及 Set Magic Word
   的任何備份效果)直接 disable,連按都不能按 → 空資料永遠不可能覆寫雲端。畫面引導
   使用者去 Restore(若雲端有備份)。這比「可按但警示」更乾脆、更防呆。
   - 「有無資料」以 contact 為準(contacts 非空)。使用者明說:沒有 contact 就沒有
     備份的意義。
   - (取代前一版「警示+中斷,除非 Overwrite」;使用者改採更強的 disable。)

9. **(決策 9)備份提醒:沒 contact 不提醒 —— 現狀已正確,不改。**
   `main_screen.dart:_maybeShowBackupReminder()` 以 `getSavedContacts().isNotEmpty`
   當 `hasData`,`if (!hasData) return;`;`BackupReminderService.shouldRemind()`
   第一行 `if (!hasData) return false;`。空資料不會跳提醒 ✅。
   → 使用者問的「決策 6 不應該跳備份提醒,修好了嗎」:提醒這一側本就正確。真正要
     修的是「備份動作」側的空資料防護(決策 8),不是提醒。
   → markBackedUp 只在備份/還原成功時呼叫;決策 8 讓空資料連備份都 disable,所以
     不會有「空資料卻記成已備份」的情況。

10. **(決策 10)Backup 與 Restore 都要防呆(統一原則)。**
   - Restore 防呆:覆寫本機資料的確認(已有);密語狀態三分(決策 4a);成功後
     詢問存密語(決策 4b)。
   - Backup 防呆:本機空直接 disable 備份(決策 8);雲端較新 conflict 確認(已有,
     但修「重裝後 localModified==null 退化成一鍵覆寫」);「雲端有備份但本機空」時
     引導先 restore。
   - 核心不變量:**空資料永遠不能覆寫雲端備份;restore 永遠不寫雲端。**

---

## 情境模擬補強(逐情境推演後補的盲點處理)

模擬矩陣見對話;以下是推演後需要額外處理的點,已由使用者裁決:

11. **(決策 11,盲點 2 / D3)備份前若「雲端是 magicword 檔、但本機無密語」→ 提示
    降級。** 使用者本機有資料但沒設密語,雲端卻是密語保護檔(常見於:曾設密語 → 登出
    清掉本機密語)。直接備份會用 uid 覆寫,把加密**悄悄降級**且舊 magicword 檔消失。
    備份前偵測此狀況,跳明確提示:「你的雲端備份目前有密語保護,這次備份將改用預設
    加密(移除密語保護),確定?」使用者確認才繼續。
    - 偵測:備份前讀雲端檔 header 的 `encMode`(`readHeaderOrNull`,不需解密),
      若 `== magicword` 且本機 `hasMagicWord() == false` → 提示。

12. **(決策 12,盲點 3 / C4)restore 覆寫本機要明確告知 + 反向提醒。**
    restore 會覆寫本機現有資料。確認對話框(`backupRestoreConfirmBody`)文案要明說
    「這會以雲端備份覆寫本機現有資料」。並加反向提醒:若偵測到「雲端備份比本機舊」
    (雲端 modifiedTime 早於本機 lastModifiedAt),額外警告「雲端備份比本機資料舊,
    還原會以較舊資料覆蓋」。backup 有 conflict guard,restore 原本沒有對稱保護 →
    補上。

13. **(決策 13,盲點 6)「本機空」以 contact 空為準(使用者裁決)。**
    決策 8 的備份 disable 條件 = contacts 為空。使用者明確選此:沒有 contact 就沒有
    備份的意義。(0 contact 但有 profile 的邊角不特別處理 —— 以 contact 為單一判準,
    避免規則複雜化。)

### 判定為本質行為 / 文案責任(非程式缺陷,靠提示涵蓋)
- 盲點 1(A2):改密語後雲端未同步,直到下次備份 → 「下次備份生效」提示涵蓋。
- 盲點 4(D2):忘記密語 = magicword 雲端檔永久解不開(e2e 本質)→ 設密語時的不可逆
  警告 + 登出時 `app_drawer` 的密語警告涵蓋(確認仍在且文案夠強)。
- 盲點 5(E1):設密語與備份已解耦,存密語須 await 完成;UI 的 disable 狀態刷新要正確
  (`_loadMagicWordState` 類)。解耦後比原本更安全,無需額外機制,但測試要涵蓋狀態刷新。

---

## 實作範圍(待調查補細節後發 workflow)

- `lib/core/services/backup_service.dart`:把 `setMagicWordAndRepack` 改成純
  `setMagicWord`(只驗證+存,無任何 Drive 操作);移除下載/解密/上傳/migrate 的
  dead code(確認 `_migrateDeleteRootIfSafe` / `_isReadableBackup` 仍被 `backup()`
  使用才保留)。
- `lib/features/settings/presentation/screens/backup_screen.dart`:設密語後不觸發
  backup,改顯示「下次備份生效」狀態;restore 密語不吻合的重輸提示 + 可更換;
  restore 成功後詢問是否儲存密語。
- `lib/features/settings/data/magic_word_service.dart`:視需要新增 API。
- `lib/l10n/app_*.arb`(5 語):改 `magicWordSaved` 語意;新增 restore 重輸/
  詢問儲存 的字串。
- `docs/release_1.6.2_store_copy.md`:同步文案。
- 測試:設密語**不**觸發任何 Drive 寫入;restore 遇 magicword 不吻合會要求重輸且
  不覆寫雲端;restore 後儲存密語的選擇路徑。

---

## 唯讀調查結果(wf_93b774c5dfedd4ce,findings.md)— 確認 + 新發現

### restore 是安全的(只讀,不碰雲端)
- `restore()` @ `backup_service.dart:382`:只 search / download / 寫**本機**,
  全程無 `uploadBackup` / `deleteFile`。密語解密 @ ~`:420`。
- UI:`_performRestore()` @ `backup_screen.dart:176`,失敗分支 @ `:216` 捕捉
  `WrongMagicWordFailure` → `_promptMagicWordAndRetryRestore()` @ `:248`
  → `_askForMagicWord()`(l10n: `magicWordRestorePromptTitle` /
  `magicWordRestorePromptBody` / `magicWordEnterLabel` / `commonContinue` /
  `commonCancel`)→ 存密語 → 再 `restore()`;第二次仍錯 → 清掉密語 @ `:276`
  並顯示 `magicWordRestoreWrong`。
  → **決策 2(重輸提示)其實已存在**,只需補強「可更換 + 第二次錯誤的文案」。
  → **決策 3(restore 成功後詢問是否儲存密語)目前是「自動存」**(`setMagicWord`
    在重試前就被呼叫)。需改成「詢問」。

### 設密語一定會寫雲端(兩條破壞路徑)
- `setMagicWordAndRepack()` @ `backup_service.dart:564`:`oldWord` 重裝後為 null;
  `sourceId == null` 分支 @ `:619-620` 直接 `backup(force:true)` →
  **用空的本機資料覆寫雲端**(= 你擔心的資料遺失)。

### 新發現:`backup()` 本身無空資料防護(第二條破壞路徑)
- `backup()` @ `:98` 無條件抓 contacts/profile 打包,**沒有** `contacts.isEmpty &&
  profile == null` 的防護。0 筆也是合法可上傳的 archive → 會乾淨地蓋掉雲端。
- 更糟:即使走 force=false 的一般備份,重裝後 `localModified == null` →
  conflict guard 觸發 `BackupConflictFailure` → UI 跳 `_confirmOverwriteNewerBackup`
  → 使用者按一下「Overwrite」就 `_performBackup(force:true)` 蓋掉雲端。
  guard 退化成「一鍵可覆寫」。
- `force:true`(repack 路徑)**完全跳過** conflict guard @ `:119-137`。

### UI 把重裝使用者推向危險按鈕
- Restore 按鈕在 `!_hasRemoteBackup` 或檢查中時 **disabled** @ `backup_screen.dart:496`;
  `hasBackup()` 只檢查檔案**存在**、不檢查可否解密。
- 「Back Up Now」@ `:481` 與「Set/Change Magic Word」@ `:563` 幾乎永遠 enabled。
- magic-word 區塊說明只講隱私/不可逆,**沒有**警告「你有尚未還原的雲端備份,
  先還原再備份/設密語」。

---

## 補強決策(採調查建議 a+b+d,防禦縱深)

6. **(決策 6)`backup()` 加空資料防護(最高價值,涵蓋所有入口)。**
   當 `contacts.isEmpty && profile == null` 時中止,回傳專屬 failure(如
   `EmptyBackupFailure`),除非呼叫端明確傳 `allowEmpty: true`(給「我真的 0 筆也要
   備份」的合法情況,需使用者明確確認)。即使 UI 引導失敗,空資料也永遠蓋不掉真備份。

7. **(決策 7)Restore 在「雲端有備份但本機空」時成為主要、可達的動作。**
   Restore 按鈕的 enabled 以 `hasBackup()` 存在性為準並視覺優先;當雲端有備份而本機
   空/剛裝時,降級或擋住「Back Up Now」「Set Magic Word」,並加文案說明覆寫風險。
   先還原、再備份。

> 註:決策 1(設密語不備份)已自然移除 `sourceId==null → backup(force:true)` 這條
> 破壞路徑;決策 6 再補 `backup()` 層的空資料防護,兩層獨立防禦。

---

## 更新後的實作範圍(待你最終確認後發 workflow)
1. `setMagicWordAndRepack` → `setMagicWord`:只驗證+存,無任何 Drive 操作;移除
   download/decrypt/upload/migrate dead code(確認 `_migrateDeleteRootIfSafe` /
   `_isReadableBackup` 仍被 `backup()` 使用才保留)。
2. `backup({force, allowEmpty})`:加 `contacts.isEmpty && profile == null` →
   `EmptyBackupFailure`(除非 `allowEmpty`)。
3. `backup_screen.dart`:
   - 設密語成功 → 不備份;顯示「下次備份生效」狀態(決策 1)。
   - restore 密語不吻合 → 重輸 + 可更換 + 第二次錯誤文案(決策 2)。
   - restore 成功解密後 → **詢問**是否儲存密語(決策 3,改掉現在的自動存)。
   - 雲端有備份但本機空 → Restore 設為主要動作、警告覆寫風險(決策 7)。
   - 收到 `EmptyBackupFailure` → 顯示「無資料可備份,是否仍要備份?」而非直接上傳。
4. `magic_word_service.dart`:視需要新增 API(例如 restore 用的「只驗證不存」)。
5. l10n 5 語:改 `magicWordSaved`→「下次備份生效」;新增 restore 詢問儲存、空資料
   防護、覆寫風險警告 的字串。
6. `docs/release_1.6.2_store_copy.md`:同步 app 內文案(等 app 字串定稿)。
7. 測試:設密語不觸發 Drive 寫入;空資料 backup 被擋;restore 遇 magicword 不吻合
   要重輸且不覆寫;restore 後詢問儲存密語的兩條分支;`force:true` 不再繞過空資料防護。
