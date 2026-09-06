import 'package:flutter/material.dart';
import 'breakpoints.dart';

/// Centers its [child] and constrains it to a maximum readable width on large
/// screens (tablets, iPads, unfolded foldables), while remaining full-width on
/// phones.
///
/// Use this to wrap forms, detail content and other single-column layouts so
/// they don't stretch edge-to-edge and become hard to read on wide displays.
class AdaptiveContainer extends StatelessWidget {
  const AdaptiveContainer({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.maxContentWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    // On phones, don't add any constraint — keep the existing full-width look.
    if (context.screenWidth < Breakpoints.medium) {
      return padding != null ? Padding(padding: padding!, child: child) : child;
    }

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding != null
            ? Padding(padding: padding!, child: child)
            : child,
      ),
    );
  }
}
