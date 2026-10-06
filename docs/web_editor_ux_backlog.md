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
