# Web Editor — UX Backlog (2026-10-06)

> 使用者實測 `ixo.app/editor`(1.6.3 線)後列的 UI/UX 修正清單。設計與既有實作的 source
> of truth:`docs/web_editor_design.md`(架構)+ app 的 `UserProfile` 資料模型(欄位對齊
> 的 ground truth,見下)。本檔是待辦 backlog,實作分批走 workflow。
>
> **跨端一致鐵則**:web editor 編輯的是 SBCB 備份裡的**同一份 contact schema**,欄位必須
> 與 app 對齊,否則 web 存回 → app restore 會對不上。加密格式(`backup_codec.dart`)**勿改**。

## Contact 欄位 ground truth(app `UserProfile`,web editor 必須對齊)
基本:`displayName`(必填)、`email`、`title`、`company`、`department`、`phone`、
`mobile`、`address`、`website`、`photoUrl`/`avatarDriveFileId`。
動態:`customFields: Map<String,String>`(Website / LinkedIn 等)。
名片圖:`cardFrontPath`/`cardBackPath`(+DriveFileId)、`originalImagePath`/`flatImagePath`。
系統(編輯時降權/唯讀):`uid`、`createdAt`、`source`、verification 欄位。

app 的 edit 畫面(`edit_contact_screen.dart`)動態欄位類型(web 至少對齊):
Phone(Work/Home/Mobile/Fax/Other)、Email(Work/Personal/Other)、
Address(Work/Home/Other)、Website(Personal/Company/Blog/Portfolio)、
Social(LinkedIn/Twitter/Facebook/Instagram/GitHub)、Date(Birthday/Anniversary)、Note。

---

## A. Picker(選檔頁)
- **A1** 現在的「Show .zip files only」改成「僅顯示 SecBizCard 備份檔案」——
  用固定檔名 `ixo_app_backup.zip` 過濾(已 `setQuery('ixo_app_backup.zip')`,把 toggle
  文案與行為對齊成「只顯示備份檔」而非泛泛的 zip)。

## B. Editor 主畫面框架
- **B1** 語系切換器重複:上方 menu bar 一個 + footer 一個 → **只留 footer 那個**,移除
  header 的語系切換。
- **B2** Header 與 editor 本體無區隔 → 加分隔線/邊界(border / shadow)。
- **B3** Private / Shared Device 狀態列不重要 → 移到最右邊(弱化)。

## C. Contact List(左欄)
- **C1** 每筆前面加**名片正面縮圖**(cardFront),fallback 到 original scan;hover 放大檢視。
- **C2** 點 list item → 右側先顯示 **detail(唯讀)**;要按「編輯」按鈕才進 edit 模式
  (detail 與 edit 分離,目前是直接 edit)。
- **C3** 選取狀態:勾 Select All / 單選時,**「N selected」只在上方顯示**;下方列保留給功能
  按鈕(Merge/Delete/Cancel)。目前 Select All 視覺無變化、selected 計數位置不對。

## D. 主功能列 / 存檔模型(行為層,較大)
- **D1** 現在是「Find duplicates」+「Save & update backup」。重新定義為三個明確動作:
  1. **Auto-save**:編輯即自動存進記憶體中的工作副本(不需手動 Save)。
  2. **重新打包上傳**:把工作副本重新加密打包 → Drive files.update 同 fileId(明確動作)。
  3. **離開/清除**:不做任何上傳,清除記憶體明文/金鑰,**回到 /editor 的 picker 頁**。
  (呼應共用電腦清除 §10:shared 模式離開必清。)
  - **離開前的 dirty 檢查(重要 UX 保護)**:若記憶體工作副本有「尚未打包上傳到 Drive」的
    變更(auto-save 了但沒按「重新打包上傳」),離開時要**跳確認對話框**(例:「有未上傳的
    變更,離開將遺失。要先重新打包上傳,還是放棄離開?」),提供「打包上傳 / 放棄離開 / 取消」。
    乾淨(無未上傳變更)則直接離開不打擾。
  - 另也要 cover 瀏覽器關閉/重整(`beforeunload`)在 dirty 時提示。
- **D2** Find duplicates 保留。

## E. Contact Detail / Edit(右欄,最大,須對齊 app)
- **E1** detail 唯讀檢視 + 「編輯」按鈕進 edit(見 C2)。
- **E2** edit 介面**至少對齊 app 的編輯功能**(見上 ground truth):
  - 可**新增欄位**(動態 customFields + label 分類),不是只有固定欄位。
  - 多值欄位(多個 phone/email)比照 Google Contacts(圖3/4)+ app 模式。
  - `uid` 等系統欄位移到**最下方**、弱化(目前 uid 顯示在最上方)。
  - 名片圖管理(front/back/original)檢視 + 刪除(對齊 app;web 端新增圖的路徑視設計)。
  - 整體編輯體驗往 Google Contacts 模式靠(圖標、Add email/Add phone、label 下拉等)。

---

## 實作分批建議(待與使用者確認後開 workflow)
- **批次 1(低風險版面)**:A1、B1、B2、B3、C3 —— 純 UI/版面,不碰資料模型。
- **批次 2(list + detail/edit 分離)**:C1、C2、E1 —— master-detail 互動改造。
- **批次 3(編輯器對齊 app,最大)**:E2 + 動態欄位/多值/label —— 碰 contact 編輯模型,
  要確保存回 round-trip 與 app schema 一致。
- **批次 4(存檔模型)**:D1 auto-save + 重新打包 + 離開清除 —— 行為層,要與 §10 清除、
  Drive files.update 流程整合,謹慎測。

> 批次 3/4 風險最高(資料 round-trip + 加密打包),務必含真機實測:web 編輯 → 重新打包 →
> app restore 確認改動進去 + 無-profile 備份仍 restore 得回。


---

## 批次 5 — 四批上線後實測回饋(2026-10-06)

> 使用者實測批次 1~4 後發現。F/G/H 是修正+改進,I 是新功能。

### F. Profile 搬到 header + header 重新設計
- **F1** profile(「我的名片」/`userProfile`)目前被當一列放進 ContactList。改為:
  - 從 ContactList **移除** profile row → 搜尋 + 清單只剩真正的 contacts,變單純。
  - profile **搬到現在顯示檔名的位置**(header 左上),當「這份備份的擁有者」卡片/入口,
    點它進 profile 編輯。
  - store 的 `profile` 與 `contacts` 本來就分開(`contacts.ts` + `activeIsProfile`),只是
    顯示位置要改。
- **F2 header 重新設計**(使用者指定):
  - **移除左上的 logo**(完全不要)。
  - 原本 logo+檔名的位置 → 放 **profile(我的名片)入口**(見 F1)。
  - **檔名 `ixo_app_backup.zip` 靠右**,放在「Find duplicates」按鈕**前面**(弱化、當狀態標示)。
- 確認:兩個「Jack Wang」= profile 一筆 + contacts 一筆,非重複,只是同名。

### G. 「其他欄位」缺明顯的新增入口
- **G1** `CustomFieldsEditor.vue` 有 `addRow()` 但 UI 看不到「新增欄位」按鈕(使用者只看到
  每列的 ×)。→ 補明顯的「+ 新增欄位」入口。

### H. 欄位 key 可自由打字 → 改壞 round-trip 風險
- **H1** `CustomFieldsEditor.vue` 的 key 是 `<input v-model="row.key">`(自由文字)。使用者改
  成亂碼會破壞 app round-trip(app 靠 key 讀資料)。修法分兩類:
  - **下拉是封閉清單,只支援能對應 Google Contacts 的欄位類型**(對標 Google Contacts):
    Phone(Mobile/Work/Home/Main/Fax/Other)、Email(Home/Work/Other)、
    Address(Home/Work/Other)、Website/URL、Birthday/Date、Notes。
    (Organization 的 company/title/department 已是主欄位,不重複進下拉。)
  - **app 特有既有 key**(taxId/postalCode 等不在 Google Contacts 對應集合、但 app/OCR 寫入
    的)→ key **鎖定唯讀**,只能改值或刪除,不可改 key。
  - 目標:使用者只能從封閉清單選,無法把 app 認得的 key 改成 app 認不得的字串。

### I. Excel 式批次編輯(新功能,大)
- **I1** 上方功能列加一個「批次編輯 / 表格檢視」:contacts = rows、欄位 = columns、每格可
  編輯,像試算表一次改所有 contacts。改完走現有 `collapseFields` → repack 流程存回。
  需處理:多值欄位在表格怎麼呈現(可能攤平成 phone_work / email_personal 等欄)、新增列、
  虛擬捲動(大量 contacts 效能)、與現有 master-detail 檢視切換。
  → 獨立大功能,設計先行(序列化回 SBCB schema 同 H 的 key 規則)。


---

## 批次 6 — Excel view 打磨(2026-10-07 實測回饋)

> 使用者實測 Excel 表格視圖後列的改進。純前端 UI,不碰 SBCB codec / round-trip / 授權。

- **J1 表格切換鈕位置**:List|Table 切換鈕從上方工具列移到**搜尋聯絡人框的右側**(跟聯絡人清單同區,語意更合)。
- **J2 隱藏空白欄位**:加一個「隱藏空白欄位」toggle —— 整欄所有 contact 都沒資料的 column 可隱藏,讓有資料的欄位有更多顯示空間。
- **J3 Excel 式捲動(重要)**:header / footer / 工具列**固定不動**,只有表格資料區域**內部**往右/往下捲動(sticky header + 容器內 overflow scroll)。目前是整頁橫向撐開把 header/footer 推走,要改掉。
- **J4 Formula bar 編輯列(取代欄寬自適應)**:表格 cell 維持**固定適中欄寬**,超長內容截斷顯示(…);選中某個 cell 時,在表格**上方一條固定編輯列**顯示該 cell 的**完整內容**並可在那編輯(Excel/Sheets 的 formula bar 模式)。編輯列與 cell 雙向同步。這同時解決「長 email/地址撐爆欄寬」和「內容被切看不到」。**不要**做欄寬自適應(會把表格橫向撐爆)。

> 全部純 UI/版面;序列化仍走 field-grouping.ts collapseFields,sbcb-codec / data.json / round-trip 不動。


---

## 批次 7 — EntryGate collapse + Excel 欄寬(2026-10-07 實測回饋)

- **K1 EntryGate 完成步驟 collapse**:三步 stepper 現在全展開 + 按鈕都留著 → 太高要上下捲。
  改成:步驟完成後 collapse 成單行狀態(①「✓ 授權 Google 雲端硬碟」按鈕消失;②「✓ 已選擇:
  ixo_app_backup.zip」按鈕+toggle 收起),只有**當前步驟**展開顯示操作。
- **K2 步驟③ compact**:「輸入通關密語」(step 標題)和「輸入您的備份暗語」(內層標題)重複,
  合併成一個;輸入框 + 解鎖鈕縮緊。
- **K3 Excel 欄寬自適應(含上限)**:目前固定 ~11rem,短內容欄(姓名/暱稱/部門)佔太寬、又要橫捲。
  改成欄寬**自適應內容但設 max-width 上限** —— 短欄縮窄、長欄到上限截斷(配合 formula bar 看完整)。
  關鍵:設上限避免長內容把表格橫向撐爆。
- **K4 多值欄位改成 Sheets/Excel 式按需長出**:移除表格欄 header 上那排固定的「+」(目前每種
  類型都預掛一個新增多值欄的 +,語意不清又佔空間)。改成:
  - 預設只顯示**有資料的**出現欄(contact 有 2 支行動電話 → 顯示「行動電話」「行動電話 2」;只有
    1 支 → 只顯示 1 欄)。空的 _2/_3 欄不預先出現。
  - 新增多值走 formula bar 旁的動作(選中某 phone/email cell 時出現「+ 新增同類」),或該類型最後
    一個有值 cell 旁才長出新欄 —— 像 Google Sheets 需要時才長欄,不用時不佔空間。
  - 序列化仍走 field-grouping.ts({category}_{label}[_N]),app round-trip 不變。


---

## 批次 8 — hideEmpty 記憶 + 新增 contact + profile 點擊修正(2026-10-07)

- **L1 隱藏空白欄位記憶**:`hideEmpty` 目前是 ContactTable 的 local ref(切清單/表格會歸零)。移到
  store(或 localStorage),切換模式 / 重進維持勾選狀態。
- **L2 新增聯絡人**(目前完全不能新增一筆):兩模式各給符合直覺的入口(方案 c):
  - 清單模式:清單上方/下方「+ 新增聯絡人」按鈕 → 新增一筆空白 contact → 進編輯。
  - 表格模式:底部一列空白可直接輸入(Excel 式,在最後一列打字即新增)。
  - 新增的 contact 走現有 store 新增 + collapseFields 序列化,round-trip 不變;標記 dirty。
- **L3 profile 點擊在表格模式沒反應**:SaveBar「我的名片」呼叫 activateProfile() 設
  activeIsProfile=true,但 profile 編輯走 list/detail 右側 pane,表格模式不顯示該 pane → 看似
  沒反應。修法:點「我的名片」時若在表格模式 → **自動切回清單模式**,才看得到 profile 編輯。
  文案保留「我的名片」(身份標示 + 可點編輯),不改成「編輯我的名片」。


---

## 批次 10 — detail/edit contextual 動作條 + 編輯互斥(2026-10-08)

> 依賴:先完成「fix-merge-modestate」(editor mode 狀態機 browsing/editing/merging/repacking)。
> 本批建立在那個 mode 模型上,不要另造一組 ad hoc 判斷。

- **M1 contextual 動作條(方案 b)**:全域工具列(我的名片/尋找重複/復原/重新打包/離開)**不動**。
  單筆 contact 的操作改放在 **detail pane 頂部一條 contextual 動作條**,與全域工具列視覺對齊但語意分開:
  - 檢視模式(detailMode=view):顯示「編輯這張」「刪除這張」。
  - 編輯模式(detailMode=edit):顯示「完成」「取消/刪除這張」+「+ 新增欄位」入口可留在表單內或提到這條。
  - 把現在散在 ContactDetail/ContactEditor 內的「編輯/完成/新增欄位/刪除」整理到這條,位置一致。
- **M2 編輯時的互斥(用 mode=editing)**:
  - 編輯某 contact 時(mode=editing),擋掉會造成狀態衝突的全域動作:尋找重複、切換表格模式。
  - 切去編輯**另一筆** contact / 點別的列 → 應先「完成」或「取消」當前編輯(或自動 commit,因編輯已 auto-persist 到工作副本,擇一並記錄)。
  - repacking 時(沿用 mode 模型)動作條也 disabled。
  - 所有 disabled 綁到統一的 mode getter,不要再散落判斷。
- 單筆「刪除這張」要有確認;刪除後回到清單/空 detail;標記 dirty;走現有 deleteContacts 路徑。
- 純前端;不碰 codec/schema/round-trip/scope。5 語 i18n。
