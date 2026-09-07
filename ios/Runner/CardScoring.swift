import CoreGraphics
import Foundation

/// Shared geometric scoring model for business-card detection.
///
/// This is a line-by-line mirror of the Kotlin implementation in
/// `android/app/src/main/kotlin/app/ixo/secbizcard/OpenCVProcessor.kt`
/// and the spec in `docs/card_detection_scoring.md`. Vision produces candidate
/// quads; this decides which one is the card and whether it's good enough.
///
/// A business card is a rigid rectangle, so under perspective it stays a convex
/// quad with near-90° corners and roughly parallel opposite edges. All points
/// are in TOP-LEFT origin pixel coordinates (matching Android).
enum CardScoring {

    // MARK: Shared constants (MUST match OpenCVProcessor.kt)
    static let cardAspectRatio = 1.586
    static let angleToleranceDeg = 35.0
    static let minAreaRatio = 0.10
    static let maxAreaRatio = 0.99
    static let parallelToleranceDeg = 25.0
    static let minAcceptScore = 0.55
    static let wAngle = 0.40
    static let wParallel = 0.20
    static let wAspect = 0.15
    static let wArea = 0.10
    static let wGuide = 0.15

    // MARK: Corner ordering — TL, TR, BR, BL (matches Android sortPoints)
    static func sortPoints(_ points: [CGPoint]) -> [CGPoint] {
        var result = [CGPoint](repeating: .zero, count: 4)
        let bySum = points.sorted { ($0.x + $0.y) < ($1.x + $1.y) }
        result[0] = bySum[0]                 // Top-left (min x+y)
        result[2] = bySum[bySum.count - 1]   // Bottom-right (max x+y)
        let remaining = [bySum[1], bySum[2]]
        let byDiff = remaining.sorted { ($0.y - $0.x) < ($1.y - $1.x) }
        result[1] = byDiff[0]                // Top-right
        result[3] = byDiff[1]                // Bottom-left
        return result
    }

    // MARK: Full score for a candidate quad (corners TL,TR,BR,BL).
    static func scoreQuad(_ quad: [CGPoint], imgArea: Double, guide: CGRect?) -> Double {
        guard quad.count == 4 else { return 0 }
        if !isConvex(quad) { return 0 }

        let sAngle = angleScore(quad)
        if sAngle <= 0 { return 0 }
        let sParallel = parallelScore(quad)
        let sAspect = aspectScore(quad)
        let sArea = areaScore(quad, imgArea: imgArea)
        if sArea <= 0 { return 0 }

        if let guide = guide {
            let sGuide = iou(boundingBox(quad), guide)
            return wAngle * sAngle + wParallel * sParallel + wAspect * sAspect
                + wArea * sArea + wGuide * sGuide
        } else {
            let total = wAngle + wParallel + wAspect + wArea
            return (wAngle * sAngle + wParallel * sParallel
                + wAspect * sAspect + wArea * sArea) / total
        }
    }

    // MARK: Sub-scores
    private static func isConvex(_ q: [CGPoint]) -> Bool {
        var sign = 0
        for i in 0..<4 {
            let a = q[i]
            let b = q[(i + 1) % 4]
            let c = q[(i + 2) % 4]
            let cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)
            if cross != 0 {
                let s = cross > 0 ? 1 : -1
                if sign == 0 { sign = s } else if sign != s { return false }
            }
        }
        return true
    }

    private static func angleScore(_ q: [CGPoint]) -> Double {
        var sumDev = 0.0
        for i in 0..<4 {
            let prev = q[(i + 3) % 4]
            let cur = q[i]
            let next = q[(i + 1) % 4]
            let v1 = CGPoint(x: prev.x - cur.x, y: prev.y - cur.y)
            let v2 = CGPoint(x: next.x - cur.x, y: next.y - cur.y)
            let ang = angleBetweenDeg(v1, v2)
            let dev = abs(ang - 90.0)
            if dev > angleToleranceDeg { return 0 }
            sumDev += dev
        }
        let meanDev = sumDev / 4.0
        return clamp01(1.0 - meanDev / angleToleranceDeg)
    }

    private static func parallelScore(_ q: [CGPoint]) -> Double {
        let top = CGPoint(x: q[1].x - q[0].x, y: q[1].y - q[0].y)
        let bottom = CGPoint(x: q[2].x - q[3].x, y: q[2].y - q[3].y)
        let left = CGPoint(x: q[3].x - q[0].x, y: q[3].y - q[0].y)
        let right = CGPoint(x: q[2].x - q[1].x, y: q[2].y - q[1].y)

        let dTB = directionDiffDeg(top, bottom)
        let dLR = directionDiffDeg(left, right)
        let penalty = (dTB + dLR) / (2 * parallelToleranceDeg)

        let lenTB = ratio(len(top), len(bottom))
        let lenLR = ratio(len(left), len(right))
        return clamp01(1.0 - penalty) * ((lenTB + lenLR) / 2.0)
    }

    private static func aspectScore(_ q: [CGPoint]) -> Double {
        let top = len(CGPoint(x: q[1].x - q[0].x, y: q[1].y - q[0].y))
        let bottom = len(CGPoint(x: q[2].x - q[3].x, y: q[2].y - q[3].y))
        let left = len(CGPoint(x: q[3].x - q[0].x, y: q[3].y - q[0].y))
        let right = len(CGPoint(x: q[2].x - q[1].x, y: q[2].y - q[1].y))
        let w = (top + bottom) / 2.0
        let h = (left + right) / 2.0
        if w <= 0 || h <= 0 { return 0 }
        let ar = max(w, h) / min(w, h)
        return clamp01(1.0 - abs(ar - cardAspectRatio) / cardAspectRatio)
    }

    private static func areaScore(_ q: [CGPoint], imgArea: Double) -> Double {
        let r = polygonArea(q) / imgArea
        return (r < minAreaRatio || r > maxAreaRatio) ? 0 : 1
    }

    // MARK: geometry helpers
    private static func len(_ v: CGPoint) -> Double {
        return sqrt(Double(v.x * v.x + v.y * v.y))
    }

    private static func ratio(_ a: Double, _ b: Double) -> Double {
        let hi = max(a, b)
        return hi <= 0 ? 0 : min(a, b) / hi
    }

    private static func angleBetweenDeg(_ a: CGPoint, _ b: CGPoint) -> Double {
        let dot = Double(a.x * b.x + a.y * b.y)
        let mag = len(a) * len(b)
        if mag == 0 { return 0 }
        let cos = clamp(dot / mag, -1.0, 1.0)
        return acos(cos) * 180.0 / .pi
    }

    private static func directionDiffDeg(_ a: CGPoint, _ b: CGPoint) -> Double {
        let ang = angleBetweenDeg(a, b)
        return min(ang, 180.0 - ang)
    }

    private static func polygonArea(_ q: [CGPoint]) -> Double {
        var area = 0.0
        for i in 0..<4 {
            let j = (i + 1) % 4
            area += Double(q[i].x * q[j].y - q[j].x * q[i].y)
        }
        return abs(area) / 2.0
    }

    private static func boundingBox(_ q: [CGPoint]) -> CGRect {
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        for p in q {
            minX = min(minX, p.x); minY = min(minY, p.y)
            maxX = max(maxX, p.x); maxY = max(maxY, p.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func iou(_ a: CGRect, _ b: CGRect) -> Double {
        let x1 = max(a.minX, b.minX)
        let y1 = max(a.minY, b.minY)
        let x2 = min(a.maxX, b.maxX)
        let y2 = min(a.maxY, b.maxY)
        let iw = max(0, x2 - x1)
        let ih = max(0, y2 - y1)
        let inter = Double(iw * ih)
        let union = Double(a.width * a.height) + Double(b.width * b.height) - inter
        return union <= 0 ? 0 : clamp01(inter / union)
    }

    private static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        return Swift.max(lo, Swift.min(hi, v))
    }

    private static func clamp01(_ v: Double) -> Double {
        return clamp(v, 0.0, 1.0)
    }
}
