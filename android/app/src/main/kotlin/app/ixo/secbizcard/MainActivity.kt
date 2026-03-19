package app.ixo.secbizcard

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import org.opencv.android.OpenCVLoader

class MainActivity : FlutterActivity() {
    private val CHANNEL_HCE = "app.ixo.secbizcard/hce"
    private val CHANNEL_OPENCV = "app.ixo.secbizcard/opencv"
    private val ocvProcessor = OpenCVProcessor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        if (OpenCVLoader.initDebug()) {
            android.util.Log.i("SecBizCard", "OpenCV loaded successfully")
        } else {
            android.util.Log.e("SecBizCard", "OpenCV initialization failed!")
        }

        super.configureFlutterEngine(flutterEngine)
        
        // HCE Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_HCE).setMethodCallHandler { call, result ->
            if (call.method == "setSharingUrl") {
                val url = call.argument<String>("url")
                if (url != null) {
                    HostCardEmulatorService.setSharingUrl(url)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "URL is null", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // OpenCV Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_OPENCV).setMethodCallHandler { call, result ->
            if (call.method == "processCard") {
                val inputPath = call.argument<String>("inputPath")
                val outputPath = call.argument<String>("outputPath")
                val isVertical = call.argument<Boolean>("isVertical") ?: false

                if (inputPath != null && outputPath != null) {
                    val resultMap = ocvProcessor.processBusinessCard(inputPath, outputPath, isVertical)
                    val success = resultMap["success"] as Boolean
                    if (success) {
                        result.success(resultMap)
                    } else {
                        result.error("PROCESSING_FAILED", "Could not detect card or process image", null)
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "Path is null", null)
                }
            } else if (call.method == "manualCrop") {
                val inputPath = call.argument<String>("inputPath")
                val outputPath = call.argument<String>("outputPath")
                val points = call.argument<List<Double>>("points")
                val isVertical = call.argument<Boolean>("isVertical") ?: false
                
                if (inputPath != null && outputPath != null && points != null) {
                    val success = ocvProcessor.manualCrop(inputPath, points, outputPath, isVertical)
                    result.success(success)
                } else {
                    result.error("INVALID_ARGUMENT", "Args missing", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
