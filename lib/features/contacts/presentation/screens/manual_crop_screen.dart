import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class ManualCropScreen extends StatefulWidget {
  final String imagePath;
  final List<double> initialPoints; // [x1, y1, x2, y2, x3, y3, x4, y4]
  final double imageWidth;
  final double imageHeight;
  final bool isVertical;

  const ManualCropScreen({
    super.key,
    required this.imagePath,
    required this.initialPoints,
    required this.imageWidth,
    required this.imageHeight,
    this.isVertical = false,
  });

  @override
  State<ManualCropScreen> createState() => _ManualCropScreenState();
}

class _ManualCropScreenState extends State<ManualCropScreen> {
  // We store 4 normalized corners (0.0 - 1.0)
  // Order: 0:TL, 1:TR, 2:BR, 3:BL
  List<Offset> _corners = [];

  double _imgAspectRatio = 1.0;
  bool _isImageLoaded = false;
  double _realImageWidth = 1.0;
  double _realImageHeight = 1.0;

  bool _isProcessing = false;
  final TransformationController _transformationController =
      TransformationController();
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    debugPrint(
      'ManualCrop Init: Widget W=${widget.imageWidth}, H=${widget.imageHeight}',
    );

    // Default init while loading (Safeguard)
    _corners = [
      const Offset(0.2, 0.2), // TL
      const Offset(0.8, 0.2), // TR
      const Offset(0.8, 0.8), // BR
      const Offset(0.2, 0.8), // BL
    ];

    final imageProvider = FileImage(File(widget.imagePath));
    imageProvider
        .resolve(const ImageConfiguration())
        .addListener(
          ImageStreamListener((ImageInfo info, bool _) {
            if (!mounted) return;

            final w = info.image.width.toDouble();
            final h = info.image.height.toDouble();

            setState(() {
              _realImageWidth = w;
              _realImageHeight = h;
              _imgAspectRatio = w / h;
              _isImageLoaded = true;

              debugPrint(
                'ManualCrop Loaded: Real W=$w, H=$h, Ratio=$_imgAspectRatio',
              );

              // Initialize corners once we know real dimensions
              if (widget.initialPoints.length == 8) {
                // Try to map passed points to normalized space.
                // We assume passed points match the DECODED image orientation roughly.
                List<Offset> loadedCorners = [];
                for (int i = 0; i < 8; i += 2) {
                  double x = widget.initialPoints[i] / _realImageWidth;
                  double y = widget.initialPoints[i + 1] / _realImageHeight;
                  // Handle Swap if mismatched? For now, assume consistent.
                  loadedCorners.add(Offset(x, y));
                }

                // Validate: If any point is way off > 1.0 or < 0.0, it denotes mismatch.
                bool valid = true;
                for (var p in loadedCorners) {
                  if (p.dx < -0.1 || p.dx > 1.1 || p.dy < -0.1 || p.dy > 1.1) {
                    valid = false;
                  }
                }

                // Check if it is the Full Screen Fallback (0,0 -> 1,0 -> 1,1 -> 0,1)
                // This happens when Auto Detection fails. We prefer Smart Default over Full Screen.
                bool isFullScreen = false;
                if (valid && loadedCorners.length == 4) {
                  // Check corners proximity to 0,0 / 1,0 / 1,1 / 0,1
                  const tol = 0.05; // 5% tolerance
                  bool tl =
                      loadedCorners[0].dx < tol && loadedCorners[0].dy < tol;
                  bool tr =
                      loadedCorners[1].dx > (1 - tol) &&
                      loadedCorners[1].dy < tol;
                  bool br =
                      loadedCorners[2].dx > (1 - tol) &&
                      loadedCorners[2].dy > (1 - tol);
                  bool bl =
                      loadedCorners[3].dx < tol &&
                      loadedCorners[3].dy > (1 - tol);

                  if (tl && tr && br && bl) isFullScreen = true;
                }

                if (valid && !isFullScreen) {
                  _corners = loadedCorners;
                  debugPrint('ManualCrop: Using Initial Points');
                } else {
                  _setSmartDefault();
                  debugPrint(
                    'ManualCrop: Using Smart Default (FullScreen=$isFullScreen)',
                  );
                }
              } else {
                _setSmartDefault();
              }
            });
          }),
        );

    _transformationController.addListener(() {
      setState(() {
        _currentScale = _transformationController.value.getMaxScaleOnAxis();
      });
    });
  }

  void _setSmartDefault() {
    // Target Visual Aspect Ratio (Width / Height)
    final targetAspect = widget.isVertical ? (55.0 / 90.0) : (90.0 / 55.0);

    // We want: (normW * imgW) / (normH * imgH) = targetAspect
    // Implies: (normW / normH) = targetAspect / _imgAspectRatio
    final requiredNormRatio =
        targetAspect / (_imgAspectRatio <= 0 ? 1.0 : _imgAspectRatio);

    double normW, normH;

    // Logic to maximize size within safe margins (0.1 to 0.9)
    // Max dimension 0.8

    if (requiredNormRatio > 1.0) {
      // Needs to be wider in normalized space
      normW = 0.8;
      normH = normW / requiredNormRatio;

      // Check if H exceeds bounds (unlikely if ratio > 1 but possible)
      if (normH > 0.8) {
        normH = 0.8;
        normW = normH * requiredNormRatio;
      }
    } else {
      // Needs to be taller in normalized space
      normH = 0.8;
      normW = normH * requiredNormRatio;

      if (normW > 0.8) {
        normW = 0.8;
        normH = normW / requiredNormRatio;
      }
    }

    // Center it
    const cx = 0.5;
    const cy = 0.5;

    final halfW = normW / 2;
    final halfH = normH / 2;

    _corners = [
      Offset(cx - halfW, cy - halfH), // TL
      Offset(cx + halfW, cy - halfH), // TR
      Offset(cx + halfW, cy + halfH), // BR
      Offset(cx - halfW, cy + halfH), // BL
    ];
  }

  void _resetCrop() {
    setState(() {
      _setSmartDefault();
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _confirmCrop() async {
    setState(() => _isProcessing = true);

    final w = _realImageWidth;
    final h = _realImageHeight;

    // Flatten corners to [x1, y1, x2, y2, x3, y3, x4, y4]
    // 0:TL, 1:TR, 2:BR, 3:BL
    final pixelPoints = <double>[];
    for (var p in _corners) {
      pixelPoints.add(p.dx * w);
      pixelPoints.add(p.dy * h);
    }

    try {
      const channel = MethodChannel('app.ixo.secbizcard/opencv');
      final outputPath = widget.imagePath.replaceFirst('.jpg', '_cropped.jpg');

      final result = await channel.invokeMethod<bool>('manualCrop', {
        'inputPath': widget.imagePath,
        'outputPath': outputPath,
        'points': pixelPoints, // Now sending true Quad points
        'isVertical': widget.isVertical,
      });

      if (result == true) {
        if (mounted) context.pop(outputPath);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Crop Failed')));
        }
      }
    } catch (e) {
      debugPrint('Manual crop error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _updateCorner(int index, Offset delta) {
    if (index < 0 || index >= _corners.length) return;

    Offset p = _corners[index];
    double newX = (p.dx + delta.dx).clamp(0.0, 1.0);
    double newY = (p.dy + delta.dy).clamp(0.0, 1.0);

    _corners[index] = Offset(newX, newY);
  }

  @override
  Widget build(BuildContext context) {
    const handleSize = 40.0;
    const halfHandle = handleSize / 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adjust Area'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isProcessing ? null : _resetCrop,
            tooltip: 'Reset to Default',
          ),
          IconButton(
            icon: _isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.check),
            onPressed: _isProcessing ? null : _confirmCrop,
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: !_isImageLoaded
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final screenRatio =
                    constraints.maxWidth / constraints.maxHeight;
                double renderWidth, renderHeight;

                // Logic for BoxFit.cover
                if (screenRatio > _imgAspectRatio) {
                  renderWidth = constraints.maxWidth;
                  renderHeight = renderWidth / _imgAspectRatio;
                } else {
                  renderHeight = constraints.maxHeight;
                  renderWidth = renderHeight * _imgAspectRatio;
                }

                if (renderWidth < constraints.maxWidth) {
                  renderWidth = constraints.maxWidth;
                  renderHeight = renderWidth / _imgAspectRatio;
                }
                if (renderHeight < constraints.maxHeight) {
                  renderHeight = constraints.maxHeight;
                  renderWidth = renderHeight * _imgAspectRatio;
                }

                // Helper to get screen position for a corner
                Offset getScreenPos(int index) {
                  if (index >= _corners.length) return Offset.zero;
                  return Offset(
                    _corners[index].dx * renderWidth,
                    _corners[index].dy * renderHeight,
                  );
                }

                return InteractiveViewer(
                  transformationController: _transformationController,
                  boundaryMargin: EdgeInsets.zero,
                  minScale: 1.0,
                  maxScale: 1.0,
                  panEnabled: false,
                  scaleEnabled: false,
                  child: Center(
                    child: SizedBox(
                      width: renderWidth,
                      height: renderHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Image.file(
                            File(widget.imagePath),
                            width: renderWidth,
                            height: renderHeight,
                            fit: BoxFit.contain,
                          ),
                          CustomPaint(
                            size: Size(renderWidth, renderHeight),
                            painter: _CropOverlayPainter(
                              corners: _corners,
                              imageSize: Size(renderWidth, renderHeight),
                              scale: _currentScale,
                            ),
                          ),
                          // 4 Handles (Quad)
                          for (int i = 0; i < 4; i++)
                            Positioned(
                              left: getScreenPos(i).dx - halfHandle,
                              top: getScreenPos(i).dy - halfHandle,
                              child: GestureDetector(
                                onPanUpdate: (details) {
                                  setState(() {
                                    double dx =
                                        (details.delta.dx / _currentScale) /
                                        renderWidth;
                                    double dy =
                                        (details.delta.dy / _currentScale) /
                                        renderHeight;
                                    _updateCorner(i, Offset(dx, dy));
                                  });
                                },
                                child: Container(
                                  width: handleSize,
                                  height: handleSize,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.amberAccent,
                                      width: 3,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.crop_free,
                                      size: 20,
                                      color: Colors.amberAccent,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  final List<Offset> corners; // Normalized [TL, TR, BR, BL]
  final Size imageSize;
  final double scale;

  _CropOverlayPainter({
    required this.corners,
    required this.imageSize,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length != 4) return;

    final paint = Paint()
      ..color = Colors.amberAccent
      ..strokeWidth =
          3.0 /
          scale // Kept logic for scale, though scale is 1
      ..style = PaintingStyle.stroke;

    final path = Path();

    // Map normalized points to screen points
    final p0 = Offset(
      corners[0].dx * imageSize.width,
      corners[0].dy * imageSize.height,
    );
    final p1 = Offset(
      corners[1].dx * imageSize.width,
      corners[1].dy * imageSize.height,
    );
    final p2 = Offset(
      corners[2].dx * imageSize.width,
      corners[2].dy * imageSize.height,
    );
    final p3 = Offset(
      corners[3].dx * imageSize.width,
      corners[3].dy * imageSize.height,
    );

    path.moveTo(p0.dx, p0.dy);
    path.lineTo(p1.dx, p1.dy);
    path.lineTo(p2.dx, p2.dy);
    path.lineTo(p3.dx, p3.dy);
    path.close();

    canvas.drawPath(path, paint);

    // Dark overlay is trickier with a Polygon.
    final outerPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    // EvenOdd fill rule makes hole punch easy
    final outerPath = Path()..fillType = PathFillType.evenOdd;

    outerPath.addRect(Rect.fromLTWH(0, 0, imageSize.width, imageSize.height));
    outerPath.addPath(path, Offset.zero);

    canvas.drawPath(outerPath, outerPaint);
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter old) {
    return old.corners != corners || old.imageSize != imageSize;
  }
}
