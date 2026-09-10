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
