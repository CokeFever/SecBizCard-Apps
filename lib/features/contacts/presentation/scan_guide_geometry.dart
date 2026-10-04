import 'dart:math' as math;

/// Pure, `BuildContext`-free geometry for the scan guide → captured-photo
/// coordinate mapping. Lives in its own module (no Flutter import, `dart:math`
/// only) so [imageNormalizedGuide] is unit-testable without a widget tree.
///
/// See design.md §2a "Dart: cover-crop correction".

/// A minimal rectangle value type (fractions or pixels — the caller decides),
/// deliberately independent of `dart:ui.Rect` to keep this file Flutter-free.
class Rect {
  const Rect(this.left, this.top, this.width, this.height);

  final double left;
  final double top;
  final double width;
  final double height;

  @override
  String toString() => 'Rect($left, $top, $width, $height)';
}

/// How the live camera preview is laid onto the on-screen box.
///
///  - [cover]: large-screen (`_CoverCameraPreview`) — the sensor frame is
///    scaled to FILL the box and the overflow is clipped (offsets <= 0).
///  - [contain]: phone (`AspectRatio` + `Center`) — the frame is scaled to FIT
///    inside the box and centered, with letterbox bars (offsets >= 0).
enum PreviewFit { cover, contain }

/// Converts a SCREEN-normalized centered guide rect into an IMAGE-normalized
/// rect (fraction of the full captured photo), accounting for how the live
/// preview maps onto the screen.
///
/// [screenGuide]      : {left,top,width,height} in 0..1 of the screen box.
/// [screenW],[screenH]: logical screen box size (same box the painter used).
/// [controllerAspect] : camera's sensor long/short ratio
///                      (`CameraController.value.aspectRatio`; orientation-free).
/// [isLandscape]      : screen box orientation (width > height).
/// [previewFit]       : how the preview is laid onto the screen box
///                      (see [PreviewFit]).
///
/// Returns an IMAGE-normalized rect, clamped to [0,1], in the SAME upright axis
/// the native side works in (top-left origin, image already EXIF-upright).
///
/// The guide mode (vertical/horizontal) and device class only change the INPUT
/// [screenGuide] fractions (produced by `_normalizedGuideRect`); the transform
/// treats the rect generically. [isLandscape] flips `previewAspect` to match
/// `_CoverCameraPreview`.
Rect imageNormalizedGuide({
  required Rect screenGuide,
  required double screenW,
  required double screenH,
  required double controllerAspect,
  required bool isLandscape,
  required PreviewFit previewFit,
}) {
  // Preview content aspect, exactly as `_CoverCameraPreview` defines it.
  final double previewAspect =
      isLandscape ? controllerAspect : 1.0 / controllerAspect;
  final double boxAspect = screenW / screenH;

  double contentW;
  double contentH;
  switch (previewFit) {
    case PreviewFit.cover:
      // Scale to FILL the box; overflow is clipped → offsets <= 0.
      if (boxAspect > previewAspect) {
        // Content overflows vertically.
        contentW = screenW;
        contentH = screenW / previewAspect;
      } else {
        // Content overflows horizontally.
        contentH = screenH;
        contentW = screenH * previewAspect;
      }
      break;
    case PreviewFit.contain:
      // Scale to FIT inside the box; letterbox bars → offsets >= 0.
      if (boxAspect > previewAspect) {
        // Letterbox on left/right.
        contentH = screenH;
        contentW = screenH * previewAspect;
      } else {
        // Letterbox on top/bottom.
        contentW = screenW;
        contentH = screenW / previewAspect;
      }
      break;
  }

  final double offsetX = (screenW - contentW) / 2.0;
  final double offsetY = (screenH - contentH) / 2.0;

  // Screen-fraction guide → screen pixels → image fractions. Because the
  // captured photo is the full sensor frame with the same aspect as the preview
  // content, the content fraction equals the image fraction.
  final double imgLeft = (screenGuide.left * screenW - offsetX) / contentW;
  final double imgTop = (screenGuide.top * screenH - offsetY) / contentH;
  final double imgW = screenGuide.width * screenW / contentW;
  final double imgH = screenGuide.height * screenH / contentH;

  return Rect(
    _clamp01(imgLeft),
    _clamp01(imgTop),
    _clamp01(imgW),
    _clamp01(imgH),
  );
}

double _clamp01(double v) => math.max(0.0, math.min(1.0, v));
