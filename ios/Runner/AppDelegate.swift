import UIKit
import Flutter
import Vision
import CoreImage
import ImageIO

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = self.window?.rootViewController as? FlutterViewController {
        let channel = FlutterMethodChannel(name: "app.ixo.secbizcard/opencv",
                                          binaryMessenger: controller.binaryMessenger)
        
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
            // Execute on background thread to avoid blocking UI
            DispatchQueue.global(qos: .userInitiated).async {
                self.processImage(inputPath: inputPath, outputPath: outputPath, isVertical: isVertical, guideRect: guideRect, result: result)
            }
          } else {
            result(FlutterMethodNotImplemented)
          }
        })
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Shared CIContext to avoid initialization lag during capture
  private static let sharedContext = CIContext(options: [
    .useSoftwareRenderer: false,
    .highQualityDownsample: false
  ])

  private func processImage(inputPath: String, outputPath: String, isVertical: Bool, guideRect: [String: Double]?, result: @escaping FlutterResult) {
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

    let handler = VNImageRequestHandler(ciImage: bakedImage, options: [:])
    let request = VNDetectRectanglesRequest { (req, err) in
        if let err = err {
            print("Vision Error: \(err)")
            DispatchQueue.main.async { result(["success": false]) }
            return
        }

        let imgArea = Double(imgW * imgH)

        // Vision normalized coords: (0,0) = bottom-left, Y up.
        // Convert to pixel coords with a TOP-LEFT origin so the geometry
        // matches Android's coordinate space (and the guide rect).
        func toPixelTL(_ pt: CGPoint) -> CGPoint {
            return CGPoint(x: pt.x * imgW, y: (1.0 - pt.y) * imgH)
        }

        // Gather all candidate quads and score them with the SHARED model
        // (mirror of OpenCVProcessor.kt / docs/card_detection_scoring.md).
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
            let quad = CardScoring.sortPoints(raw)
            let score = CardScoring.scoreQuad(quad, imgArea: imgArea, guide: guidePixelRect)
            if score > bestScore {
                bestScore = score
                bestQuad = quad
            }
        }

        guard let winner = bestQuad, bestScore >= CardScoring.minAcceptScore else {
            // Fallback: hand off the GUIDE region (not whole image) to manual crop.
            // Points are returned in TOP-LEFT origin pixels to match Android.
            let pts: [Double]
            if let g = guidePixelRect {
                pts = [
                    Double(g.minX), Double(g.minY),
                    Double(g.maxX), Double(g.minY),
                    Double(g.maxX), Double(g.maxY),
                    Double(g.minX), Double(g.maxY),
                ]
            } else {
                pts = [0.0, 0.0, imgW, 0.0, imgW, imgH, 0.0, imgH]
            }
            DispatchQueue.main.async {
                result([
                    "success": true,
                    "fallback": true,
                    "score": bestScore,
                    "imageWidth": Int(imgW),
                    "imageHeight": Int(imgH),
                    "points": pts,
                ])
            }
            return
        }

        // winner corners are TL,TR,BR,BL in TOP-LEFT origin. Convert back to
        // CoreImage's BOTTOM-LEFT origin for CIPerspectiveCorrection.
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
        guard let correctedCG = ctx.createCGImage(corrected, from: corrected.extent) else {
            DispatchQueue.main.async { result(["success": false]) }
            return
        }
        var finalImage = UIImage(cgImage: correctedCG)
        
        // ============================================================
        // STEP 5: Orientation Correction (matches Android exactly)
        // ============================================================
        // Android logic (OpenCVProcessor.kt lines 140-151):
        //   if (isVertical && cols > rows) rotate 90 CW
        //   if (!isVertical && rows > cols) rotate 90 CW
        
        let w = finalImage.size.width
        let h = finalImage.size.height
        
        if isVertical && w > h {
            // Card is landscape but user wants vertical → rotate 90° CW
            finalImage = self.rotateUIImage90CW(finalImage)
        } else if !isVertical && h > w {
            // Card is portrait but user wants horizontal → rotate 90° CW
            finalImage = self.rotateUIImage90CW(finalImage)
        }
        
        // ============================================================
        // STEP 6: Image Enhancement (matches Android's enhanceImage)
        // ============================================================
        // Android: contrast 1.2, brightness +10
        // CIFilter: brightness range is 0-1, so +10/255 ≈ 0.04
        let finalCG = finalImage.cgImage!
        let enhancedCI = CIImage(cgImage: finalCG)
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 1.2,
                kCIInputBrightnessKey: 0.04,
            ])
        
        guard let enhancedCG = ctx.createCGImage(enhancedCI, from: enhancedCI.extent) else {
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
                DispatchQueue.main.async { result(["success": true]) }
            } catch {
                print("Save Error: \(error)")
                DispatchQueue.main.async { result(["success": false]) }
            }
        } else {
            DispatchQueue.main.async { result(["success": false]) }
        }
    }
    
    // Configure Vision to PRODUCE CANDIDATES only; the shared CardScoring model
    // does the real selection/validation. Thresholds are intentionally loose
    // and maximumObservations high so we get several quads to score.
    request.minimumConfidence = 0.3
    request.minimumAspectRatio = 0.3
    request.minimumSize = 0.15
    request.quadratureTolerance = 45.0
    request.maximumObservations = 8
    
    do {
        try handler.perform([request])
    } catch {
        print("Handler Error: \(error)")
        DispatchQueue.main.async { result(["success": false]) }
    }
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
