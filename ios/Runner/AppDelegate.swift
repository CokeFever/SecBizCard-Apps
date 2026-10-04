import UIKit
import Flutter
import Vision
import CoreImage
import ImageIO

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // With the UIScene lifecycle (iOS 27+), the implicit FlutterEngine is
  // initialized after `didFinishLaunchingWithOptions:` returns, so plugin
  // registration and method-channel setup must happen here instead.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "app.ixo.secbizcard/opencv",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )

    channel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if (call.method == "processCard") {
        guard let args = call.arguments as? [String: Any],
              let inputPath = args["inputPath"] as? String,
              let outputPath = args["outputPath"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing paths", details: nil))
          return
        }
        let isVertical = args["isVertical"] as? Bool ?? false
        let guideRect = args["guideRect"] as? [String: Double]
        // NEW: cover-crop-corrected image-normalized rect (hard pre-crop) +
        // orientation-free sensor ratio (aspect-divergence guard). Both nullable
        // / additive; absent => stage 1 / the guard are skipped.
        let imageGuideRect = args["imageGuideRect"] as? [String: Double]
        let previewAspectUsed = args["previewAspectUsed"] as? Double
        // Remote-tunable detection params (route A). Absent/empty => built-in.
        let tuning = CardScoring.CardTuning(map: args["tuning"] as? [String: Any])
        // Execute on background thread to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            self.processImage(inputPath: inputPath, outputPath: outputPath, isVertical: isVertical, guideRect: guideRect, imageGuideRect: imageGuideRect, previewAspectUsed: previewAspectUsed, tuning: tuning, result: result)
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
  }

  // Shared CIContext to avoid initialization lag during capture
  private static let sharedContext = CIContext(options: [
    .useSoftwareRenderer: false,
    .highQualityDownsample: false
  ])

  private func processImage(inputPath: String, outputPath: String, isVertical: Bool, guideRect: [String: Double]?, imageGuideRect: [String: Double]?, previewAspectUsed: Double?, tuning: CardScoring.CardTuning, result: @escaping FlutterResult) {
    let url = URL(fileURLWithPath: inputPath)
    guard let ciImage = CIImage(contentsOf: url) else {
         DispatchQueue.main.async { result(["success": false]) }
         return
    }
    
    // ============================================================
    // STEP 1: Bake EXIF orientation into ACTUAL PIXELS
    // ============================================================
    // This is the critical fix. CIImage.oriented() only sets a virtual
    // transform, but CIPerspectiveCorrection reads RAW pixels.
    // We must render the oriented pixels to a CGImage first,
    // exactly like Android's loadMatWithExif() physically rotates pixels.
    
    var orientedCI = ciImage
    if let orientVal = ciImage.properties[kCGImagePropertyOrientation as String] {
        let rawVal: UInt32
        if let i32 = orientVal as? Int32 { rawVal = UInt32(i32) }
        else if let u32 = orientVal as? UInt32 { rawVal = u32 }
        else if let i = orientVal as? Int { rawVal = UInt32(i) }
        else { rawVal = 1 }
        
        if let cgOri = CGImagePropertyOrientation(rawValue: rawVal) {
            orientedCI = ciImage.oriented(cgOri)
        }
    }
    
    // Render to CGImage → new CIImage with baked pixels (no virtual transform)
    let ctx = AppDelegate.sharedContext
    guard let cgImage = ctx.createCGImage(orientedCI, from: orientedCI.extent) else {
        DispatchQueue.main.async { result(["success": false]) }
        return
    }
    let bakedImage = CIImage(cgImage: cgImage)
    
    let imgW = bakedImage.extent.width
    let imgH = bakedImage.extent.height

    // Capture detection area ONCE (NIT-2): scoring uses the FULL image area in
    // BOTH stages so the guide-IoU prior and areaRatio stay in today's frame.
    let fullArea = Double(imgW * imgH)

    // Capture/preview aspect-divergence guard (capture-aspect guard). The Dart
    // transform assumes the captured photo's aspect equals the orientation-free
    // sensor ratio it sent as previewAspectUsed. Both sides are orientation-
    // free (max/min), so compare directly; a divergence is logged once and
    // surfaced on EVERY result map. The 25% margin + full-image fallback bound
    // the worst case to "no worse than today" even when it diverges.
    var aspectMismatch = false
    if let preview = previewAspectUsed, imgW > 0, imgH > 0 {
        let captureAspect = Double(max(imgW, imgH) / min(imgW, imgH))
        if abs(captureAspect - preview) > 0.02 {
            print("precrop: capture/preview aspect divergence capture=\(captureAspect) preview=\(preview)")
            aspectMismatch = true
        }
    }

    // ============================================================
    // STEP 2: Detect rectangle on the baked (upright) image
    // ============================================================
    // Guide rect (normalized 0..1) mapped into pixel space, top-left origin,
    // for the shared scoring model's guide prior.
    let guidePixelRect: CGRect? = guideRect.map { g in
        let l = (g["left"] ?? 0) * imgW
        let t = (g["top"] ?? 0) * imgH
        let w = (g["width"] ?? 0) * imgW
        let h = (g["height"] ?? 0) * imgH
        return CGRect(x: l, y: t, width: w, height: h)
    }

    let ctxLocal = ctx

    // ------------------------------------------------------------
    // detectBest: run VNDetectRectanglesRequest on `image` (a re-origined crop
    // in stage 1, or the full baked image in stage 2) and score the candidates.
    // Vision points are normalized to `image.extent.size` (the HANDED image),
    // bottom-left origin — so we scale by THAT size (not full imgW/imgH) and add
    // `offset` (TL-origin, full-image pixels) to lift the quad into full-image
    // TOP-LEFT coords. Scoring uses guidePixelRect + the FULL `fullArea`, so the
    // scoring frame is identical in both stages.
    //
    // OPTION (a): the completion reports `visionErrored` DISTINCTLY from a
    // zero-candidate / low-score result. visionErrored == true ONLY on request
    // err != nil OR handler.perform throwing — NEVER reused to mean "no
    // candidate". The orchestration below depends on this distinction.
    func detectBest(on image: CIImage, offset: CGPoint,
                    completion: @escaping ([CGPoint]?, Double, Bool) -> Void) {
        let cw = image.extent.width   // crop size (stage 1) / full imgW (stage 2)
        let ch = image.extent.height
        func toPixelTL(_ pt: CGPoint) -> CGPoint {
            // pt in [0,1] over the handed image; (1 - pt.y) flips BL→TL; + offset
            // lifts into full-image TL space. Stage 2 passes offset == .zero and
            // (cw,ch) == (imgW,imgH), so this reduces to the baseline formula.
            return CGPoint(x: pt.x * cw + offset.x, y: (1.0 - pt.y) * ch + offset.y)
        }
        let request = VNDetectRectanglesRequest { (req, err) in
            if let err = err {
                print("Vision Error: \(err)")
                completion(nil, 0, true)   // visionErrored = true (OPTION a)
                return
            }
            let observations = (req.results as? [VNRectangleObservation]) ?? []
            var bestQuad: [CGPoint]? = nil
            var bestScore = 0.0
            for obs in observations {
                let raw = [
                    toPixelTL(obs.topLeft),
                    toPixelTL(obs.topRight),
                    toPixelTL(obs.bottomRight),
                    toPixelTL(obs.bottomLeft),
                ]
                let quad = CardScoring.sortPoints(raw, useCentroid: tuning.useCentroidCornerSort)
                let score = CardScoring.scoreQuad(quad, imgArea: fullArea, guide: guidePixelRect, tuning: tuning)
                if score > bestScore {
                    bestScore = score
                    bestQuad = quad
                }
            }
            completion(bestQuad, bestScore, false) // normal result, not an error
        }
        // Thresholds reused VERBATIM in both stages (do NOT rescale per stage —
        // minimumSize is a fraction of the handed image's smaller dimension, so
        // on the crop it is a smaller absolute size, which is intentional).
        request.minimumConfidence = 0.3
        request.minimumAspectRatio = 0.3
        request.minimumSize = 0.15
        request.quadratureTolerance = 45.0
        request.maximumObservations = 8
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Handler Error: \(error)")
            completion(nil, 0, true)   // visionErrored = true (OPTION a)
        }
    }

    // ------------------------------------------------------------
    // finish: accept the winning quad — the EXISTING warp / orient / enhance /
    // save pipeline, UNCHANGED. winner corners are TL,TR,BR,BL (TOP-LEFT origin,
    // full-image). Perspective correction runs on the FULL bakedImage.
    func finish(winner: [CGPoint], score: Double) {
        func toBottomLeft(_ p: CGPoint) -> CGPoint {
            return CGPoint(x: p.x, y: imgH - p.y)
        }
        let tl = toBottomLeft(winner[0])
        let tr = toBottomLeft(winner[1])
        let br = toBottomLeft(winner[2])
        let bl = toBottomLeft(winner[3])

        // ============================================================
        // STEP 4: Perspective Correction
        // ============================================================
        let filter = CIFilter(name: "CIPerspectiveCorrection")!
        filter.setValue(bakedImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: tl), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: tr), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: br), forKey: "inputBottomRight")
        filter.setValue(CIVector(cgPoint: bl), forKey: "inputBottomLeft")

        guard let corrected = filter.outputImage else {
            DispatchQueue.main.async { result(["success": false]) }
            return
        }

        // Render the corrected image to bake its pixels too
        guard let correctedCG = ctxLocal.createCGImage(corrected, from: corrected.extent) else {
            DispatchQueue.main.async { result(["success": false]) }
            return
        }
        var finalImage = UIImage(cgImage: correctedCG)

        // ============================================================
        // STEP 5: Orientation Correction (matches Android exactly)
        // ============================================================
        // Android logic (OpenCVProcessor.kt):
        //   if (isVertical && cols > rows) rotate 90 CW
        //   if (!isVertical && rows > cols) rotate 90 CW
        let w = finalImage.size.width
        let h = finalImage.size.height

        if isVertical && w > h {
            finalImage = self.rotateUIImage90CW(finalImage)
        } else if !isVertical && h > w {
            finalImage = self.rotateUIImage90CW(finalImage)
        }

        // ============================================================
        // STEP 6: Image Enhancement (matches Android's enhanceImage)
        // ============================================================
        let finalCG = finalImage.cgImage!
        let enhancedCI = CIImage(cgImage: finalCG)
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 1.2,
                kCIInputBrightnessKey: 0.04,
            ])

        guard let enhancedCG = ctxLocal.createCGImage(enhancedCI, from: enhancedCI.extent) else {
            DispatchQueue.main.async { result(["success": false]) }
            return
        }
        let enhancedImage = UIImage(cgImage: enhancedCG)

        // ============================================================
        // STEP 7: Save as JPEG
        // ============================================================
        if let jpegData = enhancedImage.jpegData(compressionQuality: 0.9) {
            do {
                try jpegData.write(to: URL(fileURLWithPath: outputPath))
                let areaRatio = fullArea > 0 ? CardScoring.polygonArea(winner) / fullArea : 0.0
                let pts: [Double] = [
                    Double(winner[0].x), Double(winner[0].y),
                    Double(winner[1].x), Double(winner[1].y),
                    Double(winner[2].x), Double(winner[2].y),
                    Double(winner[3].x), Double(winner[3].y),
                ]
                DispatchQueue.main.async {
                    result([
                        "success": true,
                        "fallback": false,
                        "aspectMismatch": aspectMismatch,
                        "score": score,
                        "areaRatio": areaRatio,
                        "imageWidth": Int(imgW),
                        "imageHeight": Int(imgH),
                        "points": pts,
                    ])
                }
            } catch {
                print("Save Error: \(error)")
                DispatchQueue.main.async { result(["success": false]) }
            }
        } else {
            DispatchQueue.main.async { result(["success": false]) }
        }
    }

    // ------------------------------------------------------------
    // emitGuideFallback: genuine zero-candidate / low-score → hand the GUIDE
    // region (not the whole image) to the manual 4-corner adjuster, exactly as
    // today. Reserved for a real miss — NOT for Vision errors (OPTION a).
    func emitGuideFallback(score: Double) {
        let pts: [Double]
        if let g = guidePixelRect {
            pts = [
                Double(g.minX), Double(g.minY),
                Double(g.maxX), Double(g.minY),
                Double(g.maxX), Double(g.maxY),
                Double(g.minX), Double(g.maxY),
            ]
        } else {
            pts = [0.0, 0.0, Double(imgW), 0.0, Double(imgW), Double(imgH), 0.0, Double(imgH)]
        }
        DispatchQueue.main.async {
            result([
                "success": true,
                "fallback": true,
                "aspectMismatch": aspectMismatch,
                "score": score,
                "areaRatio": 0.0, // no card detected
                "imageWidth": Int(imgW),
                "imageHeight": Int(imgH),
                "points": pts,
            ])
        }
    }

    // ------------------------------------------------------------
    // STAGE 2: full-image detection. Carries the stage-1 best (if any) so the
    // higher-scoring of the two wins. Vision error on stage 2 with NO stage-1
    // winner returns success:false EXACTLY as today (→ Dart throws → original
    // image used); do NOT emit fallback:true for that error.
    func runStage2(previousBest: ([CGPoint]?, Double)) {
        detectBest(on: bakedImage, offset: .zero) { q2, s2, errored2 in
            if errored2 && previousBest.0 == nil {
                DispatchQueue.main.async { result(["success": false]) }
                return
            }
            // Pick the higher-scoring of (previousBest, stage-2 result).
            var winner = previousBest.0
            var winScore = previousBest.1
            if let q2 = q2, s2 > winScore {
                winner = q2
                winScore = s2
            }
            if let w = winner, winScore >= tuning.minAcceptScore {
                finish(winner: w, score: winScore)
            } else {
                emitGuideFallback(score: winScore)
            }
        }
    }

    // ------------------------------------------------------------
    // STAGE 1: pre-crop ROI (guide + margin), only if enabled & a rect present
    // & the clamped ROI is non-empty.
    if tuning.usePrecrop, let ig = imageGuideRect {
        let roi = expandAndClamp(ig, extent: bakedImage.extent, margin: tuning.precropMarginRatio)
        if roi.width > 0 && roi.height > 0 {
            // CIImage is BOTTOM-LEFT origin: convert the TL ROI to CI (BL) space.
            let ciRoi = CGRect(x: roi.minX, y: imgH - roi.maxY, width: roi.width, height: roi.height)
            // cropped(to:) retains origin == ciRoi.origin; re-origin to (0,0) so
            // Vision normalizes cleanly over the crop and the lift-back offset is
            // purely explicit.
            let crop = bakedImage.cropped(to: ciRoi)
                .transformed(by: CGAffineTransform(translationX: -ciRoi.minX, y: -ciRoi.minY))
            detectBest(on: crop, offset: CGPoint(x: roi.minX, y: roi.minY)) { q, s, errored in
                if errored {
                    // Vision error on stage 1 → treat as a miss, run stage 2.
                    runStage2(previousBest: (nil, 0))
                } else if let q = q, s >= tuning.minAcceptScore {
                    finish(winner: q, score: s)   // stage-1 winner good enough
                } else {
                    runStage2(previousBest: (q, s)) // carry stage-1 best (if any)
                }
            }
        } else {
            print("precrop: empty ROI, skipping stage 1")
            runStage2(previousBest: (nil, 0))
        }
    } else {
        runStage2(previousBest: (nil, 0))
    }
  }

  /// Image-normalized rect → TL-origin pixel CGRect, expanded by `margin` on
  /// EACH side (margin * dimension) then clamped to `extent`. A degenerate rect
  /// yields a zero-size CGRect (caller skips stage 1).
  private func expandAndClamp(_ g: [String: Double], extent: CGRect, margin: Double) -> CGRect {
    let W = extent.width, H = extent.height
    let l = CGFloat(g["left"] ?? 0) * W, t = CGFloat(g["top"] ?? 0) * H
    let w = CGFloat(g["width"] ?? 0) * W, h = CGFloat(g["height"] ?? 0) * H
    let ex = w * CGFloat(margin), ey = h * CGFloat(margin)
    let x0 = max(0, l - ex), y0 = max(0, t - ey)
    let x1 = min(W, l + w + ex), y1 = min(H, t + h + ey)
    return CGRect(x: x0, y: y0, width: max(0, x1 - x0), height: max(0, y1 - y0))
  }
  
  /// Rotate a UIImage 90° clockwise (matches Android's Core.ROTATE_90_CLOCKWISE)
  private func rotateUIImage90CW(_ image: UIImage) -> UIImage {
    let size = CGSize(width: image.size.height, height: image.size.width)
    UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
    guard let context = UIGraphicsGetCurrentContext() else { return image }
    
    context.translateBy(x: size.width / 2, y: size.height / 2)
    context.rotate(by: .pi / 2)
    image.draw(in: CGRect(
        x: -image.size.width / 2,
        y: -image.size.height / 2,
        width: image.size.width,
        height: image.size.height
    ))
    
    let rotated = UIGraphicsGetImageFromCurrentImageContext() ?? image
    UIGraphicsEndImageContext()
    return rotated
  }
}
