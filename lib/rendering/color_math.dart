import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// WCAG 2 relative luminance of an opaque color.
double relativeLuminance(Color c) {
  double channel(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG 2 contrast ratio, 1 (none) to 21 (black on white).
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a), lb = relativeLuminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// [top] drawn with [alpha] over the opaque [bottom].
Color blend(Color top, Color bottom, double alpha) => Color.from(
  alpha: 1,
  red: top.r * alpha + bottom.r * (1 - alpha),
  green: top.g * alpha + bottom.g * (1 - alpha),
  blue: top.b * alpha + bottom.b * (1 - alpha),
);

/// Smallest contrast of [text] against any of [backgrounds].
double minContrast(Color text, Iterable<Color> backgrounds) =>
    backgrounds.map((b) => contrastRatio(text, b)).reduce(math.min);

/// HSL to color with components in 0..1 (hue in degrees).
Color hsl(double hue, double saturation, double lightness) => HSLColor.fromAHSL(
  1,
  hue % 360,
  saturation.clamp(0, 1),
  lightness.clamp(0, 1),
).toColor();
