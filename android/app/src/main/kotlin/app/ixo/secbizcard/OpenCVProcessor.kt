package app.ixo.secbizcard

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import org.opencv.android.Utils
import org.opencv.core.*
import org.opencv.imgproc.Imgproc
import java.io.File
import java.io.FileOutputStream
import java.util.ArrayList
import kotlin.math.abs
import kotlin.math.acos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/**
 * Business-card detection + perspective correction.
 *
 * OpenCV is used only to PRODUCE candidate quadrilaterals. The candidate is
 * chosen and validated by the shared geometric scoring model documented in
 * docs/card_detection_scoring.md, which is implemented identically on iOS
 * (AppDelegate.swift). A business card is a rigid rectangle, so under camera
 * perspective it stays a convex quad with near-90° corners and roughly
 * parallel opposite edges — CardScoring exploits exactly that.
 */
class OpenCVProcessor {

    // ---- Shared scoring constants (MUST match AppDelegate.swift) -----------
    private object S {
        const val CARD_ASPECT_RATIO = 1.586
        const val ANGLE_TOLERANCE_DEG = 35.0
        const val MIN_AREA_RATIO = 0.10
        const val MAX_AREA_RATIO = 0.99
        const val PARALLEL_TOLERANCE_DEG = 25.0
        const val MIN_ACCEPT_SCORE = 0.55
        const val W_ANGLE = 0.40
        const val W_PARALLEL = 0.20
        const val W_ASPECT = 0.15
        const val W_AREA = 0.10
        const val W_GUIDE = 0.15
    }

    fun processBusinessCard(
        inputPath: String,
        outputPath: String,
        isVertical: Boolean,
        guideRect: Map<String, Double>? = null,
    ): Map<String, Any> {
        val resultData = HashMap<String, Any>()
        try {
            val src = loadMatWithExif(inputPath) ?: throw Exception("Failed to load")
            val originalWidth = src.cols()
            val originalHeight = src.rows()

            val maxDim = 1000.0
            val scale = if (src.cols() > maxDim || src.rows() > maxDim) {
                min(maxDim / src.cols(), maxDim / src.rows())
            } else {
                1.0
            }

            val resized = Mat()
            Imgproc.resize(src, resized, Size(), scale, scale, Imgproc.INTER_AREA)

            val imgArea = (resized.rows() * resized.cols()).toDouble()

            // Guide rect in RESIZED image pixels (from normalized 0..1 input).
            val guide: Rect? = guideRect?.let {
                val l = (it["left"] ?: 0.0) * resized.cols()
                val t = (it["top"] ?: 0.0) * resized.rows()
                val w = (it["width"] ?: 0.0) * resized.cols()
                val h = (it["height"] ?: 0.0) * resized.rows()
                Rect(l.toInt(), t.toInt(), w.toInt(), h.toInt())
            }

            // 1. Collect candidate quads from multiple edge strategies.
            val candidates = collectCandidates(resized)

            // 2. Score every candidate with the shared model; pick the best.
            var bestQuad: Array<Point>? = null
            var bestScore = 0.0
            for (quad in candidates) {
                val score = scoreQuad(quad, imgArea, guide)
                if (score > bestScore) {
                    bestScore = score
                    bestQuad = quad
                }
            }

            if (bestQuad != null && bestScore >= S.MIN_ACCEPT_SCORE) {
                // Scale corners back to original resolution.
                val scaledPoints = ArrayList<Double>()
                val origCorners = arrayOfNulls<Point>(4)
                for (i in bestQuad.indices) {
                    val x = bestQuad[i].x / scale
                    val y = bestQuad[i].y / scale
                    origCorners[i] = Point(x, y)
                    scaledPoints.add(x)
                    scaledPoints.add(y)
                }

                val cardContour = MatOfPoint2f(*origCorners.map { it!! }.toTypedArray())
                val result = warpPerspective(src, cardContour)
                var processed = enhanceImage(result)

                if (isVertical) {
                    if (processed.cols() > processed.rows()) {
                        Core.rotate(processed, processed, Core.ROTATE_90_CLOCKWISE)
                    }
                } else {
                    if (processed.rows() > processed.cols()) {
                        Core.rotate(processed, processed, Core.ROTATE_90_CLOCKWISE)
                    }
                }

                saveMatAsJpeg(processed, outputPath)

                resultData["success"] = true
                resultData["fallback"] = false
                resultData["score"] = bestScore
                resultData["imageWidth"] = originalWidth
                resultData["imageHeight"] = originalHeight
                resultData["points"] = scaledPoints
                return resultData
            }

            // 3. Fallback: hand off the GUIDE region (not the whole image) to
            //    the manual 4-corner adjuster.
            saveMatAsJpeg(src, outputPath)
            resultData["success"] = true
            resultData["fallback"] = true
            resultData["score"] = bestScore
            resultData["imageWidth"] = originalWidth
            resultData["imageHeight"] = originalHeight
            resultData["points"] = fallbackPoints(guide, scale, originalWidth, originalHeight)
            return resultData
        } catch (e: Exception) {
            e.printStackTrace()
            resultData["success"] = false
            return resultData
        }
    }

    /** Corner points for the fallback crop: the guide region if available,
     *  otherwise the full image. Returned in ORIGINAL image pixels. */
    private fun fallbackPoints(
        guide: Rect?,
        scale: Double,
        origW: Int,
        origH: Int,
    ): List<Double> {
        if (guide != null) {
            val gx = guide.x / scale
            val gy = guide.y / scale
            val gw = guide.width / scale
            val gh = guide.height / scale
            return listOf(
                gx, gy,
                gx + gw, gy,
                gx + gw, gy + gh,
                gx, gy + gh,
            )
        }
        return listOf(
            0.0, 0.0,
            origW.toDouble(), 0.0,
            origW.toDouble(), origH.toDouble(),
            0.0, origH.toDouble(),
        )
    }

    /**
     * Produces candidate quadrilaterals using multiple edge-detection
     * strategies (Canny at two thresholds + adaptive threshold), each followed
     * by contour approximation. approxPolyDP is tried at several epsilon values
     * so cards with rounded corners / inner borders (which yield 5+ vertices)
     * are still recovered via a 4-point minimum-area rectangle.
     */
    private fun collectCandidates(resized: Mat): List<Array<Point>> {
        val gray = Mat()
        Imgproc.cvtColor(resized, gray, Imgproc.COLOR_BGR2GRAY)
        Imgproc.GaussianBlur(gray, gray, Size(5.0, 5.0), 0.0)

        val edgeMaps = ArrayList<Mat>()

        // Strategy A: Canny (standard thresholds).
        val cannyA = Mat()
        Imgproc.Canny(gray, cannyA, 75.0, 200.0)
        edgeMaps.add(cannyA)

        // Strategy B: Canny (lower thresholds for low-contrast backgrounds).
        val cannyB = Mat()
        Imgproc.Canny(gray, cannyB, 30.0, 120.0)
        edgeMaps.add(cannyB)

        // Strategy C: adaptive threshold (helps when the card edge has weak
        // gradients but a tonal difference from the background).
        val adaptive = Mat()
        Imgproc.adaptiveThreshold(
            gray, adaptive, 255.0,
            Imgproc.ADAPTIVE_THRESH_GAUSSIAN_C, Imgproc.THRESH_BINARY_INV, 11, 2.0,
        )
        edgeMaps.add(adaptive)

        val minArea = resized.rows() * resized.cols() / 8.0
        val candidates = ArrayList<Array<Point>>()

        for (edges in edgeMaps) {
            // Close small gaps so card borders form continuous contours.
            val kernel = Imgproc.getStructuringElement(Imgproc.MORPH_RECT, Size(3.0, 3.0))
            Imgproc.morphologyEx(edges, edges, Imgproc.MORPH_CLOSE, kernel)

            val contours = ArrayList<MatOfPoint>()
            Imgproc.findContours(
                edges, contours, Mat(),
                Imgproc.RETR_LIST, Imgproc.CHAIN_APPROX_SIMPLE,
            )

            for (contour in contours) {
                val area = Imgproc.contourArea(contour)
                if (area < minArea) continue

                val c2f = MatOfPoint2f(*contour.toArray())
                val peri = Imgproc.arcLength(c2f, true)

                // Try several epsilon fractions to approximate a 4-gon.
                for (epsFrac in doubleArrayOf(0.02, 0.03, 0.05, 0.08)) {
                    val approx = MatOfPoint2f()
                    Imgproc.approxPolyDP(c2f, approx, epsFrac * peri, true)
                    val n = approx.total().toInt()
                    if (n == 4) {
                        candidates.add(sortPoints(approx.toArray()))
                        break
                    } else if (n in 5..8) {
                        // Reduce to a rotated bounding rectangle (4 points).
                        val rot = Imgproc.minAreaRect(approx)
                        val box = arrayOfNulls<Point>(4)
                        rot.points(box)
                        candidates.add(sortPoints(box.map { it!! }.toTypedArray()))
                        break
                    }
                }
            }
        }
        return candidates
    }

    // ------------------------------------------------------------------------
    // Shared geometric scoring model (mirror of AppDelegate.swift)
    // ------------------------------------------------------------------------

    /** Full score for a candidate quad. Corners are TL,TR,BR,BL. */
    private fun scoreQuad(quad: Array<Point>, imgArea: Double, guide: Rect?): Double {
        if (!isConvex(quad)) return 0.0

        val sAngle = angleScore(quad)
        if (sAngle <= 0.0) return 0.0
        val sParallel = parallelScore(quad)
        val sAspect = aspectScore(quad)
        val sArea = areaScore(quad, imgArea)
        if (sArea <= 0.0) return 0.0

        return if (guide != null) {
            val sGuide = iou(boundingBox(quad), guide)
            S.W_ANGLE * sAngle + S.W_PARALLEL * sParallel + S.W_ASPECT * sAspect +
                S.W_AREA * sArea + S.W_GUIDE * sGuide
        } else {
            // Renormalize without the guide weight.
            val total = S.W_ANGLE + S.W_PARALLEL + S.W_ASPECT + S.W_AREA
            (S.W_ANGLE * sAngle + S.W_PARALLEL * sParallel +
                S.W_ASPECT * sAspect + S.W_AREA * sArea) / total
        }
    }

    private fun isConvex(q: Array<Point>): Boolean {
        var sign = 0
        for (i in 0 until 4) {
            val a = q[i]
            val b = q[(i + 1) % 4]
            val c = q[(i + 2) % 4]
            val cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)
            val s = if (cross > 0) 1 else -1
            if (cross != 0.0) {
                if (sign == 0) sign = s else if (sign != s) return false
            }
        }
        return true
    }

    private fun angleScore(q: Array<Point>): Double {
        var sumDev = 0.0
        for (i in 0 until 4) {
            val prev = q[(i + 3) % 4]
            val cur = q[i]
            val next = q[(i + 1) % 4]
            val v1 = Point(prev.x - cur.x, prev.y - cur.y)
            val v2 = Point(next.x - cur.x, next.y - cur.y)
            val ang = angleBetweenDeg(v1, v2)
            val dev = abs(ang - 90.0)
            if (dev > S.ANGLE_TOLERANCE_DEG) return 0.0
            sumDev += dev
        }
        val meanDev = sumDev / 4.0
        return (1.0 - meanDev / S.ANGLE_TOLERANCE_DEG).coerceIn(0.0, 1.0)
    }

    private fun parallelScore(q: Array<Point>): Double {
        val top = Point(q[1].x - q[0].x, q[1].y - q[0].y)
        val bottom = Point(q[2].x - q[3].x, q[2].y - q[3].y)
        val left = Point(q[3].x - q[0].x, q[3].y - q[0].y)
        val right = Point(q[2].x - q[1].x, q[2].y - q[1].y)

        val dTB = directionDiffDeg(top, bottom)
        val dLR = directionDiffDeg(left, right)
        val penalty = (dTB + dLR) / (2 * S.PARALLEL_TOLERANCE_DEG)

        val lenTB = ratio(len(top), len(bottom))
        val lenLR = ratio(len(left), len(right))
        return ((1.0 - penalty).coerceIn(0.0, 1.0)) * ((lenTB + lenLR) / 2.0)
    }

    private fun aspectScore(q: Array<Point>): Double {
        val top = len(Point(q[1].x - q[0].x, q[1].y - q[0].y))
        val bottom = len(Point(q[2].x - q[3].x, q[2].y - q[3].y))
        val left = len(Point(q[3].x - q[0].x, q[3].y - q[0].y))
        val right = len(Point(q[2].x - q[1].x, q[2].y - q[1].y))
        val w = (top + bottom) / 2.0
        val h = (left + right) / 2.0
        if (w <= 0 || h <= 0) return 0.0
        val ar = max(w, h) / min(w, h)
        return (1.0 - abs(ar - S.CARD_ASPECT_RATIO) / S.CARD_ASPECT_RATIO)
            .coerceIn(0.0, 1.0)
    }

    private fun areaScore(q: Array<Point>, imgArea: Double): Double {
        val r = polygonArea(q) / imgArea
        return if (r < S.MIN_AREA_RATIO || r > S.MAX_AREA_RATIO) 0.0 else 1.0
    }

    // ---- geometry helpers --------------------------------------------------

    private fun len(v: Point): Double = sqrt(v.x * v.x + v.y * v.y)

    private fun ratio(a: Double, b: Double): Double {
        val hi = max(a, b)
        return if (hi <= 0) 0.0 else min(a, b) / hi
    }

    /** Angle (deg) between two vectors sharing an origin, range 0..180. */
    private fun angleBetweenDeg(a: Point, b: Point): Double {
        val dot = a.x * b.x + a.y * b.y
        val mag = len(a) * len(b)
        if (mag == 0.0) return 0.0
        val cos = (dot / mag).coerceIn(-1.0, 1.0)
        return Math.toDegrees(acos(cos))
    }

    /** Difference in direction (deg) between two edge vectors, range 0..90. */
    private fun directionDiffDeg(a: Point, b: Point): Double {
        val ang = angleBetweenDeg(a, b)
        return min(ang, 180.0 - ang)
    }

    private fun polygonArea(q: Array<Point>): Double {
        var area = 0.0
        for (i in 0 until 4) {
            val j = (i + 1) % 4
            area += q[i].x * q[j].y - q[j].x * q[i].y
        }
        return abs(area) / 2.0
    }

    private fun boundingBox(q: Array<Point>): Rect {
        var minX = Double.MAX_VALUE
        var minY = Double.MAX_VALUE
        var maxX = -Double.MAX_VALUE
        var maxY = -Double.MAX_VALUE
        for (p in q) {
            minX = min(minX, p.x); minY = min(minY, p.y)
            maxX = max(maxX, p.x); maxY = max(maxY, p.y)
        }
        return Rect(minX.toInt(), minY.toInt(), (maxX - minX).toInt(), (maxY - minY).toInt())
    }

    private fun iou(a: Rect, b: Rect): Double {
        val x1 = max(a.x, b.x)
        val y1 = max(a.y, b.y)
        val x2 = min(a.x + a.width, b.x + b.width)
        val y2 = min(a.y + a.height, b.y + b.height)
        val iw = max(0, x2 - x1)
        val ih = max(0, y2 - y1)
        val inter = (iw * ih).toDouble()
        val union = a.width.toDouble() * a.height + b.width.toDouble() * b.height - inter
        return if (union <= 0) 0.0 else (inter / union).coerceIn(0.0, 1.0)
    }

    // ------------------------------------------------------------------------
    // Manual crop (unchanged behaviour)
    // ------------------------------------------------------------------------

    fun manualCrop(inputPath: String, points: List<Double>, outputPath: String, isVertical: Boolean): Boolean {
        try {
            val src = loadMatWithExif(inputPath) ?: return false
            if (points.size != 8) return false

            val srcPoints = arrayOf(
                Point(points[0], points[1]),
                Point(points[2], points[3]),
                Point(points[4], points[5]),
                Point(points[6], points[7]),
            )
            val matPoints = MatOfPoint2f(*srcPoints)
            var warped = warpPerspective(src, matPoints)

            try {
                warped = enhanceImage(warped)
            } catch (e: Exception) {
                e.printStackTrace()
            }

            if (isVertical) {
                if (warped.cols() > warped.rows()) {
                    Core.rotate(warped, warped, Core.ROTATE_90_CLOCKWISE)
                }
            } else {
                if (warped.rows() > warped.cols()) {
                    Core.rotate(warped, warped, Core.ROTATE_90_CLOCKWISE)
                }
            }

            saveMatAsJpeg(warped, outputPath)
            return true
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }

    // ------------------------------------------------------------------------
    // Shared image helpers
    // ------------------------------------------------------------------------

    private fun saveMatAsJpeg(mat: Mat, outputPath: String) {
        val bitmap = Bitmap.createBitmap(mat.cols(), mat.rows(), Bitmap.Config.ARGB_8888)
        Utils.matToBitmap(mat, bitmap)
        val out = FileOutputStream(File(outputPath))
        bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out)
        out.flush()
        out.close()
    }

    private fun loadMatWithExif(path: String): Mat? {
        try {
            val bitmap = BitmapFactory.decodeFile(path) ?: return null
            val src = Mat()
            Utils.bitmapToMat(bitmap, src)

            val exif = android.media.ExifInterface(path)
            val orientation = exif.getAttributeInt(
                android.media.ExifInterface.TAG_ORIENTATION,
                android.media.ExifInterface.ORIENTATION_NORMAL,
            )

            when (orientation) {
                android.media.ExifInterface.ORIENTATION_ROTATE_90 ->
                    Core.rotate(src, src, Core.ROTATE_90_CLOCKWISE)
                android.media.ExifInterface.ORIENTATION_ROTATE_180 ->
                    Core.rotate(src, src, Core.ROTATE_180)
                android.media.ExifInterface.ORIENTATION_ROTATE_270 ->
                    Core.rotate(src, src, Core.ROTATE_90_COUNTERCLOCKWISE)
            }
            return src
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }

    private fun enhanceImage(src: Mat): Mat {
        val dest = Mat()
        src.convertTo(dest, -1, 1.2, 10.0)
        return dest
    }

    private fun warpPerspective(src: Mat, contour: MatOfPoint2f): Mat {
        val points = contour.toArray()
        val sortedPoints = sortPoints(points)

        val widthA = dist(sortedPoints[2], sortedPoints[3])
        val widthB = dist(sortedPoints[1], sortedPoints[0])
        val maxWidth = max(widthA.toInt(), widthB.toInt())

        val heightA = dist(sortedPoints[1], sortedPoints[2])
        val heightB = dist(sortedPoints[0], sortedPoints[3])
        val maxHeight = max(heightA.toInt(), heightB.toInt())

        val dst = MatOfPoint2f(
            Point(0.0, 0.0),
            Point(maxWidth.toDouble() - 1, 0.0),
            Point(maxWidth.toDouble() - 1, maxHeight.toDouble() - 1),
            Point(0.0, maxHeight.toDouble() - 1),
        )

        val srcPoints = MatOfPoint2f(*sortedPoints)
        val m = Imgproc.getPerspectiveTransform(srcPoints, dst)
        val warped = Mat()
        Imgproc.warpPerspective(src, warped, m, Size(maxWidth.toDouble(), maxHeight.toDouble()))
        return warped
    }

    private fun dist(a: Point, b: Point): Double =
        sqrt(Math.pow(a.x - b.x, 2.0) + Math.pow(a.y - b.y, 2.0))

    private fun sortPoints(points: Array<Point>): Array<Point> {
        val result = Array(4) { Point(0.0, 0.0) }
        val pts = points.copyOf()
        pts.sortBy { it.x + it.y }
        result[0] = pts[0]           // Top-left (min x+y)
        result[2] = pts[pts.size - 1] // Bottom-right (max x+y)

        val remaining = arrayOf(pts[1], pts[2])
        remaining.sortBy { it.y - it.x }
        result[1] = remaining[0]     // Top-right
        result[3] = remaining[1]     // Bottom-left
        return result
    }
}
