import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// One paragraph of a wallpaper, sized relative to the canvas width.
class TextBlock {
  const TextBlock(
    this.text, {
    required this.fontFamily,
    required this.size,
    this.weight = 400,
    this.lineHeight = 1.25,
    this.letterSpacing = 0,
    this.opacity = 1,
    this.gapBefore = 0,
  });

  final String text;
  final String fontFamily;

  /// Font size as a fraction of the canvas width.
  final double size;

  /// Variable font weight axis value (100–900).
  final double weight;
  final double lineHeight;

  /// Letter spacing in ems.
  final double letterSpacing;
  final double opacity;

  /// Space above this block, as a fraction of the canvas width.
  final double gapBefore;
}

/// Blocks laid out at a common scale that fits the box.
class FittedText {
  FittedText(this.paragraphs, this.gaps, this.scale, this.overflowed);

  final List<ui.Paragraph> paragraphs;

  /// Space above each paragraph, in pixels.
  final List<double> gaps;
  final double scale;

  /// True only if the text did not fit even at the minimum scale.
  final bool overflowed;

  double get height {
    var h = 0.0;
    for (var i = 0; i < paragraphs.length; i++) {
      h += gaps[i] + paragraphs[i].height;
    }
    return h;
  }

  double get width =>
      paragraphs.fold(0, (w, p) => p.longestLine > w ? p.longestLine : w);

  /// Paints the blocks top-down from [origin]; returns each block's rect.
  List<Rect> paint(Canvas canvas, Offset origin) {
    final rects = <Rect>[];
    var y = origin.dy;
    for (var i = 0; i < paragraphs.length; i++) {
      y += gaps[i];
      final p = paragraphs[i];
      canvas.drawParagraph(p, Offset(origin.dx, y));
      rects.add(Rect.fromLTWH(origin.dx, y, p.longestLine, p.height));
      y += p.height;
    }
    return rects;
  }

  void dispose() {
    for (final p in paragraphs) {
      p.dispose();
    }
  }
}

/// Finds the largest scale (≤ 1) at which every block fits in
/// [maxWidth] × [maxHeight] without breaking a word, so long texts shrink
/// instead of overflowing.
FittedText fitBlocks(
  List<TextBlock> blocks, {
  required double canvasWidth,
  required double maxWidth,
  required double maxHeight,
  required Color color,
  TextAlign align = TextAlign.start,
  double minScale = 0.2,
}) {
  FittedText layout(double scale) {
    final paragraphs = <ui.Paragraph>[];
    final gaps = <double>[];
    for (final b in blocks) {
      final fontSize = b.size * canvasWidth * scale;
      final builder =
          ui.ParagraphBuilder(
              ui.ParagraphStyle(
                textAlign: align,
                fontFamily: b.fontFamily,
                fontSize: fontSize,
                height: b.lineHeight,
              ),
            )
            ..pushStyle(
              ui.TextStyle(
                color: color.withValues(alpha: color.a * b.opacity),
                fontFamily: b.fontFamily,
                fontSize: fontSize,
                height: b.lineHeight,
                letterSpacing: b.letterSpacing * fontSize,
                fontWeight: _nearestWeight(b.weight),
                fontVariations: [ui.FontVariation('wght', b.weight)],
              ),
            )
            ..addText(b.text);
      final p = builder.build()
        ..layout(ui.ParagraphConstraints(width: maxWidth));
      paragraphs.add(p);
      gaps.add(b.gapBefore * canvasWidth * scale);
    }
    return FittedText(paragraphs, gaps, scale, false);
  }

  bool fits(FittedText t) =>
      t.height <= maxHeight &&
      // A single word wider than the box would be broken mid-word.
      t.paragraphs.every((p) => p.minIntrinsicWidth <= maxWidth + 0.5);

  final full = layout(1);
  if (fits(full)) return full;
  full.dispose();

  var lo = minScale, hi = 1.0;
  FittedText? best;
  final atMin = layout(minScale);
  if (!fits(atMin)) {
    return FittedText(atMin.paragraphs, atMin.gaps, minScale, true);
  }
  best = atMin;
  for (var i = 0; i < 14; i++) {
    final mid = (lo + hi) / 2;
    final t = layout(mid);
    if (fits(t)) {
      best!.dispose();
      best = t;
      lo = mid;
    } else {
      t.dispose();
      hi = mid;
    }
  }
  return best!;
}

FontWeight _nearestWeight(double w) =>
    FontWeight.values[((w / 100).round() - 1).clamp(
      0,
      FontWeight.values.length - 1,
    )];
