import 'dart:math' as math;

import 'package:flutter/material.dart';

/// WCAG relative luminance + contrast ratio helpers for token tests.
class Contrast {
  Contrast._();

  static double relativeLuminance(Color color) {
    double channel(double c) {
      final s = c / 255.0;
      return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = channel(color.r * 255);
    final g = channel(color.g * 255);
    final b = channel(color.b * 255);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  static double ratio(Color foreground, Color background) {
    final l1 = relativeLuminance(foreground);
    final l2 = relativeLuminance(background);
    final lighter = math.max(l1, l2);
    final darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  static bool passesNormalText(Color fg, Color bg) => ratio(fg, bg) >= 4.5;

  static bool passesLargeText(Color fg, Color bg) => ratio(fg, bg) >= 3.0;
}
