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
```

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
