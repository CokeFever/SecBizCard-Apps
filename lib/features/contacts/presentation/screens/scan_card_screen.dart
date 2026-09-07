import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:secbizcard/features/contacts/data/services/ocr_service.dart';
import 'package:secbizcard/generated/l10n/app_localizations.dart';

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
  OcrPreScanStatus? _preScanStatus; // engine + remaining shared quota

  // Permission state: null = still checking, true = denied, false = granted
  bool? _isPermissionDenied;
  bool _isPermanentlyDenied = false;
  bool _isCameraError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndRequestPermission();
    _loadPreScanStatus();
  }

  Future<void> _loadPreScanStatus() async {
    final status = await _ocrService.preScanStatus();
    if (mounted) setState(() => _preScanStatus = status);
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

      // OCR Recognition. We attempt Cloud Vision first (own key or shared),
      // so reflect that in the status; if it falls back, the review screen's
      // badge will show on-device instead.
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        final willUseCloud = await _ocrService.willAttemptCloudVision();
        setState(() {
          _processingStatus = willUseCloud
              ? l10n.ocrRecognizingCloudVision
              : l10n.ocrRecognizingOnDevice;
        });
      }

      final outcome = await _ocrService.recognize(finalImagePath);

      if (mounted) {
        final profile = outcome.profile;
        if (profile != null) {
          // Surface a brief note when we fell back or are near a usage limit.
          final msg = _ocrNoteMessage(outcome);
          if (msg != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
            );
          }
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

  /// The on-screen alignment guide, expressed as a normalized rectangle
  /// (0..1) relative to the image. The guide is always centered; its size
  /// mirrors [CameraOverlayPainter] (vertical: 0.6 of the shorter side,
  /// horizontal: 0.85 of the longer side, card aspect 55:90). Passing this to
  /// the native detector lets it use the frame the user aimed with as a soft
  /// prior — matching docs/card_detection_scoring.md (W_GUIDE).
  Map<String, double> _normalizedGuideRect() {
    // Fraction of the frame the card guide occupies, along width/height.
    // These mirror CameraOverlayPainter's cardW/cardH ratios.
    final double wFrac;
    final double hFrac;
    if (_isVertical) {
      wFrac = 0.6;
      hFrac = 0.6 * (90 / 55); // may exceed 1.0 on very tall guides; clamped
    } else {
      wFrac = 0.85;
      hFrac = 0.85 * (55 / 90);
    }
    final clampedW = wFrac.clamp(0.0, 1.0);
    final clampedH = hFrac.clamp(0.0, 1.0);
    return {
      'left': (0.5 - clampedW / 2).clamp(0.0, 1.0),
      'top': (0.5 - clampedH / 2).clamp(0.0, 1.0),
      'width': clampedW,
      'height': clampedH,
    };
  }

  /// Camera-preview badge showing the engine that will be used and, for the
  /// shared key, remaining monthly quota (e.g. "Cloud Vision · 2/5 this month").
  Widget _buildPreScanBadge(BuildContext context, OcrPreScanStatus status) {
    final l10n = AppLocalizations.of(context)!;
    late final String label;
    switch (status.engine) {
      case OcrEngineUsed.ownKeyVision:
        // BYOK: no numbers (usage is managed by the user in Cloud Console).
        label = l10n.ocrSourceCloudVisionOwn;
        break;
      case OcrEngineUsed.sharedVision:
        if (status.whitelisted &&
            status.used != null &&
            status.cap != null) {
          // Owner/admin: show the shared key's global monthly usage.
          label = l10n.ocrSharedKeyUsage(status.used!, status.cap!);
        } else if (status.used != null && status.cap != null) {
          label = l10n.ocrSourceCloudVisionShared(status.used!, status.cap!);
        } else {
          label = l10n.ocrRecognizingCloudVision;
        }
        break;
      case OcrEngineUsed.mlKit:
        label = l10n.ocrSourceOnDevice;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_outlined, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  /// A short, friendly message when OCR fell back or is near a usage limit.
  /// Returns null when nothing needs to be surfaced (the common case).
  String? _ocrNoteMessage(OcrOutcome outcome) {
    switch (outcome.note) {
      case 'own_key_near_limit':
        return 'Your Cloud Vision key is near its monthly free limit (80%).';
      case 'shared_near_limit':
        return 'Shared recognition quota is running low this month.';
    }
    // If we ended on ML Kit while the user expected higher quality, hint gently.
    if (outcome.engine == OcrEngineUsed.mlKit) {
      return 'Used on-device recognition. Add a Cloud Vision key in Settings for best results.';
    }
    return null;
  }

  Future<String?> _processWithOpenCV(String inputPath) async {
    const channel = MethodChannel('app.ixo.secbizcard/opencv');
    final outputPath = inputPath.replaceFirst('.jpg', '_processed.jpg');

    try {
      final result = await channel.invokeMethod('processCard', {
        'inputPath': inputPath,
        'outputPath': outputPath,
        'isVertical': _isVertical,
        'guideRect': _normalizedGuideRect(),
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

          // Pre-scan engine + shared-quota indicator (top-right).
          if (!_isProcessing && _preScanStatus != null)
            Positioned(
              top: 64,
              right: 16,
              child: _buildPreScanBadge(context, _preScanStatus!),
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
