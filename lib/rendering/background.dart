import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../core/seeded_random.dart';
import 'color_math.dart';

enum BackgroundStyle { linear, radial, solid }

enum PatternStyle { none, dots, stripes, rings, blobs, waves }

/// A fully described, code-generated background. Built only from a seed,
/// so the same day and category always give the same picture.
class BackgroundSpec {
  const BackgroundSpec({
    required this.style,
    required this.colors,
    required this.angle,
    required this.focus,
    required this.pattern,
    required this.patternColor,
    required this.patternAlpha,
    required this.patternSeed,
  });

  /// Seeded by the day and the category, as the spec requires. The template
  /// only changes the layout on top.
  factory BackgroundSpec.forDay(int day, String categoryId) =>
      BackgroundSpec.fromRandom(
        SeededRandom.of(['background', day, categoryId]),
      );

  factory BackgroundSpec.fromRandom(SeededRandom r) {
    final hue = r.range(0, 360);
    // Mostly deep or soft palettes; mid tones are rarer because they are
    // the hardest to read on.
    final tone = r.nextDouble();
    final baseLightness = tone < 0.5
        ? r.range(0.12, 0.30)
        : tone < 0.85
        ? r.range(0.72, 0.88)
        : r.range(0.42, 0.58);
    final saturation = r.range(0.35, 0.75);
    final hueShift = r.range(25, 70) * (r.nextBool() ? 1 : -1);
    final count = r.nextDouble() < 0.4 ? 3 : 2;
    final colors = [
      for (var i = 0; i < count; i++)
        hsl(
          hue + hueShift * i / (count - 1),
          saturation + r.range(-0.1, 0.1),
          baseLightness + r.range(-0.08, 0.08),
        ),
    ];
    final style = r.pick(BackgroundStyle.values);
    final pattern = r.pick(PatternStyle.values);
    final dark = relativeLuminance(colors.first) < 0.18;
    return BackgroundSpec(
      style: style,
      colors: style == BackgroundStyle.solid ? [colors.first] : colors,
      angle: r.range(0, math.pi * 2),
      focus: Offset(r.range(0.15, 0.85), r.range(0.1, 0.5)),
      pattern: pattern,
      patternColor: dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
      patternAlpha: pattern == PatternStyle.none ? 0 : r.range(0.05, 0.12),
      patternSeed: r.nextUint32(),
    );
  }

  final BackgroundStyle style;
  final List<Color> colors;

  /// Direction of a linear gradient, radians.
  final double angle;

  /// Center of a radial gradient, as a fraction of the canvas.
  final Offset focus;
  final PatternStyle pattern;
  final Color patternColor;
  final double patternAlpha;
  final int patternSeed;

  /// Every color that can appear behind the text, worst cases included.
  /// Used to pick a readable text color without reading pixels back.
  List<Color> get possibleColors => [
    ...colors,
    // Gradients interpolate between stops; the midpoints matter too.
    for (var i = 0; i + 1 < colors.length; i++)
      Color.lerp(colors[i], colors[i + 1], 0.5)!,
    if (patternAlpha > 0)
      for (final c in colors) blend(patternColor, c, patternAlpha * _blobBoost),
  ];

  /// Blobs overlap, so their tint can stack up to about twice the alpha.
  double get _blobBoost => pattern == PatternStyle.blobs ? 2 : 1;

  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint();
    switch (style) {
      case BackgroundStyle.solid:
        paint.color = colors.first;
      case BackgroundStyle.linear:
        final center = rect.center;
        final half = size.longestSide / 2;
        final d = Offset(math.cos(angle), math.sin(angle)) * half;
        paint.shader = ui.Gradient.linear(
          center - d,
          center + d,
          colors,
          _stops,
        );
      case BackgroundStyle.radial:
        paint.shader = ui.Gradient.radial(
          Offset(focus.dx * size.width, focus.dy * size.height),
          size.longestSide * 0.95,
          colors,
          _stops,
        );
    }
    canvas.drawRect(rect, paint);
    _paintPattern(canvas, size);
  }

  List<double> get _stops => [
    for (var i = 0; i < colors.length; i++) i / (colors.length - 1),
  ];

  void _paintPattern(Canvas canvas, Size size) {
    if (pattern == PatternStyle.none) return;
    final r = SeededRandom(patternSeed);
    final w = size.width, h = size.height;
    final ink = Paint()..color = patternColor.withValues(alpha: patternAlpha);
    switch (pattern) {
      case PatternStyle.none:
        return;
      case PatternStyle.dots:
        final step = w * r.range(0.05, 0.08);
        final radius = step * r.range(0.07, 0.12);
        for (var y = step / 2; y < h; y += step) {
          for (var x = step / 2; x < w; x += step) {
            canvas.drawCircle(Offset(x, y), radius, ink);
          }
        }
      case PatternStyle.stripes:
        final step = w * r.range(0.07, 0.12);
        ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = step * r.range(0.15, 0.3);
        final slope = r.nextBool() ? 1.0 : -1.0;
        for (var x = -h; x < w + h; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x + slope * h, h), ink);
        }
      case PatternStyle.rings:
        final c = Offset(r.range(0, w), r.range(0, h * 0.6));
        final step = w * r.range(0.06, 0.1);
        ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = step * 0.1;
        for (var rad = step; rad < size.longestSide * 1.4; rad += step) {
          canvas.drawCircle(c, rad, ink);
        }
      case PatternStyle.blobs:
        ink.maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.08);
        final n = 3 + r.nextInt(3);
        for (var i = 0; i < n; i++) {
          canvas.drawCircle(
            Offset(r.range(-0.1, 1.1) * w, r.range(-0.1, 1.1) * h),
            w * r.range(0.25, 0.55),
            ink,
          );
        }
      case PatternStyle.waves:
        ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * r.range(0.006, 0.012);
        final amplitude = h * r.range(0.01, 0.025);
        final length = w * r.range(0.5, 1.0);
        final step = h * r.range(0.035, 0.06);
        for (var y = 0.0; y < h + step; y += step) {
          final path = Path()..moveTo(0, y);
          for (var x = 0.0; x <= w; x += w / 48) {
            path.lineTo(x, y + math.sin(x / length * math.pi * 2) * amplitude);
          }
          canvas.drawPath(path, ink);
        }
    }
  }
}
