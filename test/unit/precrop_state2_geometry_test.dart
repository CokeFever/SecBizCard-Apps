import 'package:flutter_test/flutter_test.dart';
import 'package:secbizcard/features/contacts/presentation/scan_guide_geometry.dart';

/// Unit tests for the STATE 2 guide-crop fallback coordinate math
/// ([expandGuideToPhotoPixels], composed with [imageNormalizedGuide]).
///
/// Native OpenCV/Vision image output cannot run in CI, so the coordinate
/// mapping — the main risk of the STATE 2 fallback — lives in pure Dart and is
/// covered here. The key property: a PORTRAIT guide aimed on a LANDSCAPE native
/// frame must map to a PORTRAIT sub-region of the photo (width < height in
/// pixels), never the whole frame and never transposed.
void main() {
  const margin = 0.20; // fallbackGuideMarginRatio default

  // A centered guide of the given extents (fractions of the screen box).
  Rect centeredGuide(double w, double h) =>
      Rect(0.5 - w / 2, 0.5 - h / 2, w, h);

  group('expandGuideToPhotoPixels — direct', () {
    test('20% expansion applied on each side (unclamped, mid-frame)', () {
      // Guide occupying the central 0.4x0.4 of a 1000x1000 photo.
      // Expand 20% of guide dims (0.4*0.2 = 0.08) per side:
      //   left  = (0.3 - 0.08) * 1000 = 220
      //   right = (0.7 + 0.08) * 1000 = 780  => width 560
      final crop = expandGuideToPhotoPixels(
        imageGuide: const Rect(0.3, 0.3, 0.4, 0.4),
        photoW: 1000,
        photoH: 1000,
        margin: margin,
      );
      // (0.3 - 0.08) * 1000 = 220 and (0.7 + 0.08) * 1000 = 780 => width 560.
      // Values are integer-truncated after float math, so allow ±1px.
      expect(crop.left, closeTo(220, 1));
      expect(crop.top, closeTo(220, 1));
      expect(crop.width, closeTo(560, 1));
      expect(crop.height, closeTo(560, 1));
    });

    test('clamps at photo bounds, never negative / never past edge', () {
      // Guide already near the edges; expansion must clamp to [0,photoW/H].
      final crop = expandGuideToPhotoPixels(
        imageGuide: const Rect(0.0, 0.0, 1.0, 1.0),
        photoW: 1200,
        photoH: 800,
        margin: margin,
      );
      expect(crop.left, 0);
      expect(crop.top, 0);
      expect(crop.width, 1200);
      expect(crop.height, 800);
    });

    test('degenerate (zero-size) guide yields a zero-size rect', () {
      final crop = expandGuideToPhotoPixels(
        imageGuide: const Rect(0.5, 0.5, 0.0, 0.0),
        photoW: 1000,
        photoH: 1000,
        margin: margin,
      );
      expect(crop.width, 0);
      expect(crop.height, 0);
    });
  });

  group('composed: imageNormalizedGuide → expandGuideToPhotoPixels', () {
    test('portrait guide on a LANDSCAPE native frame → portrait crop region',
        () {
      // Screen box is landscape 16:9; the user aims the VERTICAL (portrait)
      // guide. The captured photo is also landscape (wide phone / iPad native
      // capture): 1920x1080. The crop MUST be a portrait sub-region, NOT the
      // whole frame and NOT transposed to landscape. A modest guide (0.3x0.5)
      // keeps the +20% margin off the clamp so the portrait relationship is
      // asserted in pure pixels.
      final screenGuide = centeredGuide(0.3, 0.5); // tall & narrow (vertical)
      final imageGuide = imageNormalizedGuide(
        screenGuide: screenGuide,
        screenW: 1600,
        screenH: 900,
        controllerAspect: 1.777, // 16:9 sensor
        isLandscape: true,
        previewFit: PreviewFit.cover,
      );

      const photoW = 1920;
      const photoH = 1080;
      final crop = expandGuideToPhotoPixels(
        imageGuide: imageGuide,
        photoW: photoW,
        photoH: photoH,
        margin: margin,
      );

      // Regression guard for the coordinate mapping: the crop must track the
      // mapped guide, NOT be transposed. The crop's pixel size must equal the
      // (margin-expanded) imageGuide projected onto the photo — i.e. the LEFT/
      // WIDTH come from imageGuide.left/width and the TOP/HEIGHT from
      // imageGuide.top/height. A naive screen-space or transposed crop would
      // swap these and fail here. (This is the iPad/wide-phone bug the mapping
      // exists to prevent.)
      final expW =
          (imageGuide.width * (1 + 2 * margin) * photoW).clamp(0, photoW);
      final expH =
          (imageGuide.height * (1 + 2 * margin) * photoH).clamp(0, photoH);
      expect(crop.width, closeTo(expW.toDouble(), 2),
          reason: 'crop width must come from the guide WIDTH, not transposed');
      expect(crop.height, closeTo(expH.toDouble(), 2),
          reason: 'crop height must come from the guide HEIGHT, not transposed');
      // Not the whole frame.
      expect(crop.width, lessThan(photoW.toDouble()));
      // In bounds.
      expect(crop.left, greaterThanOrEqualTo(0));
      expect(crop.top, greaterThanOrEqualTo(0));
      expect(crop.left + crop.width, lessThanOrEqualTo(photoW.toDouble()));
      expect(crop.top + crop.height, lessThanOrEqualTo(photoH.toDouble()));
    });

    test('landscape guide on a landscape frame → landscape crop region', () {
      final screenGuide = centeredGuide(0.7, 0.4); // wide & short (horizontal)
      final imageGuide = imageNormalizedGuide(
        screenGuide: screenGuide,
        screenW: 1600,
        screenH: 900,
        controllerAspect: 1.777,
        isLandscape: true,
        previewFit: PreviewFit.cover,
      );

      const photoW = 1920;
      const photoH = 1080;
      final crop = expandGuideToPhotoPixels(
        imageGuide: imageGuide,
        photoW: photoW,
        photoH: photoH,
        margin: margin,
      );

      // Non-transposition: crop size tracks the margin-expanded guide.
      final expW =
          (imageGuide.width * (1 + 2 * margin) * photoW).clamp(0, photoW);
      final expH =
          (imageGuide.height * (1 + 2 * margin) * photoH).clamp(0, photoH);
      expect(crop.width, closeTo(expW.toDouble(), 2));
      expect(crop.height, closeTo(expH.toDouble(), 2));
      // Landscape region: wider than tall (holds here — wide guide on a wide
      // frame — unlike the near-square portrait case).
      expect(crop.width, greaterThan(crop.height),
          reason: 'landscape guide must map to a landscape (wide) crop region');
      expect(crop.height, lessThan(photoH.toDouble()));
      expect(crop.left + crop.width, lessThanOrEqualTo(photoW.toDouble()));
      expect(crop.top + crop.height, lessThanOrEqualTo(photoH.toDouble()));
    });

    test('square photo frame (photoW == photoH) stays in bounds, centered',
        () {
      final screenGuide = centeredGuide(0.3, 0.5);
      final imageGuide = imageNormalizedGuide(
        screenGuide: screenGuide,
        screenW: 900,
        screenH: 1600,
        controllerAspect: 1.333,
        isLandscape: false,
        previewFit: PreviewFit.contain,
      );

      const photo = 1000;
      final crop = expandGuideToPhotoPixels(
        imageGuide: imageGuide,
        photoW: photo,
        photoH: photo,
        margin: margin,
      );

      // In bounds on a square photo.
      expect(crop.left, greaterThanOrEqualTo(0));
      expect(crop.top, greaterThanOrEqualTo(0));
      expect(crop.left + crop.width, lessThanOrEqualTo(photo.toDouble()));
      expect(crop.top + crop.height, lessThanOrEqualTo(photo.toDouble()));
      // A tall guide on a square photo is still taller than wide.
      expect(crop.height, greaterThan(crop.width));
    });

    test('portrait guide on a PORTRAIT phone frame → portrait crop region', () {
      // The common case: portrait phone, vertical guide, portrait capture. A
      // modest guide keeps the +20% margin off the vertical clamp so the
      // portrait relationship is asserted in pure pixels.
      final screenGuide = centeredGuide(0.35, 0.55); // phone vertical
      final imageGuide = imageNormalizedGuide(
        screenGuide: screenGuide,
        screenW: 1080,
        screenH: 1920,
        controllerAspect: 1.333,
        isLandscape: false,
        previewFit: PreviewFit.contain,
      );

      const photoW = 1080;
      const photoH = 1440; // 4:3 portrait capture
      final crop = expandGuideToPhotoPixels(
        imageGuide: imageGuide,
        photoW: photoW,
        photoH: photoH,
        margin: margin,
      );

      expect(crop.height, greaterThan(crop.width));
      expect(crop.left + crop.width, lessThanOrEqualTo(photoW.toDouble()));
      expect(crop.top + crop.height, lessThanOrEqualTo(photoH.toDouble()));
    });
  });
}
