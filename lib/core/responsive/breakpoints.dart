import 'dart:ui' show DisplayFeatureType;

import 'package:flutter/widgets.dart';

/// Window size classes, aligned with Material 3 / Android window size class
/// guidance. These drive adaptive layout decisions across the app so that a
/// single set of thresholds is used everywhere (phones, unfolded foldables,
/// tablets and iPads).
///
/// Reference thresholds (width in logical pixels):
///  - compact:  < 600   → phones in portrait, folded foldables
///  - medium:   600–839  → small tablets, large phones landscape,
///                          many foldables when unfolded (portrait)
///  - expanded: >= 840   → tablets / iPad / unfolded foldables (landscape)
enum WindowSizeClass { compact, medium, expanded }

/// Breakpoint constants (logical pixels). Kept in one place so layout code and
/// tests can reference the same values.
class Breakpoints {
  const Breakpoints._();

  /// Below this width the UI is treated as a phone (single pane, bottom nav).
  static const double medium = 600;

  /// At or above this width the UI can show a two-pane / expanded layout
  /// (master-detail, navigation rail).
  static const double expanded = 840;

  /// Content that would otherwise stretch uncomfortably wide on large screens
  /// is constrained to this maximum readable width and centered.
  static const double maxContentWidth = 640;

  /// A slightly wider cap used for form-heavy screens on very large displays.
  static const double maxFormWidth = 720;
}

/// Resolves the [WindowSizeClass] for a given width.
WindowSizeClass windowSizeClassForWidth(double width) {
  if (width >= Breakpoints.expanded) return WindowSizeClass.expanded;
  if (width >= Breakpoints.medium) return WindowSizeClass.medium;
  return WindowSizeClass.compact;
}

/// Convenience extensions on [BuildContext] for adaptive layout decisions.
///
/// These read [MediaQuery] and therefore rebuild dependents when the window is
/// resized — which is exactly what we want for foldables (fold/unfold) and
/// iPad multitasking (Split View / Slide Over / Stage Manager).
extension ResponsiveContext on BuildContext {
  Size get screenSize => MediaQuery.sizeOf(this);

  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;

  WindowSizeClass get windowSizeClass =>
      windowSizeClassForWidth(screenWidth);

  /// Phone-class layout: single pane with bottom navigation.
  bool get isCompact => windowSizeClass == WindowSizeClass.compact;

  /// Medium width: transitional (e.g. small tablet / unfolded foldable
  /// portrait). Uses a navigation rail but usually still a single pane.
  bool get isMedium => windowSizeClass == WindowSizeClass.medium;

  /// Large width: tablet / iPad / unfolded foldable landscape. Enables the
  /// two-pane master-detail layout.
  bool get isExpanded => windowSizeClass == WindowSizeClass.expanded;

  /// True when a navigation rail (instead of a bottom bar) should be shown.
  bool get useNavigationRail => screenWidth >= Breakpoints.medium;

  /// True when the device currently has a vertical hinge/fold that splits the
  /// screen into left and right regions (book posture on a foldable).
  bool get hasVerticalHinge {
    for (final feature in MediaQuery.displayFeaturesOf(this)) {
      final separating = feature.type == DisplayFeatureType.hinge ||
          feature.type == DisplayFeatureType.fold;
      if (separating && feature.bounds.height >= feature.bounds.width) {
        return true;
      }
    }
    return false;
  }

  /// True for the "wide / passport-style" foldables that unfold to a near-4:3
  /// (roughly square) inner display — e.g. Galaxy Z Fold 8 Wide, Xiaomi 18
  /// Fold, the rumoured iPhone Fold, and tri-folds.
  ///
  /// These unfold to plenty of usable area for two panes even in portrait,
  /// where the raw width can sit just below the [Breakpoints.expanded]
  /// threshold. We detect them by a reasonably large minimum dimension paired
  /// with an aspect ratio genuinely close to 1 (0.8–1.25).
  ///
  /// The lower bound is deliberately 0.8 (not 0.75) so a standard 4:3 tablet in
  /// portrait — e.g. iPad mini at 768×1024 (aspect 0.75) — is NOT treated as
  /// near-square: those stay single-pane with a navigation rail in portrait and
  /// only switch to two panes in landscape. Passport-style foldables such as
  /// Galaxy Z Fold 8 Wide (~0.93) and the rumoured iPhone Fold (~0.97) unfold
  /// much closer to square and do qualify.
  bool get isNearSquareLargeScreen {
    final size = screenSize;
    final shortestSide = size.shortestSide;
    if (shortestSide < Breakpoints.medium) return false;
    final aspect = size.width / size.height;
    return aspect >= 0.8 && aspect <= 1.25;
  }

  /// True when a two-pane layout should be used.
  ///
  /// This intentionally keys off *usable area and posture*, not device type, so
  /// the same side-by-side columns appear consistently on:
  ///  - iPad / iPad mini in landscape (width >= expanded)
  ///  - iPhone Fold and other seamless wide foldables (width >= expanded, or
  ///    near-square when unfolded)
  ///  - Galaxy Z Fold-class / passport-style foldables and tri-folds, including
  ///    their near-square portrait state and book-posture hinge
  bool get useTwoPane =>
      screenWidth >= Breakpoints.expanded ||
      isNearSquareLargeScreen ||
      (hasVerticalHinge && screenWidth >= Breakpoints.medium);
}
