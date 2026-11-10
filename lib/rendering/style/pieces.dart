import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'fonts.dart';

/// A small box-layout engine for wallpapers. Layouts build a tree of
/// pieces at a given scale; [fitPieces] finds the largest scale (≤ 1) at
/// which the tree fits, so long texts shrink instead of overflowing.

/// One text drawn on the canvas and what it can sit on, for the contrast
/// and safe-area checks.
class TextDraw {
  const TextDraw(this.rect, this.colors, this.under);

  final Rect rect;
  final List<Color> colors;
  final List<Color> under;
}

class PaintContext {
  PaintContext(this.canvas, this.under, this.out);

  final Canvas canvas;

  /// Every color that can be behind the text being painted.
  final List<Color> under;
  final List<TextDraw> out;

  PaintContext withUnder(List<Color> colors) =>
      PaintContext(canvas, colors, out);
}

abstract class Piece {
  double get width;
  double get height;

  /// False when a word had to be broken or a line did not fit.
  bool get fits;
  void paint(PaintContext ctx, Offset at);
  void dispose() {}
}

/// Text style relative to the canvas width.
class Ts {
  const Ts({
    required this.family,
    required this.size,
    required this.color,
    this.weight = 400,
    this.italic = false,
    this.spacing = 0,
    this.height = 1.22,
    this.glow,
  });

  final String family;

  /// Font size as a fraction of the canvas width.
  final double size;
  final Color color;
  final double weight;
  final bool italic;

  /// Letter spacing in ems.
  final double spacing;
  final double height;

  /// A soft halo of this color around the letters (a CRT phosphor glow).
  final Color? glow;

  Ts copyWith({
    String? family,
    double? size,
    Color? color,
    double? weight,
    bool? italic,
    double? spacing,
    double? height,
    Color? glow,
  }) => Ts(
    family: family ?? this.family,
    size: size ?? this.size,
    color: color ?? this.color,
    weight: weight ?? this.weight,
    italic: italic ?? this.italic,
    spacing: spacing ?? this.spacing,
    height: height ?? this.height,
    glow: glow ?? this.glow,
  );
}

/// Units for one layout pass: canvas width times the current fit scale.
class Unit {
  const Unit(this.canvasWidth, this.scale);

  final double canvasWidth;
  final double scale;

  double call(double fraction) => fraction * canvasWidth * scale;

  /// Hairlines do not shrink below a pixel.
  double line(double fraction) => math.max(1, fraction * canvasWidth);
}

class TextPiece extends Piece {
  TextPiece._(this.paragraph, this.maxWidth, this.colors, this.lastChar);

  /// Lays out [spans] in at most [maxWidth].
  factory TextPiece(
    Unit u,
    List<(String, Ts)> spans, {
    required double maxWidth,
    TextAlign align = TextAlign.start,
  }) {
    final first = spans.first.$2;
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: align,
        fontFamily: first.family,
        fontSize: u(first.size),
        height: first.height,
      ),
    );
    var length = 0;
    for (final (text, s) in spans) {
      final fontSize = u(s.size);
      builder.pushStyle(
        ui.TextStyle(
          color: s.color,
          fontFamily: s.family,
          fontFamilyFallback: BundledFonts.fallback,
          fontSize: fontSize,
          height: s.height,
          letterSpacing: s.spacing * fontSize,
          fontWeight: _nearestWeight(s.weight),
          fontStyle: s.italic ? FontStyle.italic : FontStyle.normal,
          fontVariations: [ui.FontVariation('wght', s.weight)],
          shadows: s.glow == null
              ? null
              : [
                  Shadow(color: s.glow!, blurRadius: fontSize * 0.35),
                  Shadow(color: s.glow!, blurRadius: fontSize * 0.12),
                ],
        ),
      );
      builder.addText(text);
      builder.pop();
      length += text.length;
    }
    final p = builder.build()
      ..layout(ui.ParagraphConstraints(width: math.max(1, maxWidth)));
    return TextPiece._(
      p,
      maxWidth,
      {for (final s in spans) s.$2.color}.toList(),
      length,
    );
  }

  /// Single-style shorthand.
  factory TextPiece.plain(
    Unit u,
    String text,
    Ts style, {
    required double maxWidth,
    TextAlign align = TextAlign.start,
  }) => TextPiece(u, [(text, style)], maxWidth: maxWidth, align: align);

  final ui.Paragraph paragraph;
  final double maxWidth;
  final List<Color> colors;
  final int lastChar;
  TextAlign? _align;

  /// Right edge, top and bottom of the last glyph, relative to the piece.
  Rect get lastGlyph {
    final boxes = paragraph.getBoxesForRange(
      math.max(0, lastChar - 1),
      lastChar,
    );
    if (boxes.isEmpty) return Rect.fromLTWH(width, 0, 0, height);
    return boxes.last.toRect();
  }

  @override
  double get width => _align == null || _align == TextAlign.start
      ? paragraph.longestLine
      : maxWidth;

  @override
  double get height => paragraph.height;

  @override
  bool get fits => paragraph.minIntrinsicWidth <= maxWidth + 0.5;

  @override
  void paint(PaintContext ctx, Offset at) {
    ctx.canvas.drawParagraph(paragraph, at);
    // The ink of a centered or right-aligned paragraph can be anywhere in
    // its box; report the whole box.
    ctx.out.add(
      TextDraw(Rect.fromLTWH(at.dx, at.dy, width, height), colors, ctx.under),
    );
  }

  @override
  void dispose() => paragraph.dispose();
}

/// [s] made just small enough for [text] to fit [maxWidth] on one line, so
/// a long headword shrinks alone instead of shrinking the whole layout.
Ts fitOneLine(Unit u, String text, Ts s, double maxWidth) {
  final p = TextPiece.plain(u, text, s, maxWidth: 1e9);
  final natural = p.width;
  p.dispose();
  return natural <= maxWidth
      ? s
      : s.copyWith(size: s.size * maxWidth * 0.98 / natural);
}

/// Use full [maxWidth] as the piece width (for centered text).
TextPiece aligned(TextPiece p, TextAlign align) => p.._align = align;

class Gap extends Piece {
  Gap(this.height);

  @override
  final double height;

  @override
  double get width => 0;

  @override
  bool get fits => true;

  @override
  void paint(PaintContext ctx, Offset at) {}
}

enum CrossAlign { start, center, end }

class VBox extends Piece {
  VBox(this.children, {this.align = CrossAlign.start, this.fixedWidth});

  final List<Piece> children;
  final CrossAlign align;

  /// Width used for centering; the widest child when null.
  final double? fixedWidth;

  @override
  double get width =>
      fixedWidth ?? children.fold(0.0, (w, c) => math.max(w, c.width));

  @override
  double get height => children.fold(0.0, (h, c) => h + c.height);

  @override
  bool get fits => children.every((c) => c.fits);

  @override
  void paint(PaintContext ctx, Offset at) {
    var y = at.dy;
    for (final c in children) {
      final dx = switch (align) {
        CrossAlign.start => 0.0,
        CrossAlign.center => (width - c.width) / 2,
        CrossAlign.end => width - c.width,
      };
      c.paint(ctx, Offset(at.dx + dx, y));
      y += c.height;
    }
  }

  @override
  void dispose() {
    for (final c in children) {
      c.dispose();
    }
  }
}

enum RowAlign { top, center, bottom }

/// Children side by side. With [spread], the first child is left, the
/// last right, and the rest share the space between.
class HBox extends Piece {
  HBox(
    this.children, {
    this.gap = 0,
    this.align = RowAlign.center,
    this.spread,
  });

  final List<Piece> children;
  final double gap;
  final RowAlign align;

  /// Total width to spread the children across.
  final double? spread;

  double get _natural =>
      children.fold(0.0, (w, c) => w + c.width) +
      gap * math.max(0, children.length - 1);

  @override
  double get width => spread ?? _natural;

  @override
  double get height => children.fold(0.0, (h, c) => math.max(h, c.height));

  @override
  bool get fits =>
      children.every((c) => c.fits) &&
      (spread == null || _natural <= spread! + 0.5);

  @override
  void paint(PaintContext ctx, Offset at) {
    final extra = spread == null || children.length < 2
        ? 0.0
        : (spread! - _natural) / (children.length - 1);
    var x = at.dx;
    for (final c in children) {
      final dy = switch (align) {
        RowAlign.top => 0.0,
        RowAlign.center => (height - c.height) / 2,
        RowAlign.bottom => height - c.height,
      };
      c.paint(ctx, Offset(x, at.dy + dy));
      x += c.width + gap + extra;
    }
  }

  @override
  void dispose() {
    for (final c in children) {
      c.dispose();
    }
  }
}

enum RuleStyle { solid, double, dashed, dotted }

class Rule extends Piece {
  Rule(
    this.width,
    this.thickness,
    this.color, {
    this.style = RuleStyle.solid,
    this.padding = 0,
  });

  @override
  final double width;
  final double thickness;
  final Color color;
  final RuleStyle style;

  /// Space above and below the line.
  final double padding;

  double get _lineHeight =>
      style == RuleStyle.double ? thickness * 3.2 : thickness;

  @override
  double get height => _lineHeight + padding * 2;

  @override
  bool get fits => true;

  @override
  void paint(PaintContext ctx, Offset at) {
    final paint = Paint()..color = color;
    final y = at.dy + padding;
    switch (style) {
      case RuleStyle.solid:
        ctx.canvas.drawRect(Rect.fromLTWH(at.dx, y, width, thickness), paint);
      case RuleStyle.double:
        ctx.canvas
          ..drawRect(Rect.fromLTWH(at.dx, y, width, thickness * 1.6), paint)
          ..drawRect(
            Rect.fromLTWH(at.dx, y + thickness * 2.6, width, thickness * 0.6),
            paint,
          );
      case RuleStyle.dashed:
        final dash = thickness * 6, space = thickness * 4;
        for (var x = 0.0; x < width; x += dash + space) {
          ctx.canvas.drawRect(
            Rect.fromLTWH(at.dx + x, y, math.min(dash, width - x), thickness),
            paint,
          );
        }
      case RuleStyle.dotted:
        final step = thickness * 3;
        for (var x = thickness / 2; x < width; x += step) {
          ctx.canvas.drawCircle(
            Offset(at.dx + x, y + thickness / 2),
            thickness / 2,
            paint,
          );
        }
    }
  }
}

/// A child inside padding, with an optional fill and border.
class BoxPiece extends Piece {
  BoxPiece(
    this.child, {
    required this.padX,
    required this.padY,
    this.fill,
    this.border,
    this.borderWidth = 1,
    this.radius = 0,
  });

  final Piece child;
  final double padX, padY;
  final Color? fill;
  final Color? border;
  final double borderWidth;
  final double radius;

  @override
  double get width => child.width + padX * 2;

  @override
  double get height => child.height + padY * 2;

  @override
  bool get fits => child.fits;

  @override
  void paint(PaintContext ctx, Offset at) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(at.dx, at.dy, width, height),
      Radius.circular(radius),
    );
    if (fill != null) ctx.canvas.drawRRect(rect, Paint()..color = fill!);
    if (border != null) {
      ctx.canvas.drawRRect(
        rect.deflate(borderWidth / 2),
        Paint()
          ..color = border!
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth,
      );
    }
    child.paint(
      fill == null ? ctx : ctx.withUnder([fill!]),
      at.translate(padX, padY),
    );
  }

  @override
  void dispose() => child.dispose();
}

/// Free drawing in a fixed box.
class Drawing extends Piece {
  Drawing(this.width, this.height, this.painter);

  @override
  final double width;
  @override
  final double height;
  final void Function(Canvas canvas, Rect box) painter;

  @override
  bool get fits => true;

  @override
  void paint(PaintContext ctx, Offset at) =>
      painter(ctx.canvas, Rect.fromLTWH(at.dx, at.dy, width, height));
}

/// The largest scale up to [maxScale] at which [build] is at most
/// [maxHeight] tall and nothing is broken; binary search, 13 steps.
(Piece, double scale, bool overflowed) fitPieces(
  Piece Function(double scale) build,
  double maxHeight, {
  double minScale = 0.25,
  double maxScale = 1,
}) {
  bool ok(Piece p) => p.fits && p.height <= maxHeight;
  final full = build(maxScale);
  if (ok(full)) return (full, maxScale, false);
  full.dispose();
  final smallest = build(minScale);
  if (!ok(smallest)) return (smallest, minScale, true);
  var best = smallest;
  var bestScale = minScale;
  var lo = minScale, hi = maxScale;
  for (var i = 0; i < 13; i++) {
    final mid = (lo + hi) / 2;
    final p = build(mid);
    if (ok(p)) {
      best.dispose();
      best = p;
      bestScale = mid;
      lo = mid;
    } else {
      p.dispose();
      hi = mid;
    }
  }
  return (best, bestScale, false);
}

FontWeight _nearestWeight(double w) =>
    FontWeight.values[((w / 100).round() - 1).clamp(
      0,
      FontWeight.values.length - 1,
    )];
