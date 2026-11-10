import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../core/seeded_random.dart';
import '../color_math.dart';
import 'style_book.dart';

/// What a background leaves for the layout.
class BackgroundResult {
  const BackgroundResult({
    required this.under,
    required this.contentBox,
    this.onSheet = false,
  });

  /// Every color that can be behind text inside [contentBox].
  final List<Color> under;

  /// Where the layout puts its text; always inside the safe text box.
  final Rect contentBox;

  /// The text is on a hanging calendar sheet drawn by the background.
  final bool onSheet;
}

/// A code-generated background. Everything random comes from [r], which is
/// seeded by the day and the category, so a day always looks the same.
abstract class StyleBackground {
  const StyleBackground();

  String get id;

  BackgroundResult paint(
    Canvas canvas,
    Size size,
    Palette p,
    SeededRandom r,
    Rect textBox,
  );
}

abstract final class StyleBackgrounds {
  static const List<StyleBackground> list = [
    PaperBackground(),
    TerminalBackground(),
    HangingSheetBackground(),
    RisoBackground(),
    TopoBackground(),
    HalftoneBackground(),
    BauhausBackground(),
    WavesBackground(),
    LinedBackground(),
    GridBackground(),
  ];

  static final Map<String, StyleBackground> all = {
    for (final b in list) b.id: b,
  };
}

const _black = Color(0xFF000000);
const _white = Color(0xFFFFFFFF);

/// Print grain: scattered dark and light specks over [area]. Returns the
/// two colors a speck can turn [base] into.
List<Color> paintGrain(
  Canvas canvas,
  Rect area,
  Color base,
  SeededRandom r, {
  double alpha = 0.05,
  double density = 1 / 28,
  required double unit,
}) {
  final dot = math.max(1.0, unit / 900);
  final count = math.min(
    160000,
    (area.width * area.height * density / (dot * dot)).round(),
  );
  for (final color in [_black, _white]) {
    final points = Float32List(count * 2);
    for (var i = 0; i < count; i++) {
      points[i * 2] = area.left + r.nextDouble() * area.width;
      points[i * 2 + 1] = area.top + r.nextDouble() * area.height;
    }
    canvas.drawRawPoints(
      ui.PointMode.points,
      points,
      Paint()
        ..color = color.withValues(alpha: alpha)
        ..strokeWidth = dot
        ..strokeCap = StrokeCap.square,
    );
  }
  return [blend(_black, base, alpha), blend(_white, base, alpha)];
}

void _fill(Canvas canvas, Size size, Color color) =>
    canvas.drawRect(Offset.zero & size, Paint()..color = color);

/// Shapes outside the text: clip the text box (plus a margin) away.
void _outsideText(Canvas canvas, Rect textBox, double margin) =>
    canvas.clipRect(textBox.inflate(margin), clipOp: ui.ClipOp.difference);

/// Off-white paper with a fine grain.
class PaperBackground extends StyleBackground {
  const PaperBackground();

  @override
  String get id => 'paper';

  @override
  BackgroundResult paint(
    Canvas c,
    Size s,
    Palette p,
    SeededRandom r,
    Rect box,
  ) {
    _fill(c, s, p.paper);
    final grain = paintGrain(
      c,
      Offset.zero & s,
      p.paper,
      r,
      alpha: 0.035,
      unit: s.width,
    );
    return BackgroundResult(under: [p.paper, ...grain], contentBox: box);
  }
}

/// A screen: flat color with faint scanlines and a soft vignette.
class TerminalBackground extends StyleBackground {
  const TerminalBackground();

  @override
  String get id => 'terminal';

  @override
  BackgroundResult paint(
    Canvas c,
    Size s,
    Palette p,
    SeededRandom r,
    Rect box,
  ) {
    _fill(c, s, p.paper);
    final step = math.max(3.0, s.width / 270);
    final line = Paint()..color = p.decor.withValues(alpha: 0.35);
    for (var y = 0.0; y < s.height; y += step) {
      c.drawRect(Rect.fromLTWH(0, y, s.width, math.max(1, step / 3)), line);
    }
    return BackgroundResult(
      under: [p.paper, blend(p.decor, p.paper, 0.35)],
      contentBox: box,
    );
  }
}

/// A tear-off calendar hanging on a dark wall: binding strip with two
/// holes, torn remains of yesterday's sheet, two sheets behind, shadow and
/// paper grain.
class HangingSheetBackground extends StyleBackground {
  const HangingSheetBackground();

  @override
  String get id => 'hanging_sheet';

  @override
  BackgroundResult paint(
    Canvas c,
    Size s,
    Palette p,
    SeededRandom r,
    Rect box,
  ) {
    final w = s.width, h = s.height;
    c.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(w * 0.5, h * 0.45),
          h * 0.7,
          [
            blend(_white, p.ground, 0.07),
            p.ground,
            blend(_black, p.ground, 0.25),
          ],
          [0, 0.6, 1],
        ),
    );
    final sheet = Rect.fromLTRB(
      w * 0.06,
      box.top - h * 0.05,
      w * 0.94,
      box.bottom + h * 0.03,
    );
    final shadow = Paint()
      ..color = _black.withValues(alpha: 0.45)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.025);

    // Two older sheets, slightly turned.
    for (final (angle, shade) in [
      (r.range(1.2, 2.6) * (r.nextBool() ? 1 : -1), 0.16),
      (r.range(0.5, 1.4) * (r.nextBool() ? 1 : -1), 0.08),
    ]) {
      c.save();
      c.translate(sheet.center.dx, sheet.top);
      c.rotate(angle * math.pi / 180);
      c.translate(-sheet.center.dx, -sheet.top);
      final back = sheet.translate(0, h * 0.006);
      c.drawRect(back.shift(Offset(0, w * 0.01)), shadow);
      c.drawRect(back, Paint()..color = blend(_black, p.paper, shade));
      c.restore();
    }

    c.drawRect(sheet.shift(Offset(0, w * 0.018)), shadow);
    c.drawRect(sheet, Paint()..color = p.paper);
    c.save();
    c.clipRect(sheet);
    final grain = paintGrain(c, sheet, p.paper, r, alpha: 0.05, unit: w);
    // A faint fold shadow under the strip.
    c.drawRect(
      Rect.fromLTWH(sheet.left, sheet.top, sheet.width, h * 0.012),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, sheet.top),
          Offset(0, sheet.top + h * 0.012),
          [_black.withValues(alpha: 0.12), _black.withValues(alpha: 0)],
        ),
    );
    c.restore();

    // Torn remains of the previous sheet, just below the binding.
    final stripBottom = sheet.top + h * 0.004;
    final torn = Path()..moveTo(sheet.left, stripBottom);
    for (var x = sheet.left; x < sheet.right; x += w * r.range(0.008, 0.02)) {
      torn.lineTo(x, stripBottom + h * r.range(0.002, 0.011));
    }
    torn
      ..lineTo(sheet.right, stripBottom)
      ..close();
    c.drawPath(torn, Paint()..color = blend(_black, p.paper, 0.05));

    final strip = Rect.fromLTRB(
      sheet.left - w * 0.012,
      sheet.top - h * 0.032,
      sheet.right + w * 0.012,
      stripBottom,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        strip.shift(Offset(0, w * 0.008)),
        Radius.circular(w * 0.01),
      ),
      shadow,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(strip, Radius.circular(w * 0.01)),
      Paint()
        ..shader = ui.Gradient.linear(
          strip.topCenter,
          strip.bottomCenter,
          [
            blend(_white, p.accent2, 0.12),
            p.accent2,
            blend(_black, p.accent2, 0.2),
          ],
          [0, 0.55, 1],
        ),
    );
    for (final fx in [0.3, 0.7]) {
      final center = Offset(w * fx, strip.center.dy);
      c.drawCircle(
        center,
        w * 0.02,
        Paint()..color = blend(_black, p.ground, 0.35),
      );
      c.drawCircle(
        center,
        w * 0.02,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, w * 0.003)
          ..color = blend(_white, p.accent2, 0.25),
      );
    }

    return BackgroundResult(
      under: [p.paper, ...grain],
      contentBox: Rect.fromLTRB(
        box.left + w * 0.02,
        box.top,
        box.right - w * 0.02,
        box.bottom,
      ),
      onSheet: true,
    );
  }
}

/// Risograph print: overlapping pink and blue circles and squares in
/// multiply, outside the text, and grain over everything.
class RisoBackground extends StyleBackground {
  const RisoBackground();

  @override
  String get id => 'riso';

  @override
  BackgroundResult paint(
    Canvas c,
    Size s,
    Palette p,
    SeededRandom r,
    Rect box,
  ) {
    final w = s.width, h = s.height;
    _fill(c, s, p.paper);
    c.save();
    _outsideText(c, box, w * 0.025);
    final n = 4 + r.nextInt(3);
    final margin = w * 0.03;
    for (var i = 0; i < n; i++) {
      final top = i.isEven;
      // Keep every shape (a turned square reaches 1.21 r) clear of the text.
      final band = top ? box.top - margin : h - box.bottom - margin;
      final rad = math.min(w * r.range(0.14, 0.32), band / 1.9);
      final reach = rad * 1.22;
      final center = Offset(
        w * r.range(-0.05, 1.05),
        top
            ? r.range(-rad * 0.4, box.top - margin - reach)
            : r.range(box.bottom + margin + reach, h + rad * 0.4),
      );
      final paint = Paint()
        ..color = (i % 3 == 1 ? p.accent2 : p.accent).withValues(alpha: 0.9)
        ..blendMode = BlendMode.multiply;
      if (r.nextDouble() < 0.55) {
        c.drawCircle(center, rad, paint);
      } else {
        c.save();
        c.translate(center.dx, center.dy);
        c.rotate(r.range(-0.5, 0.5));
        c.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: rad * 1.7,
            height: rad * 1.7,
          ),
          paint,
        );
        c.restore();
      }
    }
    c.restore();
    final grain = paintGrain(
      c,
      Offset.zero & s,
      p.paper,
      r,
      alpha: 0.07,
      density: 1 / 14,
      unit: w,
    );
    return BackgroundResult(under: [p.paper, ...grain], contentBox: box);
  }
}

/// Contour lines growing out of two centers, each ring turned a little.
class TopoBackground extends StyleBackground {
  const TopoBackground();

  @override
  String get id => 'topo';

  @override
  BackgroundResult paint(
    Canvas c,
    Size s,
    Palette p,
    SeededRandom r,
    Rect box,
  ) {
    final w = s.width, h = s.height;
    _fill(c, s, p.ground);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, w * 0.0028)
      ..color = p.decor;
    final centers = [
      Offset(w * r.range(0.1, 0.9), h * r.range(0.05, 0.3)),
      Offset(w * r.range(0.1, 0.9), h * r.range(0.7, 0.95)),
    ];
    final step = w * r.range(0.038, 0.05);
    for (final center in centers) {
      final phases = [for (var k = 0; k < 4; k++) r.range(0, math.pi * 2)];
      final amps = [
        r.range(0.04, 0.08),
        r.range(0.02, 0.05),
        r.range(0.01, 0.025),
        r.range(0.005, 0.012),
      ];
      final turn = r.range(0.015, 0.04) * (r.nextBool() ? 1 : -1);
      for (var i = 1; step * i < h * 0.75; i++) {
        final radius = step * i;
        final path = Path();
        for (var j = 0; j <= 96; j++) {
          final t = j / 96 * math.pi * 2;
          var f = 1.0;
          for (var k = 0; k < 4; k++) {
            f += amps[k] * math.sin((k + 2) * t + phases[k] + i * 0.08);
          }
          final a = t + turn * i;
          final pt = center + Offset(math.cos(a), math.sin(a)) * radius * f;
          j == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
        }
        c.drawPath(path..close(), stroke);
      }
    }
    return BackgroundResult(under: [p.ground, p.decor], contentBox: box);
  }
}

/// Halftone dots that grow toward one corner, plus a cluster of bigger
/// accent dots outside the text.
class HalftoneBackground extends StyleBackground {
  const HalftoneBackground();

  @override
  String get id => 'halftone';

  @override
  BackgroundResult paint(
    Canvas c,
    Size s,
    Palette p,
    SeededRandom r,
    Rect box,
  ) {
    final w = s.width, h = s.height;
    _fill(c, s, p.paper);
    final focus = Offset(r.nextBool() ? 0 : w, r.nextBool() ? 0 : h);
    void dots(
      Paint paint,
      double spacing,
      double maxR,
      Offset from,
      double reach,
    ) {
      c.save();
      c.translate(w / 2, h / 2);
      c.rotate(math.pi / 4);
      final span = s.longestSide * 0.8;
      for (var y = -span; y < span; y += spacing) {
        for (var x = -span; x < span; x += spacing) {
          final cos = math.cos(math.pi / 4), sin = math.sin(math.pi / 4);
          final pt = Offset(
            x * cos - y * sin + w / 2,
            x * sin + y * cos + h / 2,
          );
          final f = 1 - (pt - from).distance / reach;
          if (f <= 0.05) continue;
          c.drawCircle(Offset(x, y), maxR * math.pow(f, 1.3), paint);
        }
      }
      c.restore();
    }

    dots(Paint()..color = p.decor, w * 0.028, w * 0.012, focus, h * 0.95);
    c.save();
    _outsideText(c, box, w * 0.02);
    final cluster = Offset(
      w * r.range(0.2, 0.8),
      r.nextBool() ? h * 0.12 : h * 0.84,
    );
    dots(Paint()..color = p.accent2, w * 0.034, w * 0.017, cluster, w * 0.5);
    c.restore();
    return BackgroundResult(under: [p.paper, p.decor], contentBox: box);
  }
}

/// Bauhaus blocks: circles, half circles, bars and triangles above and
/// below the text.
class BauhausBackground extends StyleBackground {
  const BauhausBackground();

  @override
  String get id => 'bauhaus';

  @override
  BackgroundResult paint(
    Canvas c,
    Size s,
    Palette p,
    SeededRandom r,
    Rect box,
  ) {
    final w = s.width, h = s.height;
    _fill(c, s, p.paper);
    c.save();
    _outsideText(c, box, w * 0.03);
    final colors = r.shuffled([p.accent, p.accent2, p.ink, p.decor]);
    Paint fill(int i) => Paint()..color = colors[i % colors.length];
    final top = box.top, bottom = box.bottom;
    switch (r.nextInt(3)) {
      case 0:
        c.drawCircle(Offset(w * 0.78, top * 0.48), w * 0.3, fill(0));
        c.drawRect(Rect.fromLTWH(0, top * 0.62, w * 0.46, top * 0.2), fill(1));
        c.drawArc(
          Rect.fromCircle(
            center: Offset(w * 0.12, bottom + (h - bottom) * 0.9),
            radius: w * 0.42,
          ),
          -math.pi / 2,
          math.pi / 2,
          true,
          fill(2),
        );
        c.drawRect(
          Rect.fromLTWH(
            w * 0.62,
            bottom + (h - bottom) * 0.35,
            w * 0.38,
            (h - bottom) * 0.22,
          ),
          fill(3),
        );
      case 1:
        final path = Path()
          ..moveTo(0, 0)
          ..lineTo(w * 0.62, 0)
          ..lineTo(0, top * 0.9)
          ..close();
        c.drawPath(path, fill(0));
        c.drawCircle(Offset(w * 0.72, top * 0.55), w * 0.17, fill(1));
        for (var i = 0; i < 3; i++) {
          c.drawArc(
            Rect.fromCircle(
              center: Offset(w * (0.17 + i * 0.33), h),
              radius: w * 0.16,
            ),
            math.pi,
            math.pi,
            true,
            fill(i + 2),
          );
        }
        c.drawRect(
          Rect.fromLTWH(
            w * 0.08,
            bottom + (h - bottom) * 0.25,
            w * 0.84,
            w * 0.03,
          ),
          fill(1),
        );
      default:
        final cell = w / 4;
        for (var i = 0; i < 4; i++) {
          final rect = Rect.fromLTWH(i * cell, top - cell * 1.3, cell, cell);
          c.drawArc(
            Rect.fromCircle(
              center: i.isEven ? rect.bottomLeft : rect.topRight,
              radius: cell,
            ),
            i.isEven ? -math.pi / 2 : math.pi / 2,
            math.pi / 2,
            true,
            fill(i),
          );
        }
        c.drawCircle(
          Offset(w * 0.25, bottom + (h - bottom) * 0.5),
          w * 0.16,
          fill(3),
        );
        c.drawRect(
          Rect.fromLTWH(
            w * 0.52,
            bottom + (h - bottom) * 0.3,
            w * 0.3,
            w * 0.3,
          ),
          fill(0),
        );
    }
    c.restore();
    return BackgroundResult(under: [p.paper], contentBox: box);
  }
}

/// Many thin waves across the page and a solid wave band at the bottom.
class WavesBackground extends StyleBackground {
  const WavesBackground();

  @override
  String get id => 'waves';

  @override
  BackgroundResult paint(
    Canvas c,
    Size s,
    Palette p,
    SeededRandom r,
    Rect box,
  ) {
    final w = s.width, h = s.height;
    _fill(c, s, p.paper);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, w * 0.0028)
      ..color = p.decor;
    final length = w * r.range(0.7, 1.2);
    final phase = r.range(0, math.pi * 2);
    final step = h * r.range(0.018, 0.026);
    for (var y = -step; y < h + step; y += step) {
      final amp = w * 0.025 * (1 + 0.6 * math.sin(y / h * math.pi * 2 + phase));
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= w; x += w / 60) {
        path.lineTo(
          x,
          y + math.sin(x / length * math.pi * 2 + y / h * 3 + phase) * amp,
        );
      }
      c.drawPath(path, stroke);
    }
    c.save();
    _outsideText(c, box, w * 0.03);
    for (final (base, color, k) in [
      (h * 0.8, p.accent2, 1.0),
      (h * 0.88, p.accent, 1.4),
    ]) {
      final band = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w; x += w / 60) {
        band.lineTo(
          x,
          base + math.sin(x / length * math.pi * 2 * k + phase) * h * 0.02,
        );
      }
      band
        ..lineTo(w, h)
        ..close();
      c.drawPath(band, Paint()..color = color);
    }
    c.restore();
    return BackgroundResult(under: [p.paper, p.decor], contentBox: box);
  }
}

/// Ruled notebook paper with a margin line and punched holes.
class LinedBackground extends StyleBackground {
  const LinedBackground();

  @override
  String get id => 'lined';

  @override
  BackgroundResult paint(
    Canvas c,
    Size s,
    Palette p,
    SeededRandom r,
    Rect box,
  ) {
    final w = s.width, h = s.height;
    _fill(c, s, p.paper);
    final line = Paint()..color = p.decor;
    final step = h * 0.024;
    for (var y = h * 0.06; y < h; y += step) {
      c.drawRect(Rect.fromLTWH(0, y, w, math.max(1, w * 0.0018)), line);
    }
    c.drawRect(
      Rect.fromLTWH(w * 0.058, 0, math.max(1, w * 0.003), h),
      Paint()..color = p.accent2,
    );
    for (final fy in [0.18, 0.5, 0.82]) {
      c.drawCircle(
        Offset(w * 0.028, h * fy),
        w * 0.012,
        Paint()..color = blend(_black, p.paper, 0.18),
      );
    }
    return BackgroundResult(under: [p.paper, p.decor], contentBox: box);
  }
}

/// Squared paper, every fifth line a little stronger.
class GridBackground extends StyleBackground {
  const GridBackground();

  @override
  String get id => 'grid';

  @override
  BackgroundResult paint(
    Canvas c,
    Size s,
    Palette p,
    SeededRandom r,
    Rect box,
  ) {
    final w = s.width, h = s.height;
    _fill(c, s, p.paper);
    final cell = w / 22;
    final thin = Paint()..color = p.decor.withValues(alpha: 0.55);
    final thick = Paint()..color = p.decor;
    final t = math.max(1.0, w * 0.0014);
    var i = 0;
    for (var x = 0.0; x < w; x += cell, i++) {
      c.drawRect(Rect.fromLTWH(x, 0, t, h), i % 5 == 0 ? thick : thin);
    }
    i = 0;
    for (var y = 0.0; y < h; y += cell, i++) {
      c.drawRect(Rect.fromLTWH(0, y, w, t), i % 5 == 0 ? thick : thin);
    }
    return BackgroundResult(under: [p.paper, p.decor], contentBox: box);
  }
}
