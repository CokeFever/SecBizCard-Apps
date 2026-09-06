import 'dart:ui' show DisplayFeature, DisplayFeatureType, DisplayFeatureState;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secbizcard/core/responsive/breakpoints.dart';

/// Builds a widget under a specific MediaQuery so we can probe the
/// ResponsiveContext extension getters for a given device profile.
Future<_Probe> _probe(
  WidgetTester tester, {
  required Size size,
  List<DisplayFeature> displayFeatures = const [],
}) async {
  late _Probe result;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, displayFeatures: displayFeatures),
      child: Builder(
        builder: (context) {
          result = _Probe(
            sizeClass: context.windowSizeClass,
            useNavigationRail: context.useNavigationRail,
            useTwoPane: context.useTwoPane,
            hasVerticalHinge: context.hasVerticalHinge,
            isNearSquareLargeScreen: context.isNearSquareLargeScreen,
          );
          return const SizedBox();
        },
      ),
    ),
  );
  return result;
}

class _Probe {
  _Probe({
    required this.sizeClass,
    required this.useNavigationRail,
    required this.useTwoPane,
    required this.hasVerticalHinge,
    required this.isNearSquareLargeScreen,
  });
  final WindowSizeClass sizeClass;
  final bool useNavigationRail;
  final bool useTwoPane;
  final bool hasVerticalHinge;
  final bool isNearSquareLargeScreen;
}

/// A vertical hinge splitting the screen left/right (book posture foldable).
DisplayFeature _verticalHinge(double x, double height) => DisplayFeature(
      bounds: Rect.fromLTWH(x, 0, 0, height),
      type: DisplayFeatureType.hinge,
      state: DisplayFeatureState.postureFlat,
    );

void main() {
  group('windowSizeClassForWidth', () {
    test('classifies widths into compact / medium / expanded', () {
      expect(windowSizeClassForWidth(360), WindowSizeClass.compact);
      expect(windowSizeClassForWidth(599.9), WindowSizeClass.compact);
      expect(windowSizeClassForWidth(600), WindowSizeClass.medium);
      expect(windowSizeClassForWidth(839.9), WindowSizeClass.medium);
      expect(windowSizeClassForWidth(840), WindowSizeClass.expanded);
      expect(windowSizeClassForWidth(1280), WindowSizeClass.expanded);
    });
  });

  group('phones and folded foldables → single pane', () {
    testWidgets('typical phone portrait stays compact, no rail, no two-pane',
        (tester) async {
      final p = await _probe(tester, size: const Size(390, 844));
      expect(p.sizeClass, WindowSizeClass.compact);
      expect(p.useNavigationRail, isFalse);
      expect(p.useTwoPane, isFalse);
    });

    testWidgets('Z Fold outer (folded) narrow cover screen stays compact',
        (tester) async {
      final p = await _probe(tester, size: const Size(360, 900));
      expect(p.useTwoPane, isFalse);
      expect(p.useNavigationRail, isFalse);
    });
  });

  group('iPad / iPad mini', () {
    testWidgets('iPad mini portrait → rail, but not two-pane', (tester) async {
      // iPad mini portrait is ~768 wide (medium), tall aspect → single pane.
      final p = await _probe(tester, size: const Size(768, 1024));
      expect(p.useNavigationRail, isTrue);
      expect(p.useTwoPane, isFalse);
    });

    testWidgets('iPad / iPad mini landscape → two-pane', (tester) async {
      final p = await _probe(tester, size: const Size(1024, 768));
      expect(p.useTwoPane, isTrue);
      expect(p.useNavigationRail, isTrue);
    });
  });

  group('wide / passport-style foldables unfolded (near-square)', () {
    testWidgets('Z Fold 8 Wide-style near-square portrait → two-pane',
        (tester) async {
      // Unfolds to a roughly 4:3 / near-square inner display in portrait,
      // width just under the raw 840 expanded threshold.
      final p = await _probe(tester, size: const Size(820, 880));
      expect(p.isNearSquareLargeScreen, isTrue);
      expect(p.useTwoPane, isTrue);
    });

    testWidgets('iPhone Fold-style seamless near-square (no hinge) → two-pane',
        (tester) async {
      final p = await _probe(tester, size: const Size(800, 820));
      expect(p.hasVerticalHinge, isFalse);
      expect(p.useTwoPane, isTrue);
    });
  });

  group('book-posture foldable with physical hinge', () {
    testWidgets('vertical hinge at medium width → two-pane + hinge detected',
        (tester) async {
      final p = await _probe(
        tester,
        size: const Size(700, 900),
        displayFeatures: [_verticalHinge(350, 900)],
      );
      expect(p.hasVerticalHinge, isTrue);
      expect(p.useTwoPane, isTrue);
    });
  });
}
