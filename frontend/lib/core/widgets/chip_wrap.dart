import 'package:flutter/material.dart';

/// Full-width chip grid: wraps to the next line in even columns.
class ChipWrap extends StatelessWidget {
  const ChipWrap({
    super.key,
    required this.children,
    this.columns = 2,
    this.spacing = 8,
  });

  final List<Widget> children;
  final int columns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = columns.clamp(1, 6);
        final width = (constraints.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}
