import 'package:flutter/material.dart';

/// Breakpoints shared by all screens.
class Breakpoints {
  static const double compact = 600; // phones
  static const double medium = 905; // tablets / small laptops
  static const double expanded = 1240; // desktops

  static bool isCompact(BuildContext c) => MediaQuery.sizeOf(c).width < compact;
  static bool isMedium(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    return w >= compact && w < medium;
  }

  static bool isExpanded(BuildContext c) => MediaQuery.sizeOf(c).width >= medium;

  /// Number of grid columns for card lists at the current width.
  static int columns(BuildContext c, {double minTileWidth = 340, int max = 3}) {
    final w = MediaQuery.sizeOf(c).width;
    return (w / minTileWidth).floor().clamp(1, max);
  }

  /// Horizontal page padding that grows with the screen.
  static double gutter(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    if (w < compact) return 16;
    if (w < medium) return 24;
    return 32;
  }
}

/// Centers [child] and caps its width so forms and lists stay readable on
/// tablets and desktops while filling the screen on phones.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveCenter({super.key, required this.child, this.maxWidth = 760, this.padding});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding == null ? child : Padding(padding: padding!, child: child),
      ),
    );
  }
}

/// Lays out [children] as a responsive grid: 1 column on phones, more on wider screens.
class ResponsiveWrapGrid extends StatelessWidget {
  final List<Widget> children;
  final double minTileWidth;
  final int maxColumns;
  final double spacing;

  const ResponsiveWrapGrid({
    super.key,
    required this.children,
    this.minTileWidth = 340,
    this.maxColumns = 3,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = (constraints.maxWidth / minTileWidth).floor().clamp(1, maxColumns);
        final tileWidth = (constraints.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final c in children) SizedBox(width: tileWidth, child: c)],
        );
      },
    );
  }
}
