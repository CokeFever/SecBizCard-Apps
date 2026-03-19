package app.ixo.secbizcard

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import org.opencv.android.Utils
import org.opencv.core.*
import org.opencv.imgproc.Imgproc
import java.io.File
import java.io.FileOutputStream
import java.util.ArrayList

class OpenCVProcessor {

    fun processBusinessCard(inputPath: String, outputPath: String, isVertical: Boolean): Map<String, Any> {
        val resultData = HashMap<String, Any>()
        try {
            // 1. Load Image and Resize (With Exif Correction to match Flutter)
            val src = loadMatWithExif(inputPath) ?: throw Exception("Failed to load")
            
            val originalWidth = src.cols()
            val originalHeight = src.rows()

            val maxDim = 1000.0
            val scale = if (src.cols() > maxDim || src.rows() > maxDim) {
                Math.min(maxDim / src.cols(), maxDim / src.rows())
            } else {
                1.0
            }
            
            // ... (rest of function logic needs to be preserved or I need to include it in replacement)
            // Since this is a partial replace, I'll return the helper method at the bottom of the class
            // and replace the loading logic here.
            
            val resized = Mat()
            Imgproc.resize(src, resized, Size(), scale, scale, Imgproc.INTER_AREA)

            // 2. Grayscale
            val gray = Mat()
            Imgproc.cvtColor(resized, gray, Imgproc.COLOR_BGR2GRAY)

            // 3. Preprocessing
            Imgproc.GaussianBlur(gray, gray, Size(5.0, 5.0), 0.0)
            
            // 4. Edge Detection
            val edges = Mat()
            Imgproc.Canny(gray, edges, 75.0, 200.0)

            // 5. Find Contours
            val contours = ArrayList<MatOfPoint>()
            val hierarchy = Mat()
            Imgproc.findContours(edges, contours, hierarchy, Imgproc.RETR_LIST, Imgproc.CHAIN_APPROX_SIMPLE)

            // 6. Analysis
            var maxQuadArea = 0.0 // Max area for a detected quadrilateral
            var cardContour: MatOfPoint2f? = null
            var largestBlobRect: Rect? = null // Bounding rect of the largest general contour
            var largestBlobArea = 0.0 // Area of the largest general contour

            for (contour in contours) {
                val area = Imgproc.contourArea(contour)
                if (area > (resized.rows() * resized.cols() / 5)) { 
                    // Track the largest general blob for potential fallback
                    if (area > largestBlobArea) {
                        largestBlobArea = area
                        largestBlobRect = Imgproc.boundingRect(contour)
                    }

                    val contour2f = MatOfPoint2f(*contour.toArray())
                    val perimeter = Imgproc.arcLength(contour2f, true)
                    val approx = MatOfPoint2f()
                    Imgproc.approxPolyDP(contour2f, approx, 0.02 * perimeter, true)

                    // Strict Quad check
                    if (approx.total() == 4L && area > maxQuadArea) {
                        cardContour = approx
                        maxQuadArea = area
                    }
                }
            }
            
            // Fallback Logic
            if (cardContour == null) {
                val out = FileOutputStream(File(outputPath))
                // Use the loaded (rotated) src for fallback save, not original bitmap file
                val fallbackBitmap = Bitmap.createBitmap(src.cols(), src.rows(), Bitmap.Config.ARGB_8888)
                Utils.matToBitmap(src, fallbackBitmap)
                fallbackBitmap.compress(Bitmap.CompressFormat.JPEG, 90, out)
                out.flush()
                out.close()
                
                resultData["success"] = true
                resultData["fallback"] = true
                resultData["imageWidth"] = originalWidth
                resultData["imageHeight"] = originalHeight
                
                // Smart Fallback: Use largestBlobRect if found, else full screen
                if (largestBlobRect != null) {
                    // Scale rect back to original dimensions
                    val rx = largestBlobRect.x / scale 
                    val ry = largestBlobRect.y / scale
                    val rw = largestBlobRect.width / scale
                    val rh = largestBlobRect.height / scale
                    
                    resultData["points"] = listOf(
                        rx, ry,
                        rx + rw, ry,
                        rx + rw, ry + rh,
                        rx, ry + rh
                    )
                } else {
                    // Full screen default
                    resultData["points"] = listOf(
                        0.0, 0.0,
                        originalWidth.toDouble(), 0.0,
                        originalWidth.toDouble(), originalHeight.toDouble(),
                        0.0, originalHeight.toDouble()
                    )
                }
                return resultData
            }
            
            // Found contour
            val points = cardContour.toArray()
            val scaledPoints = ArrayList<Double>()
            for (i in points.indices) {
                points[i].x /= scale
                points[i].y /= scale
                scaledPoints.add(points[i].x)
                scaledPoints.add(points[i].y)
            }
            cardContour = MatOfPoint2f(*points)

             // 6. Perspective Transform
            val result = warpPerspective(src, cardContour)
            
            // 7. Enhance Image
            val enhanced = enhanceImage(result)
            var processed = enhanced 
            
            // 8. Orientation Correction
            if (isVertical) {
                // Expect Height > Width. If Width > Height, rotate 90
                if (processed.cols() > processed.rows()) {
                    Core.rotate(processed, processed, Core.ROTATE_90_CLOCKWISE)
                }
            } else {
                // Expect Width > Height. If Height > Width, rotate 90
                if (processed.rows() > processed.cols()) {
                    Core.rotate(processed, processed, Core.ROTATE_90_CLOCKWISE)
                }
            }
            
            // Save Result
            val resultBitmap = Bitmap.createBitmap(processed.cols(), processed.rows(), Bitmap.Config.ARGB_8888)
            Utils.matToBitmap(processed, resultBitmap)
            
            val file = File(outputPath)
            val out = FileOutputStream(file)
            resultBitmap.compress(Bitmap.CompressFormat.JPEG, 90, out)
            out.flush()
            out.close()
            
            resultData["success"] = true
            resultData["fallback"] = false
            resultData["imageWidth"] = originalWidth
            resultData["imageHeight"] = originalHeight
            resultData["points"] = scaledPoints
            
            return resultData
            
        } catch (e: Exception) {
            e.printStackTrace()
            resultData["success"] = false
            return resultData
        }
    }
    
    fun manualCrop(inputPath: String, points: List<Double>, outputPath: String, isVertical: Boolean): Boolean {
         try {
            // 1. Load with Exif to align with Flutter coordinates
            val src = loadMatWithExif(inputPath) ?: return false
            
            if (points.size != 8) return false
            
            val srcPoints = arrayOf(
                Point(points[0], points[1]),
                Point(points[2], points[3]),
                Point(points[4], points[5]),
                Point(points[6], points[7])
            )
            val matPoints = MatOfPoint2f(*srcPoints)
            
            // 1. First Warp (User's rough crop)
            var warped = warpPerspective(src, matPoints)
            
            // 2. Enhance Image (Brightness / Clarity)
            try {
                // Apply enhancement to the warped result
                val enhanced = enhanceImage(warped)
                warped = enhanced
            } catch (e: Exception) {
                // Ignore enhancement errors, proceed with warped
                e.printStackTrace()
            }

            // 3. Auto-Rotate based on orientation preference
            if (isVertical) {
                if (warped.cols() > warped.rows()) {
                    Core.rotate(warped, warped, Core.ROTATE_90_CLOCKWISE)
                }
            } else {
                if (warped.rows() > warped.cols()) {
                    Core.rotate(warped, warped, Core.ROTATE_90_CLOCKWISE)
                }
            }

            val resultBitmap = Bitmap.createBitmap(warped.cols(), warped.rows(), Bitmap.Config.ARGB_8888)
            Utils.matToBitmap(warped, resultBitmap)
            
            val file = File(outputPath)
            val out = FileOutputStream(file)
            resultBitmap.compress(Bitmap.CompressFormat.JPEG, 90, out)
            out.flush()
            out.close()
            
            return true
         } catch(e: Exception) {
             e.printStackTrace()
             return false
         }
    }
    
    private fun loadMatWithExif(path: String): Mat? {
        try {
            val bitmap = BitmapFactory.decodeFile(path) ?: return null
            val src = Mat()
            Utils.bitmapToMat(bitmap, src)
            
            val exif = android.media.ExifInterface(path)
            val orientation = exif.getAttributeInt(android.media.ExifInterface.TAG_ORIENTATION, android.media.ExifInterface.ORIENTATION_NORMAL)
            
            when (orientation) {
                android.media.ExifInterface.ORIENTATION_ROTATE_90 -> Core.rotate(src, src, Core.ROTATE_90_CLOCKWISE)
                android.media.ExifInterface.ORIENTATION_ROTATE_180 -> Core.rotate(src, src, Core.ROTATE_180)
                android.media.ExifInterface.ORIENTATION_ROTATE_270 -> Core.rotate(src, src, Core.ROTATE_90_COUNTERCLOCKWISE)
            }
            return src
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }

    private fun enhanceImage(src: Mat): Mat {
        val dest = Mat()
        // Simple Enhancement: Contrast 1.2, Brightness +10
        src.convertTo(dest, -1, 1.2, 10.0)
        return dest
    }

    private fun refineCrop(src: Mat): Mat? {
        try {
            val gray = Mat()
            Imgproc.cvtColor(src, gray, Imgproc.COLOR_BGR2GRAY)
            
            // Use Adaptive Threshold to find strong edges inside the crop
            val thresh = Mat()
            Imgproc.adaptiveThreshold(gray, thresh, 255.0, Imgproc.ADAPTIVE_THRESH_GAUSSIAN_C, Imgproc.THRESH_BINARY_INV, 11, 2.0)
            
            // Edge detection
            val edges = Mat()
            Imgproc.Canny(thresh, edges, 50.0, 150.0) // Lower thresholds for inner detail? No, standard is fine

            val contours = ArrayList<MatOfPoint>()
            Imgproc.findContours(edges, contours, Mat(), Imgproc.RETR_LIST, Imgproc.CHAIN_APPROX_SIMPLE)

            var maxArea = 0.0
            var cardContour: MatOfPoint2f? = null
            val imgArea = src.rows() * src.cols()

            for (contour in contours) {
                val area = Imgproc.contourArea(contour)
                // We're looking for a card that fills MOST of the crop (> 50%) but is "cleaner"
                if (area > (imgArea * 0.5)) { 
                    val contour2f = MatOfPoint2f(*contour.toArray())
                    val perimeter = Imgproc.arcLength(contour2f, true)
                    val approx = MatOfPoint2f()
                    Imgproc.approxPolyDP(contour2f, approx, 0.02 * perimeter, true)

                    if (approx.total() == 4L && area > maxArea) {
                        // Check convex?
                        if (Imgproc.isContourConvex(MatOfPoint( *approx.toArray() ))) {
                             cardContour = approx
                             maxArea = area
                        }
                    }
                }
            }
            
            if (cardContour != null) {
                 return warpPerspective(src, cardContour)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return null // No better crop found
    }

    private fun warpPerspective(src: Mat, contour: MatOfPoint2f): Mat {
        val points = contour.toArray()
        
        // Sort points: top-left, top-right, bottom-right, bottom-left
        // This is a simplified sorting
        val sortedPoints = sortPoints(points)

        val widthA = Math.sqrt(Math.pow(sortedPoints[2].x - sortedPoints[3].x, 2.0) + Math.pow(sortedPoints[2].y - sortedPoints[3].y, 2.0))
        val widthB = Math.sqrt(Math.pow(sortedPoints[1].x - sortedPoints[0].x, 2.0) + Math.pow(sortedPoints[1].y - sortedPoints[0].y, 2.0))
        val maxWidth = Math.max(widthA.toInt(), widthB.toInt())

        val heightA = Math.sqrt(Math.pow(sortedPoints[1].x - sortedPoints[2].x, 2.0) + Math.pow(sortedPoints[1].y - sortedPoints[2].y, 2.0))
        val heightB = Math.sqrt(Math.pow(sortedPoints[0].x - sortedPoints[3].x, 2.0) + Math.pow(sortedPoints[0].y - sortedPoints[3].y, 2.0))
        val maxHeight = Math.max(heightA.toInt(), heightB.toInt())

        val dst = MatOfPoint2f(
            Point(0.0, 0.0),
            Point(maxWidth.toDouble() - 1, 0.0),
            Point(maxWidth.toDouble() - 1, maxHeight.toDouble() - 1),
            Point(0.0, maxHeight.toDouble() - 1)
        )

        val srcPoints = MatOfPoint2f(*sortedPoints)
        val M = Imgproc.getPerspectiveTransform(srcPoints, dst)
        val warped = Mat()
        Imgproc.warpPerspective(src, warped, M, Size(maxWidth.toDouble(), maxHeight.toDouble()))

        return warped
    }

    private fun sortPoints(points: Array<Point>): Array<Point> {
        val result = Array(4) { Point(0.0, 0.0) }
        
        // Sum and Diff to find corners
        // Top-left: min (x+y), Bottom-right: max (x+y)
        // Top-right: min (y-x), Bottom-left: max (y-x)
        
        points.sortBy { it.x + it.y }
        result[0] = points[0] // Top-left
        result[2] = points[3] // Bottom-right
        
        val remaining = arrayOf(points[1], points[2])
        remaining.sortBy { it.y - it.x }
        result[1] = remaining[0] // Top-right
        result[3] = remaining[1] // Bottom-left
        
        return result
    }
}
