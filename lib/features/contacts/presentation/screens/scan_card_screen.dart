import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:secbizcard/features/contacts/data/services/ocr_service.dart';

class ScanCardScreen extends StatefulWidget {
  const ScanCardScreen({super.key});

  @override
  State<ScanCardScreen> createState() => _ScanCardScreenState();
}

class _ScanCardScreenState extends State<ScanCardScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isProcessing = false;
  final _ocrService = OCRService();
  bool _isVertical = false;
  String? _capturedImagePath;
  String _processingStatus = '';

  // Permission state: null = still checking, true = denied, false = granted
  bool? _isPermissionDenied;
  bool _isPermanentlyDenied = false;
  bool _isCameraError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndRequestPermission();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recheckPermission();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Dispose camera when app goes to background to prevent resource locks
      _disposeCamera();
    }
  }

  /// Called once on init – requests permission if needed, then starts camera.
  Future<void> _checkAndRequestPermission() async {
    var status = await Permission.camera.status;
    debugPrint('[ScanCard] Initial status: $status');

    if (!status.isGranted && !status.isPermanentlyDenied) {
      status = await Permission.camera.request();
      debugPrint('[ScanCard] After request: $status');
    }

    if (!mounted) return;

    if (status.isGranted) {
      await _startCamera();
    } else {
      setState(() {
        _isPermissionDenied = true;
        _isPermanentlyDenied = status.isPermanentlyDenied;
      });
    }
  }

  /// Called on resume – only checks status, never prompts.
  Future<void> _recheckPermission() async {
    final status = await Permission.camera.status;
    debugPrint('[ScanCard] Recheck status: $status');
    if (!mounted) return;

    if (status.isGranted) {
      // Permission is granted – restart camera
      await _startCamera();
    } else {
      // Permission was revoked
      _disposeCamera();
      setState(() {
        _isPermissionDenied = true;
        _isPermanentlyDenied = status.isPermanentlyDenied;
      });
    }
  }

  Future<void> _startCamera() async {
    // Dispose any existing controller first
    _disposeCamera();

    try {
      final cameras = await availableCameras();
      debugPrint('[ScanCard] Available cameras: ${cameras.length}');
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _isCameraError = true;
          });
        }
        return;
      }

      final controller = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();
      if (mounted) {
        setState(() {
          _controller = controller;
          _isPermissionDenied = false;
          _isPermanentlyDenied = false;
          _isCameraError = false;
        });
      } else {
        controller.dispose();
      }
    } catch (e) {
      debugPrint('[ScanCard] Camera init error: $e');
      if (mounted) {
        setState(() {
          _isCameraError = true;
        });
      }
    }
  }

  void _disposeCamera() {
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isProcessing) {
      return;
    }

    // Immediately show processing state
    HapticFeedback.lightImpact();
    setState(() {
      _isProcessing = true;
      _processingStatus = 'Capturing...';
    });

    try {
      final image = await _controller!.takePicture();

      // Freeze the screen: show captured image instead of camera preview
      if (mounted) {
        setState(() {
          _capturedImagePath = image.path;
          _processingStatus = 'Detecting card edges...';
        });
      }

      // Call OpenCV Perspective Correction
      String finalImagePath = image.path;
      try {
        final processedPath = await _processWithOpenCV(image.path);

        if (processedPath == null) {
          // User cancelled manual crop or processing failed
          if (mounted) {
            setState(() {
              _isProcessing = false;
              _capturedImagePath = null;
              _processingStatus = '';
            });
          }
          return;
        }

        finalImagePath = processedPath;
      } catch (e) {
        debugPrint('OpenCV processing failed, falling back to original: $e');
      }

      // OCR Recognition
      if (mounted) {
        setState(() {
          _processingStatus = 'Recognizing text...';
        });
      }

      final profile = await _ocrService.recognizeBusinessCard(finalImagePath);

      if (mounted) {
        if (profile != null) {
          context.push(
            '/review-contact',
            extra: {'profile': profile, 'imagePath': finalImagePath},
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to recognize text on card')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error taking picture: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _capturedImagePath = null;
          _processingStatus = '';
        });
      }
    }
  }

  Future<String?> _processWithOpenCV(String inputPath) async {
    const channel = MethodChannel('app.ixo.secbizcard/opencv');
    final outputPath = inputPath.replaceFirst('.jpg', '_processed.jpg');

    try {
      final result = await channel.invokeMethod('processCard', {
        'inputPath': inputPath,
        'outputPath': outputPath,
        'isVertical': _isVertical,
      });

      if (result is Map) {
        final success = result['success'] as bool? ?? false;
        final isFallback = result['fallback'] as bool? ?? false;

        if (!success) {
          throw Exception('Processing failed');
        }

        if (isFallback) {
          final width = (result['imageWidth'] as int?)?.toDouble() ?? 1080.0;
          final height = (result['imageHeight'] as int?)?.toDouble() ?? 1920.0;
          final points =
              (result['points'] as List?)?.cast<double>() ??
              [0.0, 0.0, width, 0.0, width, height, 0.0, height];

          if (mounted) {
            final manualResult = await context.push<String>(
              '/manual-crop',
              extra: {
                'imagePath': inputPath,
                'initialPoints': points,
                'imageWidth': width,
                'imageHeight': height,
                'isVertical': _isVertical,
              },
            );

            if (manualResult != null) return manualResult;
          }
          return null;
        }

        return outputPath;
      } else if (result is String) {
        return result;
      }

      return null;
    } on MissingPluginException {
      debugPrint('OpenCV channel not implemented (iOS?), falling back to original image');
      return inputPath;
    } catch (e) {
      debugPrint('OpenCV Error: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // 1. Still checking permission
    if (_isPermissionDenied == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    // 2. Permission Denied View
    if (_isPermissionDenied == true) {
      return _buildPermissionDeniedView();
    }

    // 3. Camera Error View
    if (_isCameraError) {
      return _buildCameraErrorView();
    }

    // 4. Camera loading
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview OR Frozen Snapshot
          Center(
            child: _capturedImagePath != null
                ? Image.file(
                    File(_capturedImagePath!),
                    fit: BoxFit.cover,
                    width: size.width,
                    height: size.height,
                  )
                : AspectRatio(
                    aspectRatio: 1 / _controller!.value.aspectRatio,
                    child: CameraPreview(_controller!),
                  ),
          ),

          // Processing Overlay (shown when processing)
          if (_isProcessing && _capturedImagePath != null)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _processingStatus,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // High-performance Custom Overlay (hidden during processing)
          if (!_isProcessing || _capturedImagePath == null)
            Positioned.fill(
              child: CustomPaint(
                painter: CameraOverlayPainter(
                  isVertical: _isVertical,
                  size: size,
                ),
              ),
            ),

          // Orientation Toggle Overlay (hidden during processing)
          if (!_isProcessing)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildToggleOption(
                        label: 'Horizontal',
                        icon: Icons.crop_landscape,
                        isSelected: !_isVertical,
                        onTap: () => setState(() => _isVertical = false),
                      ),
                      _buildToggleOption(
                        label: 'Vertical',
                        icon: Icons.crop_portrait,
                        isSelected: _isVertical,
                        onTap: () => setState(() => _isVertical = true),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Instruction Text (hidden during processing)
          if (!_isProcessing)
            Positioned(
              bottom: 160,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text(
                    'Place Business Card in frame',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ),

          // Back Button (always visible)
          Positioned(
            top: 60,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black45,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.pop(),
              ),
            ),
          ),

          // Capture Button (hidden during processing)
          if (!_isProcessing)
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Center(
                child: FloatingActionButton.large(
                  onPressed: _takePicture,
                  backgroundColor: Colors.white,
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.black,
                    size: 36,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPermissionDeniedView() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.camera_alt_outlined,
                size: 80,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 24),
              const Text(
                'Camera Permission Required',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'This feature requires camera access to scan and recognize business cards.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_isPermanentlyDenied)
                ElevatedButton.icon(
                  onPressed: () => openAppSettings(),
                  icon: const Icon(Icons.settings),
                  label: const Text('Open Settings'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: _checkAndRequestPermission,
                  icon: const Icon(Icons.security),
                  label: const Text('Grant Permission'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraErrorView() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 24),
              const Text(
                'Camera Unavailable',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Could not access the camera. Please ensure it is not being used by another app.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _checkAndRequestPermission,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.black : Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CameraOverlayPainter extends CustomPainter {
  final bool isVertical;
  final Size size;

  CameraOverlayPainter({required this.isVertical, required this.size});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.6);

    final cardW = isVertical ? (size.width * 0.6) : (size.width * 0.85);
    final cardH = isVertical
        ? (cardW * (90 / 55))
        : (cardW * (55 / 90));

    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: cardW,
      height: cardH,
    );

    // Draw darkened background with a hole
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12))),
      ),
      paint,
    );

    // Draw white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CameraOverlayPainter oldDelegate) {
    return oldDelegate.isVertical != isVertical;
  }
}
