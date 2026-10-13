# Future Backlog — 已決定但尚未實作(cross-session)

重開 session 時,這裡記錄「已討論、owner 同意未來要做、但還沒排進版本」的項目。做了就從這裡移除
並寫進對應 handoff。

## 強制更新機制 + Remote Config version gate(未來 app 版本)
**背景:** app 目前**沒有**強制更新機制(2026-10-12 grep 確認)。但 app 已在用 Firebase Remote
Config(`lib/features/contacts/data/card_detection_config.dart` 已讀 RC),所以加 gate 不用從零開始。

**要做的(未來某個 app 版本,例如 1.6.5+):**
- app 啟動時讀一個 Remote Config 值,例如 `min_supported_build`(整數,對應 pubspec 的 build number)。
- 若當前 app build < `min_supported_build` → 顯示**擋住的更新畫面**(五語:en/zh-TW/zh-CN/ja/ko),
  附「前往商店更新」按鈕(用 url_launcher 開對應商店),不給繼續用。
- 之後要「強更」時,只要在 Firebase Console 把 `min_supported_build` 設成目標 build → 所有舊版
  app 下次啟動被擋 → 被迫更新。**純後台遠端控制,不用再發 app 版本。**

**先天限制(務必記得):** version gate 只能擋「安裝了含 gate 那版之後」的使用者。現在停在 1.6.3/更舊
的使用者沒有 gate 程式,事後設 RC 擋不到他們 —— 他們只能靠商店自然更新。gate 是防止**未來**使用者
卡舊版,以及讓 owner 之後能把 1.6.5+ 的人往上推。

**為什麼要做(動機):** 搭配後端 App Check enforce 的 5 步前置鐵律(見 `backend-protection.md`)——
gate 是「步驟 4:雙平台強更把舊版趕上來」的實作手段,讓 unverified(無 App Check)流量歸零,
才能安全翻後端 enforce。

**平台原生強更的限制(為什麼要自建 RC gate):**
- Android Play In-App Updates 有 immediate 模式,但要 app 接 `in_app_update` plugin 才會觸發
  (目前沒接);Play 後台沒有「遠端一鍵強更」。
- iOS App Store **沒有**原生強更,一定要 app 自己做 version gate。
- 結論:兩平台都必須 app 端有程式。RC gate 是跨雙平台、owner 可遠端控制的乾淨解。

## OCR 姓名修法已進 package,但 app 還沒吃到(⚠️ 發版必做)
**狀態(2026-10-12):** OCR 姓名 vs title 修法(email↔name 覆蓋度雙向比對 + 擴充 title 詞庫/縮寫
SRE/FDE/… + Microsoft Joanne Tsai 回歸測試,47→56 測試)已 commit + push 到 **sibling repo
`SecBizCard` main = commit `97e45a5`**。但**尚未到使用者手上**。

**為什麼:** app `pubspec.yaml` 用 **git dependency + pin 到特定 commit**(刻意設計,鎖定每版 OCR):
```
SecBizCard_OCR:
  git: { url: ..., path: packages/SecBizCard_OCR, ref: 1def446d9e03bc36598481617d18196ad0717fc7 }
```
目前 ref 還 pin 在**舊 commit `1def446`**。

**⚠️ 發下一個 app 版本(1.6.5)時必做,否則「以為修了但 app 還用舊 parser」:**
1. 把 pubspec.yaml 的 `ref:` 從 `1def446...` 更新成 **`97e45a5`**(或屆時 OCR package 的最新 main commit)。
2. `fvm flutter pub get` 更新 pubspec.lock。
3. build + 驗證姓名解析(可跑 app 的相關測試)。
這一步跟 1.6.5 的其他改動(問題 1 precrop fallback 存檔、強更 version gate 若一起做)一起發。

## 問題 1 — precrop fallback 存整張原圖 → ✅ 已修(commit `8850b76`,本地 main 未 push)
投資報告:`.agents/tasks/investigate-ocr-precrop-name/findings.md`。
**已實作(2026-10-12,commit `8850b76` 在 SecBizCard-Apps 本地 main,未 push、未發版):**
降級順序改成 **STATE 3(偵測邊緣)→ STATE 2(導引框+20%,photo 座標)→ STATE 1(整張,極端才用)**。
STATE 2 現在是 OCR 輸入 + 存檔原圖(同一張),不再 fallback 到整張。20% = Remote Config tunable
`fallbackGuideMarginRatio`(default 0.20,可免發版調)。手動裁切改以 STATE 2 為基準(不再 80% 鬆框)。
動了 Android OpenCVProcessor.kt / iOS AppDelegate.swift+CardScoring.swift / Dart
scan_card_screen.dart+manual_crop_screen.dart+scan_guide_geometry.dart,+7 座標映射單元測試。
**⚠️ native 影像裁切 CI 驗不了 → 有一份 9 案例真機測試清單在
`.agents/tasks/fix-precrop-state2-fallback-2026-10-12/verification.md`,owner 發版前/後務必真機測
(尤其 iPad 橫向原生畫面這個最大回歸風險)。**
這個改動跟姓名 ref bump 一起進 1.6.5。
