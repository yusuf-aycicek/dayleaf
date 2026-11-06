import 'package:flutter/painting.dart';

import 'background.dart';
import 'color_math.dart';
import 'layout.dart';
import 'text_fit.dart';
import 'wallpaper_content.dart';

/// What a template drew, for tests and debugging.
class LayoutReport {
  const LayoutReport({
    required this.safeBox,
    required this.blockRects,
    required this.textColor,
    required this.textBackgrounds,
    required this.scale,
    required this.overflowed,
    this.panel,
  });

  final Rect safeBox;
  final List<Rect> blockRects;
  final Color textColor;

  /// Every color the text may sit on (after any scrim or card).
  final List<Color> textBackgrounds;
  final double scale;
  final bool overflowed;

  /// The card or scrim behind the text, if any.
  final RRect? panel;
}

/// A wallpaper layout. Add one by implementing this and listing it in
/// [WallpaperTemplates.all] (and adding its name to the ARB files).
abstract class WallpaperTemplate {
  const WallpaperTemplate();

  String get id;

  /// Reserved for a future premium tier. Everything is free for now.
  bool get isPremium => false;

  LayoutReport paint(
    Canvas canvas,
    Size size,
    WallpaperContent content,
    BackgroundSpec background,
  );
}

abstract final class WallpaperTemplates {
  static const minimal = MinimalTemplate();
  static const card = CardTemplate();
  static const bold = BoldTypeTemplate();

  static const List<WallpaperTemplate> all = [minimal, card, bold];

  static WallpaperTemplate byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => minimal);
}

const _sans = 'Manrope';
const _serif = 'Lora';
const _display = 'Anton';

/// Text straight on the background, left-aligned, vertically centered.
class MinimalTemplate extends WallpaperTemplate {
  const MinimalTemplate();

  @override
  String get id => 'minimal';

  @override
  LayoutReport paint(
    Canvas canvas,
    Size size,
    WallpaperContent c,
    BackgroundSpec bg,
  ) {
    final box = WallpaperSafeArea.textBox(size);
    final plan = ColorPlan.forBackground(bg.possibleColors);
    final blocks = [
      TextBlock(
        upperFor(c.badge, c.language),
        fontFamily: _sans,
        size: 0.03,
        weight: 700,
        letterSpacing: 0.16,
        opacity: 0.75,
      ),
      TextBlock(
        c.title,
        fontFamily: _sans,
        size: 0.12,
        weight: 800,
        lineHeight: 1.08,
        gapBefore: 0.03,
      ),
      if (c.subtitle != null)
        TextBlock(
          c.subtitle!,
          fontFamily: _sans,
          size: 0.055,
          weight: 600,
          gapBefore: 0.025,
        ),
      if (c.body != null)
        TextBlock(
          c.body!,
          fontFamily: _sans,
          size: 0.046,
          weight: 450,
          lineHeight: 1.35,
          opacity: 0.92,
          gapBefore: 0.04,
        ),
      if (c.footnote != null)
        TextBlock(
          c.footnote!,
          fontFamily: _sans,
          size: 0.04,
          weight: 400,
          lineHeight: 1.35,
          opacity: 0.75,
          gapBefore: 0.015,
        ),
    ];
    return _paintFloating(
      canvas,
      size,
      box,
      blocks,
      plan,
      bg,
      padding: size.width * 0.05,
    );
  }
}

/// A rounded card holding the text, serif title.
class CardTemplate extends WallpaperTemplate {
  const CardTemplate();

  @override
  String get id => 'card';

  @override
  LayoutReport paint(
    Canvas canvas,
    Size size,
    WallpaperContent c,
    BackgroundSpec bg,
  ) {
    final box = WallpaperSafeArea.textBox(size);
    final under = bg.possibleColors;
    final darkBg =
        under.map(relativeLuminance).reduce((a, b) => a + b) / under.length <
        0.2;
    // Light card on dark backgrounds and vice versa.
    final cardColor = darkBg
        ? const Color(0xFFF7F5F0)
        : const Color(0xFF16181D);
    final text = darkBg ? darkInk : lightInk;
    var alpha = 0.9;
    List<Color> onCard() => [for (final u in under) blend(cardColor, u, alpha)];
    while (minContrast(text, onCard()) < minTextContrast && alpha < 1) {
      alpha = (alpha + 0.02).clamp(0, 1);
    }

    final pad = size.width * 0.075;
    final blocks = [
      TextBlock(
        upperFor(c.badge, c.language),
        fontFamily: _sans,
        size: 0.028,
        weight: 700,
        letterSpacing: 0.14,
        opacity: 0.7,
      ),
      TextBlock(
        c.title,
        fontFamily: _serif,
        size: 0.1,
        weight: 700,
        lineHeight: 1.12,
        gapBefore: 0.025,
      ),
      if (c.subtitle != null)
        TextBlock(
          c.subtitle!,
          fontFamily: _sans,
          size: 0.05,
          weight: 600,
          gapBefore: 0.02,
        ),
      if (c.body != null)
        TextBlock(
          c.body!,
          fontFamily: _serif,
          size: 0.044,
          weight: 400,
          lineHeight: 1.4,
          opacity: 0.9,
          gapBefore: 0.035,
        ),
      if (c.footnote != null)
        TextBlock(
          c.footnote!,
          fontFamily: _sans,
          size: 0.038,
          weight: 400,
          lineHeight: 1.35,
          opacity: 0.72,
          gapBefore: 0.015,
        ),
    ];
    final fitted = fitBlocks(
      blocks,
      canvasWidth: size.width,
      maxWidth: box.width - pad * 2,
      maxHeight: box.height - pad * 2,
      color: text,
    );
    final cardHeight = fitted.height + pad * 2;
    final card = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        box.left,
        box.center.dy - cardHeight / 2,
        box.width,
        cardHeight,
      ),
      Radius.circular(size.width * 0.06),
    );
    canvas.drawRRect(
      card.shift(Offset(0, size.width * 0.012)),
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.03),
    );
    canvas.drawRRect(card, Paint()..color = cardColor.withValues(alpha: alpha));
    final rects = fitted.paint(canvas, Offset(card.left + pad, card.top + pad));
    fitted.dispose();
    return LayoutReport(
      safeBox: box,
      blockRects: rects,
      textColor: text,
      textBackgrounds: onCard(),
      scale: fitted.scale,
      overflowed: fitted.overflowed,
      panel: card,
    );
  }
}

/// A huge condensed title with a small accent line.
class BoldTypeTemplate extends WallpaperTemplate {
  const BoldTypeTemplate();

  @override
  String get id => 'bold';

  @override
  LayoutReport paint(
    Canvas canvas,
    Size size,
    WallpaperContent c,
    BackgroundSpec bg,
  ) {
    final box = WallpaperSafeArea.textBox(size);
    final plan = ColorPlan.forBackground(bg.possibleColors);
    final blocks = [
      TextBlock(
        upperFor(c.badge, c.language),
        fontFamily: _sans,
        size: 0.03,
        weight: 800,
        letterSpacing: 0.2,
        opacity: 0.8,
      ),
      TextBlock(
        upperFor(c.title, c.titleLanguage),
        fontFamily: _display,
        size: 0.19,
        weight: 400,
        lineHeight: 1.0,
        gapBefore: 0.03,
      ),
      if (c.subtitle != null)
        TextBlock(
          c.subtitle!,
          fontFamily: _sans,
          size: 0.056,
          weight: 700,
          gapBefore: 0.03,
        ),
      if (c.body != null)
        TextBlock(
          c.body!,
          fontFamily: _sans,
          size: 0.044,
          weight: 500,
          lineHeight: 1.35,
          opacity: 0.9,
          gapBefore: 0.035,
        ),
      if (c.footnote != null)
        TextBlock(
          c.footnote!,
          fontFamily: _sans,
          size: 0.038,
          weight: 400,
          lineHeight: 1.35,
          opacity: 0.75,
          gapBefore: 0.015,
        ),
    ];
    final report = _paintFloating(
      canvas,
      size,
      box,
      blocks,
      plan,
      bg,
      padding: size.width * 0.05,
      accent: true,
    );
    return report;
  }
}

/// Shared by the templates whose text sits directly on the background.
LayoutReport _paintFloating(
  Canvas canvas,
  Size size,
  Rect box,
  List<TextBlock> blocks,
  ColorPlan plan,
  BackgroundSpec bg, {
  required double padding,
  bool accent = false,
}) {
  // Reserve the scrim padding up front so the text fits with or without it.
  final inner = box.deflate(padding);
  final accentSpace = accent ? size.width * 0.04 : 0.0;
  final fitted = fitBlocks(
    blocks,
    canvasWidth: size.width,
    maxWidth: inner.width,
    maxHeight: inner.height - accentSpace,
    color: plan.text,
  );
  final contentHeight = fitted.height + accentSpace;
  final top = inner.center.dy - contentHeight / 2;

  RRect? panel;
  if (plan.scrim != null) {
    panel = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        box.left,
        top - padding,
        box.right,
        top + contentHeight + padding,
      ),
      Radius.circular(size.width * 0.05),
    );
    canvas.drawRRect(
      panel,
      Paint()..color = plan.scrim!.withValues(alpha: plan.scrimAlpha),
    );
  }
  if (accent) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(inner.left, top, size.width * 0.12, size.width * 0.012),
        Radius.circular(size.width * 0.006),
      ),
      Paint()..color = plan.text.withValues(alpha: 0.85),
    );
  }
  final rects = fitted.paint(canvas, Offset(inner.left, top + accentSpace));
  fitted.dispose();
  return LayoutReport(
    safeBox: box,
    blockRects: rects,
    textColor: plan.text,
    textBackgrounds: plan.effective(bg.possibleColors),
    scale: fitted.scale,
    overflowed: fitted.overflowed,
    panel: panel,
  );
}
