# Business Card Detection — Shared Geometric Scoring Spec

This document defines the **single, platform-independent scoring model** used to
pick and validate a business-card quadrilateral from candidate quadrilaterals.

Both platforms produce candidate quads with their own native detector:

- **Android**: OpenCV edge detection + contour approximation (`OpenCVProcessor.kt`)
- **iOS**: Vision `VNDetectRectanglesRequest` (`AppDelegate.swift`)

…but the **selection + validation "brain" is identical**: the same constants,
the same formulas, the same accept/reject threshold. This is what makes the two
platforms behave consistently. When changing any constant here, change it in
**both** `OpenCVProcessor.kt` and `AppDelegate.swift` and keep this file in sync.

A real business card is a rigid rectangle. Under camera capture it only ever
undergoes a **perspective projection**, so its detected outline is a **convex
quadrilateral whose four interior angles stay near 90°** and whose opposite
edges stay roughly parallel and similar in length. We exploit that.

---

## Input to the scorer

Each candidate is 4 corner points in image-pixel coordinates. The scorer also
receives an optional `guideRect` — the on-screen alignment frame (horizontal or
vertical card guide) mapped into image pixels — used as a soft prior.

## Corner ordering (both platforms)

Order corners as `[topLeft, topRight, bottomRight, bottomLeft]` (clockwise).
Ordering must be done in a consistent coordinate space per platform; the scoring
below assumes this clockwise ordering.

**Algorithm (centroid polar sort, default since the `useCentroidCornerSort`
flag).** Sort the four points by their polar angle (`atan2(y - cy, x - cx)`)
about the centroid to form a stable clockwise ring in TOP-LEFT origin space,
then start at the corner in the centroid's upper-left quadrant (`x < cx && y <
cy`) and walk clockwise → TL, TR, BR, BL. This is stable under in-plane rotation
(a card tilted to avoid glare). If no point is in the upper-left quadrant
(near-square or extreme tilt), it falls back to the smallest `x + y` as the
start; final orientation is then resolved by the downstream `isVertical` +
aspect-ratio 90° correction, per the Horizontal/Vertical guide contract.

The **legacy** ordering ("x + y min = top-left") is retained behind the flag for
emergency rollback; it mislabels corners on tilted cards, producing a
warped/flipped result. Both platforms implement both paths identically
(`OpenCVProcessor.sortPoints` / `CardScoring.sortPoints`).

## Geometric metrics

For quad corners `p0=TL, p1=TR, p2=BR, p3=BL`:

- **Edges**: `top=p1-p0`, `right=p2-p1`, `bottom=p2-p3`, `left=p3-p0`
- **Interior angle** at each corner = angle between its two adjacent edges.
- **Convexity**: cross-products of consecutive edge vectors all share one sign.

## Constants (MUST match on both platforms)

```
CARD_ASPECT_RATIO      = 1.586   // ISO 7810 ID-1 (85.6 × 54 mm)
ANGLE_IDEAL_DEG        = 90.0
ANGLE_TOLERANCE_DEG    = 35.0    // acceptable deviation per corner (55°–125°)
MIN_AREA_RATIO         = 0.10    // quad area / image area lower bound
MAX_AREA_RATIO         = 0.99
PARALLEL_TOLERANCE_DEG = 25.0    // opposite-edge direction difference
MIN_ACCEPT_SCORE       = 0.55    // below this -> fall back to manual crop

// Weights (sum = 1.0)
W_ANGLE      = 0.40   // how close the four corners are to 90°
W_PARALLEL   = 0.20   // opposite edges parallel + similar length
W_ASPECT     = 0.15   // closeness to card aspect ratio
W_AREA       = 0.10   // sensible fill of the frame
W_GUIDE      = 0.15   // overlap / alignment with the guide frame prior

// Edge-detection thresholds (Android collectCandidates strategies A & B)
CANNY_LOW_A  = 75.0    CANNY_HIGH_A = 200.0
CANNY_LOW_B  = 30.0    CANNY_HIGH_B = 120.0
```

## Remote Config (tuning without a release)

The constants above are **built-in defaults**. They are also externalized to
**Firebase Remote Config** so they can be tuned from the console without
shipping a new app build. This is "route A": Dart reads Remote Config
(`lib/features/contacts/data/card_detection_config.dart`), packs the values into
a `tuning` map, and passes it into the native `processCard` / `manualCrop`
method-channel calls. Both platforms read the SAME keys, which also keeps
Android and iOS in lockstep.

Rules:
- **Restart-to-apply.** `minimumFetchInterval` is 24 h; a value set in the
  console is activated on a subsequent launch, not mid-session.
- **Defaults are authoritative offline.** Until a fetch activates (and on any
  error), the in-app defaults — which MUST equal the constants above — are used.
- **Native always falls back per-key.** If the `tuning` map is absent or a key
  is missing, the native built-in constant is used, so behavior is identical to
  the shipped build.
- **Values are range-clamped in Dart.** Out-of-range console values are ignored
  in favor of the default (a console typo cannot break field detection).

Remote Config keys (double unless noted):
```
minAcceptScore, wAngle, wParallel, wAspect, wArea, wGuide,
angleToleranceDeg, parallelToleranceDeg, cardAspectRatio,
minAreaRatio, maxAreaRatio,
cannyLowA, cannyHighA, cannyLowB, cannyHighB

// Gradual-rollout flag (bool)
useCentroidCornerSort    // default TRUE: centroid+atan2 corner sort (see below).
                         // Flip false to roll back to the legacy x+y sort.
```

When changing a default here, change it in BOTH `OpenCVProcessor.kt` (`object S`)
and `CardScoring.swift` (`static let`) AND in `CardDetectionConfig._defaults`.

## Implemented / future work

1. **`useCentroidCornerSort` — DONE, default ON.** Fixes the tilted-card corner
   mislabeling (warped/flipped result) using the centroid polar sort described
   under "Corner ordering". The flag defaults ON (new correct behavior) and can
   be flipped OFF from the console to roll back to the legacy x+y sort without a
   release. Assumption we rely on: the user places the card in the correct
   orientation and picks the matching guide (Horizontal/Vertical), so
   `isVertical` is trusted ground truth and we only need to handle mild
   perspective tilt — NOT 180° flips or free rotation.
2. **Contrast / illumination preprocessing (CLAHE) — NOT pursued.** Considered
   for low-contrast backgrounds and uneven lighting from angled shots. Dropped
   for now because it has **no equivalent on iOS**: Android runs its own OpenCV
   edge detection (so a CLAHE pass could add an edge-map candidate source), but
   iOS uses Apple Vision's `VNDetectRectanglesRequest`, a black box that can't
   consume a custom preprocessed edge map. Adding it Android-only would break
   the "both platforms behave identically" invariant this spec is built on, so
   it was removed rather than shipped one-sided. Revisit only if an iOS-equivalent
   approach is found.
3. **Square / special-shape cards.** Rare. Current model handles them via the
   fallback (low aspect score is outweighed by angle/parallel/guide, and truly
   non-rectangular outlines fall through to manual crop). Deliberately NOT
   special-cased to avoid adding main-flow complexity for a small minority.

## Sub-scores (each normalized to 0..1)

1. **Convexity gate (hard)**: non-convex quad → score 0, rejected outright.

2. **Angle score** `sAngle`:
   ```
   for each corner: dev_i = |interiorAngle_i - 90|
   if any dev_i > ANGLE_TOLERANCE_DEG -> sAngle = 0 (reject-ish)
   else sAngle = 1 - (mean(dev_i) / ANGLE_TOLERANCE_DEG)
   ```

3. **Parallel score** `sParallel`:
   ```
   dTopBottom = angleBetween(top, bottom)      // degrees, 0 = parallel
   dLeftRight = angleBetween(left, right)
   penalty    = (dTopBottom + dLeftRight) / (2 * PARALLEL_TOLERANCE_DEG)
   lenRatioTB = min(|top|,|bottom|)/max(|top|,|bottom|)
   lenRatioLR = min(|left|,|right|)/max(|left|,|right|)
   sParallel  = clamp01((1 - penalty)) * ((lenRatioTB + lenRatioLR)/2)
   ```

4. **Aspect score** `sAspect`:
   ```
   w = (|top| + |bottom|) / 2
   h = (|left| + |right|) / 2
   ar = max(w,h) / min(w,h)               // orientation-independent
   sAspect = clamp01(1 - |ar - CARD_ASPECT_RATIO| / CARD_ASPECT_RATIO)
   ```

5. **Area score** `sArea`:
   ```
   r = quadArea / imageArea
   if r < MIN_AREA_RATIO or r > MAX_AREA_RATIO -> sArea = 0
   else sArea = 1 (fills frame reasonably)
   ```

6. **Guide score** `sGuide` (skip if no guideRect; renormalize weights):
   ```
   sGuide = IoU(quadBoundingBox, guideRect)   // 0..1 intersection-over-union
   ```

## Final score

```
score = W_ANGLE*sAngle + W_PARALLEL*sParallel + W_ASPECT*sAspect
      + W_AREA*sArea + W_GUIDE*sGuide
```
If `guideRect` is absent, drop `W_GUIDE` and renormalize the remaining weights
so they sum to 1.0.

## Selection

- Score every candidate; pick the highest.
- If best score `>= MIN_ACCEPT_SCORE` → perspective-correct using that quad.
- Otherwise → **fall back to the guide-frame region** (not the whole image) as
  the initial crop and hand off to the manual 4-corner adjuster.

---

## Tuning strategy: what's a Remote-Config value vs. what needs a release

This project has two "scorers" — the **geometric card-detection** scorer above,
and the **OCR text-field** scorer in the private `SecBizCard_OCR` package
(`_scoreName`, etc.). Both raise the same recurring question: *"can this be
tuned from the cloud, or does it need an app release?"* The answer follows a
strict three-layer split. Keep it in mind before changing scoring code.

### Layer 1 — Parameters / thresholds → Remote Config (hot-tunable, NO release)
Numeric **weights and thresholds** live in `CardDetectionConfig` and are
overridable from Firebase Remote Config, validated against a plausible range.
Examples: geometry weights (`wAngle`…), `minAcceptScore`, the feedback-predictor
thresholds (`poorNameScoreBelow`, `poorCoverageBelow`, `poorDetectionScoreBelow`),
and OCR scorer weights such as `pureTitleNamePenalty`. Changing the *value* of an
existing knob is a console change, not a release.

OCR scorer weights reach the package via `SecBizCardOcr.parseLines(tuning: {...})`
(the app builds that map from `CardDetectionConfig`). Only weights whose **rule
already exists** in the package can be tuned this way.

### Layer 2 — Recognition RULES → code, needs a release (unavoidable)
A **new rule** — a new disqualifier, a new signal, a new pattern — is logic, not
a value. Remote Config cannot add "detect a pure job-title line" or "penalize a
social CTA"; it can only tune the weight *after* the rule ships. So the FIRST
time a new misread pattern is handled, it goes in a release. This is inherent to
any OCR system: business-card layouts are endless, and new misread patterns can
only be met with new rules. Cloud config tunes sensitivity; it never teaches a
new recognition behavior.

**Corollary:** when you add a new rule, also expose its weight as a Layer-1
config value (with a sensible hardcoded default as the fallback), so future
sensitivity tweaks of that rule DON'T need another release. That's how
`pureTitleNamePenalty` was added (default −120, tunable thereafter).

### Layer 3 — Safety net: regression tests + a pinned OCR dependency
- **Every rule change ships with a regression test** (see the OCR package's
  `parsing_test.dart`, e.g. the AWS-CTA and Kantar pure-title cases). The
  accumulating suite is what makes "add a new rule" low-risk — it proves old
  cards still parse correctly.
- **The app pins the `SecBizCard_OCR` git dependency to an explicit ref**, so a
  given app version is locked to a known OCR version and a rebuild can't drift
  onto a newer parser. Bump the ref deliberately when you want the new OCR.

### Quick decision guide
- "Make it slightly more/less aggressive" → Layer 1, Remote Config, no release.
- "It misreads a NEW kind of line" → Layer 2, new rule + test + release; expose
  its weight as Layer 1 while you're there.
- Never chase a Play Console optimization score by loosening a rule; correctness
  and the regression suite come first.


---

## 未來評估:名片簿 / 多卡同框(multi-card in one frame)

**狀態:已知問題,暫緩處理。目前只用掃描畫面的引導提示緩解(`scanCardSingleTip`
「一次辨識一張名片」)。** OCR 設計上就是「一次一張」,以下為日後若要真正處理時的
背景與方向。

### 觀察到的實例(2026-09-27,OCR feedback)
使用者對著**名片簿透明頁**拍照,一次框到三張名片(飛瑞 / 工研院 / acer),彼此
排列整齊又隔著反光膜。結果:

- OpenCV / Vision 的單卡邊緣偵測**找不到清楚的單張卡邊界 → 判定 fallback →
  改用整張影像送 OCR**。
- 三張卡的文字全進 parser,`parseLines` 是「文字袋」模型(僅用 box 高度做名字
  prominence、用 top 排序電話,不做空間區域過濾),於是拼出**跨卡的錯誤結果**:
  name 取自第 2 張、title/company 取自第 3 張、email 取自第 1 張。
- `detectionScore` 0.90、`detectionFallback:false` → 信心分數還很高,使用者不會
  被警告。這是「高信心但錯」的危險情況。

### 為什麼「用瞄準框過濾框外文字」現在做不到(調查結論)
1. **座標系對不上**:瞄準框(`_normalizedGuideRect`)是螢幕/預覽座標;OCR 的 box
   是「OCR 輸入影像」像素座標,而該影像是相機全解析度照片經 OpenCV 透視校正裁切
   +可能旋轉後的產物。中間**沒有保存 預覽→影像 的轉換**,校正後瞄準框在輸出影像
   裡失去意義。
2. **shared-key 路徑的 box x/y 實際是 0**:後端 `recognizeCard` 未回傳位置,
   client `?? 0` 補零(見 `cloud_vision_recognizer.dart` `recognizeWithSharedKey`)。
   多數使用者走 shared-key,位置資訊根本不存在。own-key Vision 與 ML Kit 內部
   有真實 x/y,但 ML Kit 的 rawOcrLines 在離開 `ocr_service.dart` 前被丟棄。

### 日後若要處理的候選方向(依成本)
- **A(推薦・需碰 native):偵測失敗時,退回「裁切到瞄準框」而非「整張影像」。**
  在原始影像上用 guideRect 硬裁一刀再送 OCR,幾何上強制只留框內那張,繞開座標系/
  後端/ML Kit 三個坑。要改 Android `OpenCVProcessor.kt` 的 fallback 分支,iOS 端
  (`AppDelegate.swift` Vision)對應補上。
- **B(純 Dart・輕):多卡防呆提示。** OCR 後若出現多卡訊號(≥2 個 email、≥2 個
  統一編號、≥2 個公司名),不硬給結果,改提示「偵測到多張名片,請對準單張重拍」。
  治標,但擋掉「高信心卻錯」。
- **C(重):真多卡切割** —— 偵測 N 張卡 → 各自 crop → 產出 N 筆聯絡人。體驗最好、
  工程最重。目前明確不做。

負責線:sbc-card-ocr(偵測/裁切)+ sbc-flutter-mobile(native)。

---

## 已排程 1.6.3:瞄準框 +25% 預裁切(方向 A 的強化版)

**狀態:已完成可行性診斷,排入 1.6.3(不進 1.6.2;1.6.2 收斂送審)。**
完整診斷報告:`.agents/tasks/precrop-investigation/findings.md`。

### 構想
送進偵測前,先把拍攝照片裁切到「瞄準框向外擴 25%」的區域,再跑現有 OpenCV/Vision
偵測。使用者本來就把名片對進框裡,預裁切能先砍掉框外雜訊(桌面、花紋、其他卡),
讓邊緣偵測在單純背景下更容易鎖定單張卡。是上面「方向 A」的強化版(在**偵測前**裁,
而非只在偵測失敗 fallback 時裁)。

### 硬前提(必須先解,否則裁歪)
瞄準框是**整個螢幕**的 normalized 座標,但預覽是相機畫面的 **cover-crop**——螢幕上
看到的是感光元件畫面的放大子區域。所以「螢幕 85% 寬的框」≠「照片 85% 寬」,兩者差一個
cover-crop 的縮放/偏移,而這個轉換**目前沒被計算或儲存**。native 現在是直接把 normalized
rect 乘上全圖寬高(`OpenCVProcessor.kt` guide 區塊、`AppDelegate.swift` guidePixelRect),
已有潛在誤差——目前只因 guide 是**軟性 IoU prior(W_GUIDE 0.15)**才沒出事。一旦升級成
**硬裁切**,誤差會把名片裁掉一部分。

### 建議實作(native,非 Dart)
native 已收到 guideRect + 知道真實 EXIF 校正後的照片像素,是唯一能裁對的地方。
- **Dart**(`scan_card_screen.dart` `_processWithOpenCV` / `_normalizedGuideRect`):
  補送 cover-crop 幾何(預覽 aspect、cover vs letterbox、isLargeScreen),讓 native
  能把「螢幕座標 guide」換算成「照片座標 guide」。用 `card_detection_config.dart` 加一個
  可遠端開關的 flag + margin(預設 0.25)。
- **Android**(`OpenCVProcessor.kt` `processBusinessCard`):算出 guide→像素 → 外擴 25%
  → clamp 到影像邊界 → 在該 ROI 跑偵測 → ROI 角點換算回全圖座標。
- **iOS**(`AppDelegate.swift` `processImage`):baked 方向後,guidePixelRect 外擴 25% +
  clamp → `CIImage.cropped(to:)` → 在 crop 上跑 Vision → 偵測點加回 crop 原點。
- 評分模型不動(`CardScoring.swift` / `object S` 常數維持)。

### 必備 fallback(防 regression)
兩階段:(1) 先在 guide+25% ROI 偵測 →(2) 分數不過 `minAcceptScore` 就**退回全圖偵測**
(現狀 code path)→(3) 再退回 guide 區域手動裁切。保證「只會更好或持平,絕不 regression」。
預裁切是**多一次 first attempt**,不是取代。整個行為用 Remote Config flag 包起來可隨時關。

### 風險(各 form factor 都要真機驗)
cover-crop 誤差在 tablet/foldable(預覽與螢幕 aspect 差很多)可能較大;25% margin 緩解但
無法完全吸收。horizontal/vertical + phone/large-screen 各變體的 guide 不同,預裁切要用
使用者當下選的變體。使用者沒對準 → 卡片部分落在 ROI 外 → 靠全圖 fallback 接住。

負責線:sbc-flutter-mobile(Android Kotlin + iOS Swift native)+ sbc-card-ocr(偵測調校)。
