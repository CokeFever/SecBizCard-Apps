import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:secbizcard/features/contacts/presentation/screens/scan_card_screen.dart';

/// Scoped layout assertions for [landscapeLeftColumnWidth] — the pure width
/// helper that keeps the landscape toggle+hint column clear of the centered
/// guide frame.
///
/// IMPORTANT: these are claims about the ENUMERATED real large-screen landscape
/// form factors below, NOT a universal property over all `Size`s. The helper
/// clamps to `[160, 360]`, so on a hypothetical ultra-narrow large-screen
/// landscape the clamp floor could exceed the available gutter; the second
/// group (`avail >= 184`) is the explicit guard that this does not happen on
/// any size we actually ship against. Landscape only ever occurs on large
/// screens (phones are portrait-locked), so these sizes represent the real
/// matrix: iPad mini, iPad 11", and an unfolded Samsung Z Fold.
void main() {
  // The enumerated real matrix sizes (logical px, landscape).
  const iPadMini = Size(1133, 744);
  const iPad11 = Size(1194, 834);
  // Representative Samsung Z Fold / foldable UNFOLDED landscape (near-square
  // inner display in landscape). Stands in for the "unfolded foldable" row of
  // the design's verification matrix.
  const zFoldUnfolded = Size(1080, 800);

  const matrix = <String, Size>{
    'iPad mini': iPadMini,
    'iPad 11"': iPad11,
    'Z Fold unfolded': zFoldUnfolded,
  };

  // Mirrors the helper's internal geometry: the horizontal (widest) guide is
  // 0.75 * shortestSide, centered, so its left edge is this far from the left.
  double frameLeftFor(Size size) =>
      (size.width - 0.75 * size.shortestSide) / 2;

  group('landscapeLeftColumnWidth — no-overlap (enumerated sizes only)', () {
    matrix.forEach((name, size) {
      test('$name: column + inset + gap clears the frame', () {
        final width = landscapeLeftColumnWidth(size);
        final frameLeft = frameLeftFor(size);
        // 16 = left inset, 24 = gap before the frame (same constants as the
        // helper). The column must end before the frame's left edge.
        expect(
          width + 16 + 24 <= frameLeft,
          isTrue,
          reason: '$name: width=$width, frameLeft=$frameLeft '
              '(width + 40 must be <= frameLeft)',
        );
      });
    });
  });

  group('landscapeLeftColumnWidth — floor-vs-available guard', () {
    matrix.forEach((name, size) {
      test('$name: available gutter >= 184 (clamp floor + gap)', () {
        // avail is the raw gutter before clamping: frameLeft - 16 - 24.
        final avail = frameLeftFor(size) - 16 - 24;
        // 184 = 160 (clamp floor) + 24 (gap). If avail dipped below this, the
        // clamp floor could crowd the frame on this size.
        expect(
          avail >= 184,
          isTrue,
          reason: '$name: avail=$avail must be >= 184',
        );
      });
    });
  });
}
