import 'package:flutter_test/flutter_test.dart';
import 'package:secbizcard/features/contacts/presentation/scan_guide_geometry.dart';

/// Unit tests for [imageNormalizedGuide] (design §2a "Testability").
///
/// Covers the cross-product {cover, contain} × {landscape, portrait} ×
/// {vertical guide, horizontal guide} × controllerAspect ∈ {1.333, 1.777}.
void main() {
  const eps = 1e-9;

  // A centered guide of the given half-extents (fractions of the screen box).
  Rect centeredGuide(double w, double h) =>
      Rect(0.5 - w / 2, 0.5 - h / 2, w, h);

  // The two representative sensor aspect ratios.
  const aspects = <double>[1.333, 1.777];

  // Guide "modes" expressed as screen-normalized centered rects. The transform
  // treats the rect generically; these only vary the INPUT fractions.
  final guideModes = <String, Rect>{
    // Vertical card guide (tall & narrow).
    'vertical': centeredGuide(0.4, 0.7),
    // Horizontal card guide (wide & short).
    'horizontal': centeredGuide(0.7, 0.4),
  };

  // Screen boxes for each orientation (same box the painter uses).
  const landscapeBox = [1600.0, 900.0]; // 16:9 landscape
  const portraitBox = [900.0, 1600.0]; // 9:16 portrait

  for (final fit in PreviewFit.values) {
    for (final landscape in [true, false]) {
      final box = landscape ? landscapeBox : portraitBox;
      for (final aspect in aspects) {
        for (final entry in guideModes.entries) {
          test(
            'within [0,1] & center preserved — '
            'fit=${fit.name} landscape=$landscape aspect=$aspect '
            'mode=${entry.key}',
            () {
              final r = imageNormalizedGuide(
                screenGuide: entry.value,
                screenW: box[0],
                screenH: box[1],
                controllerAspect: aspect,
                isLandscape: landscape,
                previewFit: fit,
              );

              // (a) outputs within [0,1].
              expect(r.left, inInclusiveRange(0.0, 1.0));
              expect(r.top, inInclusiveRange(0.0, 1.0));
              expect(r.width, inInclusiveRange(0.0, 1.0));
              expect(r.height, inInclusiveRange(0.0, 1.0));

              // (b) center preserved. NOTE: this is a PURE Dart pre-guard
              // property that holds under the design's input assumption
              // capture-aspect == controllerAspect. It does NOT, by itself,
              // guarantee physical on-device centering when the real capture
              // aspect diverges from controllerAspect — that runtime case is
              // caught separately by the native captureAspect vs
              // previewAspectUsed guard (NIT/Finding 5), not by this test.
              //
              // Only assert centering when the mapped rect is not clamped at a
              // boundary (clamping legitimately breaks centering, e.g. a guide
              // partially outside the covered content region).
              final unclampedH =
                  r.left > eps && r.left + r.width < 1.0 - eps;
              final unclampedV =
                  r.top > eps && r.top + r.height < 1.0 - eps;
              if (unclampedH) {
                expect(r.left + r.width / 2, closeTo(0.5, 1e-9));
              }
              if (unclampedV) {
                expect(r.top + r.height / 2, closeTo(0.5, 1e-9));
              }
            },
          );
        }
      }
    }
  }

  // (c) Hand-computed known cases, one per fit.
  group('hand-computed cases', () {
    test('cover: 16:9 box, controllerAspect 1.333, landscape', () {
      // boxAspect = 1600/900 = 1.777... > previewAspect = 1.333
      //   => contentW = 1600, contentH = 1600/1.333 = 1200.075...
      //      offsetX = 0, offsetY = (900 - 1200.075)/2 = -150.0375
      // guide left=0.4 width=0.2 top=0.4 height=0.2:
      //   imgLeft = (0.4*1600 - 0)/1600            = 0.4
      //   imgW    = 0.2*1600/1600                  = 0.2
      //   imgTop  = (0.4*900 - (-150.0375))/1200.075
      //   imgH    = 0.2*900/1200.075
      const screenW = 1600.0, screenH = 900.0, aspect = 1.333;
      const contentH = screenW / aspect; // 1200.0750...
      const offsetY = (screenH - contentH) / 2.0;
      const expectedTop = (0.4 * screenH - offsetY) / contentH;
      const expectedH = 0.2 * screenH / contentH;

      final r = imageNormalizedGuide(
        screenGuide: const Rect(0.4, 0.4, 0.2, 0.2),
        screenW: screenW,
        screenH: screenH,
        controllerAspect: aspect,
        isLandscape: true,
        previewFit: PreviewFit.cover,
      );

      expect(r.left, closeTo(0.4, 1e-9));
      expect(r.width, closeTo(0.2, 1e-9));
      expect(r.top, closeTo(expectedTop, 1e-9));
      expect(r.height, closeTo(expectedH, 1e-9));
      // Sanity: still centered vertically.
      expect(r.top + r.height / 2, closeTo(0.5, 1e-9));
    });

    test('contain: 9:16 phone box, controllerAspect 1.333, portrait', () {
      // portrait => previewAspect = 1/1.333 = 0.7501...
      // boxAspect = 900/1600 = 0.5625 < previewAspect => letterbox top/bottom:
      //   contentW = screenW = 900, contentH = screenW/previewAspect
      //   previewAspect = 1/1.333, so contentH = 900 * 1.333 = 1199.7
      //   offsetX = 0, offsetY = (1600 - 1199.7)/2 = 200.15
      // guide left=0.4 width=0.2 top=0.4 height=0.2:
      //   imgLeft = (0.4*900 - 0)/900 = 0.4
      //   imgW    = 0.2*900/900       = 0.2
      //   imgTop  = (0.4*1600 - 200.15)/1199.7
      //   imgH    = 0.2*1600/1199.7
      const screenW = 900.0, screenH = 1600.0, aspect = 1.333;
      const previewAspect = 1.0 / aspect;
      const contentH = screenW / previewAspect; // 1199.7
      const offsetY = (screenH - contentH) / 2.0;
      const expectedTop = (0.4 * screenH - offsetY) / contentH;
      const expectedH = 0.2 * screenH / contentH;

      final r = imageNormalizedGuide(
        screenGuide: const Rect(0.4, 0.4, 0.2, 0.2),
        screenW: screenW,
        screenH: screenH,
        controllerAspect: aspect,
        isLandscape: false,
        previewFit: PreviewFit.contain,
      );

      expect(r.left, closeTo(0.4, 1e-9));
      expect(r.width, closeTo(0.2, 1e-9));
      expect(r.top, closeTo(expectedTop, 1e-9));
      expect(r.height, closeTo(expectedH, 1e-9));
      expect(r.top + r.height / 2, closeTo(0.5, 1e-9));
    });
  });

  // (d) Monotonicity: a wider screen guide yields a wider-or-equal image guide.
  group('monotonicity', () {
    for (final fit in PreviewFit.values) {
      for (final landscape in [true, false]) {
        final box = landscape ? landscapeBox : portraitBox;
        test('wider screen guide => wider-or-equal image guide — '
            'fit=${fit.name} landscape=$landscape', () {
          double imgWidthFor(double w) => imageNormalizedGuide(
                screenGuide: centeredGuide(w, 0.4),
                screenW: box[0],
                screenH: box[1],
                controllerAspect: 1.333,
                isLandscape: landscape,
                previewFit: fit,
              ).width;

          final narrow = imgWidthFor(0.3);
          final mid = imgWidthFor(0.5);
          final wide = imgWidthFor(0.7);
          expect(mid, greaterThanOrEqualTo(narrow - eps));
          expect(wide, greaterThanOrEqualTo(mid - eps));
        });
      }
    }
  });
}
