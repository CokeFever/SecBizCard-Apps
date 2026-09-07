import 'dart:ui' show DisplayFeature, DisplayFeatureType;

import 'package:flutter/material.dart';

/// A two-pane (side-by-side) layout that renders consistently across every
/// large-screen form factor:
///
///  - iPad / iPad mini in landscape (and Stage Manager)
///  - iPhone Fold and Samsung Z Fold-class devices when unfolded
///  - Any other window wide enough for two panes
///
/// The two panes are always laid out the same way. The only device-specific
/// behaviour is the *seam* between them:
///
///  - On a foldable with a physical hinge, [TwoPane] reads the vertical
///    [DisplayFeature] (the hinge) from [MediaQuery] and aligns the divider to
///    it, leaving a gap the exact width of the hinge so no content is hidden
///    behind or split awkwardly across the fold.
///  - On devices without a hinge (iPad, iPhone Fold's seamless display,
///    ordinary wide windows) it falls back to a proportional split using
///    [startFlex] / [endFlex] with a thin divider.
///
/// This gives the "left/right column consistency" required across foldables
/// and tablets while still respecting a real hinge when one exists.
class TwoPane extends StatelessWidget {
  const TwoPane({
    super.key,
    required this.start,
    required this.end,
    this.startFlex = 1,
    this.endFlex = 1,
    this.dividerColor,
  });

  final Widget start;
  final Widget end;
  final int startFlex;
  final int endFlex;
  final Color? dividerColor;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final divider = dividerColor ?? Theme.of(context).dividerColor;

    // Look for a vertical separating hinge/fold that splits the screen into a
    // left and right region (a book-posture foldable). Horizontal folds
    // (tabletop posture) are ignored here because the app's two-pane layout is
    // horizontal.
    final DisplayFeature? verticalHinge = _findVerticalHinge(mq);

    if (verticalHinge != null) {
      return _HingeAwarePane(
        start: start,
        end: end,
        hinge: verticalHinge,
        screenWidth: mq.size.width,
        dividerColor: divider,
      );
    }

    // No hinge: proportional split (iPad, iPhone Fold, generic wide window).
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: startFlex, child: start),
        VerticalDivider(width: 1, thickness: 1, color: divider),
        Expanded(flex: endFlex, child: end),
      ],
    );
  }

  /// Returns the first vertical hinge/fold that separates the screen into a
  /// left and right region, or null if there is none.
  static DisplayFeature? _findVerticalHinge(MediaQueryData mq) {
    for (final feature in mq.displayFeatures) {
      final isSeparating = feature.type == DisplayFeatureType.hinge ||
          feature.type == DisplayFeatureType.fold;
      if (!isSeparating) continue;

      // A vertical seam runs top-to-bottom: its height is at least its width
      // (a zero-width hinge also counts). This distinguishes book posture
      // (left/right split) from tabletop posture (top/bottom split), which we
      // don't use for this horizontal two-pane layout.
      final isVertical = feature.bounds.height >= feature.bounds.width;
      if (isVertical) return feature;
    }
    return null;
  }
}

/// Lays out two panes on either side of a physical hinge, leaving the hinge
/// area empty so content is never occluded by the fold.
class _HingeAwarePane extends StatelessWidget {
  const _HingeAwarePane({
    required this.start,
    required this.end,
    required this.hinge,
    required this.screenWidth,
    required this.dividerColor,
  });

  final Widget start;
  final Widget end;
  final DisplayFeature hinge;
  final double screenWidth;
  final Color dividerColor;

  @override
  Widget build(BuildContext context) {
    final double hingeLeft = hinge.bounds.left;
    final double hingeWidth = hinge.bounds.width <= 0 ? 1 : hinge.bounds.width;
    final double rightStart = hinge.bounds.right;
    final double rightWidth = screenWidth - rightStart;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: hingeLeft, child: start),
        // The physical hinge gap — kept empty and painted with the divider
        // colour so the seam reads as an intentional separator.
        Container(width: hingeWidth, color: dividerColor),
        SizedBox(width: rightWidth, child: end),
      ],
    );
  }
}
