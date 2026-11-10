import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../color_math.dart';
import '../wallpaper_content.dart';
import 'backgrounds.dart';
import 'pieces.dart';
import 'style_book.dart';

/// What a layout drew, for tests and debugging.
class LayoutReport {
  const LayoutReport({
    required this.safeBox,
    required this.texts,
    required this.scale,
    required this.overflowed,
    this.panel,
  });

  /// The box all text must stay in.
  final Rect safeBox;

  /// Every text drawn, with its colors and what it sits on.
  final List<TextDraw> texts;
  final double scale;

  /// True only if the text did not fit even at the minimum scale.
  final bool overflowed;

  /// The card behind the text, if the layout draws one.
  final Rect? panel;
}

/// Places the content in the box the background leaves. Add one by
/// implementing this and listing it in [StyleLayouts.list].
abstract class StyleLayout {
  const StyleLayout();

  String get id;

  /// Palette colors this layout draws text in; their contrast on the
  /// paper is checked when the recipes are read.
  Set<String> get textRoles => const {'ink', 'muted', 'accent'};

  LayoutReport paint(
    Canvas canvas,
    Size size,
    WallpaperContent c,
    Palette p,
    FontPair f,
    BackgroundResult bg,
  );
}

abstract final class StyleLayouts {
  static const List<StyleLayout> list = [
    DictionaryLayout(),
    TerminalLayout(),
    TerminalLayout(glow: true),
    CalendarLayout(),
    PosterLayout(),
    PosterLayout(offsetPrint: true),
    CardLayout(),
    NoteLayout(),
  ];

  static final Map<String, StyleLayout> all = {for (final l in list) l.id: l};
}

/// Fits [build] into the content box (inside a card when [card] is set),
/// centers it vertically and paints it.
LayoutReport placeContent(
  Canvas canvas,
  Size size,
  BackgroundResult bg,
  Piece Function(Unit u, double width) build, {
  PanelStyle? card,
  double grow = 1.2,
}) {
  final box = bg.contentBox;
  final pad = card == null ? 0.0 : size.width * card.padding;
  final width = box.width - pad * 2;
  final (piece, scale, overflowed) = fitPieces(
    (s) => build(Unit(size.width, s), width),
    box.height - pad * 2,
    maxScale: grow,
  );
  final top = box.center.dy - piece.height / 2;
  var under = bg.under;
  Rect? panel;
  if (card != null) {
    panel = Rect.fromLTRB(
      box.left,
      top - pad,
      box.right,
      top + piece.height + pad,
    );
    final rrect = RRect.fromRectAndRadius(
      panel,
      Radius.circular(size.width * card.radius),
    );
    canvas.drawRRect(
      rrect.shift(Offset(0, size.width * 0.01)),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.03),
    );
    canvas.drawRRect(
      rrect,
      Paint()..color = card.color.withValues(alpha: card.alpha),
    );
    if (card.border != null) {
      canvas.drawRRect(
        rrect.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, size.width * 0.0015)
          ..color = card.border!,
      );
    }
    under = [for (final u in bg.under) blend(card.color, u, card.alpha)];
  }
  final out = <TextDraw>[];
  piece.paint(PaintContext(canvas, under, out), Offset(box.left + pad, top));
  piece.dispose();
  return LayoutReport(
    safeBox: box,
    texts: out,
    scale: scale,
    overflowed: overflowed,
    panel: panel,
  );
}

/// A translucent card drawn behind the text.
class PanelStyle {
  const PanelStyle({
    required this.color,
    this.alpha = 0.88,
    this.padding = 0.065,
    this.radius = 0.045,
    this.border,
  });

  final Color color;
  final double alpha;
  final double padding;
  final double radius;
  final Color? border;
}

/// "dayanıklı, çabuk toparlanan" → two numbered senses.
List<String> splitMeanings(String meaning) {
  final parts = [
    for (final s in meaning.split(RegExp(r'\s*[;,]\s*')))
      if (s.trim().isNotEmpty) s.trim(),
  ];
  return parts.length > 3 || parts.isEmpty ? [meaning] : parts;
}

/// A dictionary page: the guide word with the issue number and the date
/// over a double rule, the syllabified headword, pronunciation, red italic
/// part of speech, a framed level, numbered senses in red, and an italic
/// example with its translation under a hairline.
class DictionaryLayout extends StyleLayout {
  const DictionaryLayout();

  @override
  String get id => 'dictionary';

  @override
  LayoutReport paint(
    Canvas canvas,
    Size size,
    WallpaperContent c,
    Palette p,
    FontPair f,
    BackgroundResult bg,
  ) => placeContent(canvas, size, bg, grow: 1.3, (u, width) {
    // The safe band is short, so the page is compact: the issue number and
    // the date share the guide-word line, the senses run on one line.
    final display = Ts(
      family: f.display,
      size: c.isWord ? 0.25 : 0.12,
      weight: f.displayWeight,
      color: p.ink,
      height: c.isWord ? 0.95 : 1.06,
    );
    final body = Ts(
      family: f.body,
      size: 0.062,
      weight: f.bodyWeight,
      color: p.ink,
      height: 1.28,
    );
    final small = body.copyWith(size: 0.034, color: p.muted, spacing: 0.03);
    final guide = c.isWord ? c.title.toLowerCase() : c.categoryLabel;

    final pron = <(String, Ts)>[
      if (c.ipa != null)
        ('/${c.ipa}/  ', body.copyWith(size: 0.05, color: p.muted)),
      if (c.partOfSpeech != null)
        (
          c.partOfSpeech!,
          body.copyWith(size: 0.056, italic: true, color: p.accent),
        ),
      if (!c.isWord)
        (c.badge, body.copyWith(size: 0.05, italic: true, color: p.accent)),
    ];
    final badge = c.level == null
        ? null
        : BoxPiece(
            TextPiece.plain(
              u,
              c.level!,
              small.copyWith(color: p.ink, weight: 600, spacing: 0.08),
              maxWidth: width,
            ),
            padX: u(0.016),
            padY: u(0.004),
            border: p.ink,
            borderWidth: u.line(0.002),
          );
    final pronPiece = pron.isEmpty
        ? null
        : TextPiece(u, pron, maxWidth: width - (badge?.width ?? 0) - u(0.03));

    final senses = c.isWord && c.subtitle != null
        ? splitMeanings(c.subtitle!)
        : const <String>[];
    final number = body.copyWith(color: p.accent, weight: 700);
    return VBox([
      HBox(
        [
          TextPiece.plain(
            u,
            guide,
            small.copyWith(italic: true),
            maxWidth: width * 0.4,
          ),
          TextPiece.plain(
            u,
            'No. ${c.labels.dayOfYear} · ${c.labels.longDate}',
            small,
            maxWidth: width * 0.58,
          ),
        ],
        spread: width,
        align: RowAlign.bottom,
      ),
      Rule(
        width,
        u.line(0.0022),
        p.ink,
        style: RuleStyle.double,
        padding: u(0.01),
      ),
      Gap(u(0.03)),
      if (c.isWord)
        TextPiece.plain(
          u,
          c.syllables ?? c.title,
          fitOneLine(u, c.syllables ?? c.title, display, width),
          maxWidth: width,
        )
      else
        TextPiece.plain(u, c.title, display, maxWidth: width),
      Gap(u(0.014)),
      if (pronPiece != null || badge != null)
        HBox([?pronPiece, ?badge], gap: u(0.03)),
      Gap(u(0.024)),
      if (senses.length == 1)
        TextPiece.plain(u, senses.single, body, maxWidth: width)
      else if (senses.isNotEmpty)
        TextPiece(u, [
          for (final (i, s) in senses.indexed) ...[
            ('${i == 0 ? '' : '   '}${i + 1} ', number),
            (s, body),
          ],
        ], maxWidth: width),
      if (!c.isWord && c.body != null)
        TextPiece.plain(u, c.body!, body, maxWidth: width),
      if (c.isWord && c.body != null) ...[
        Rule(width, u.line(0.0014), p.muted, padding: u(0.022)),
        TextPiece.plain(
          u,
          c.body!,
          body.copyWith(size: 0.056, italic: true),
          maxWidth: width,
        ),
        if (c.footnote != null) ...[
          Gap(u(0.008)),
          TextPiece.plain(
            u,
            c.footnote!,
            body.copyWith(size: 0.048, color: p.muted),
            maxWidth: width,
          ),
        ],
      ],
    ]);
  });
}

/// A child given a fixed width.
class SizedPiece extends Piece {
  SizedPiece(this.child, this.width);

  final Piece child;
  @override
  final double width;

  @override
  double get height => child.height;

  @override
  bool get fits => child.fits && child.width <= width + 0.5;

  @override
  void paint(PaintContext ctx, Offset at) => child.paint(ctx, at);

  @override
  void dispose() => child.dispose();
}

/// A title with a block cursor right after its last letter.
class _CursorTitle extends Piece {
  _CursorTitle(this.text, this.cursorWidth, this.color);

  final TextPiece text;
  final double cursorWidth;
  final Color color;

  @override
  double get width => text.width + cursorWidth * 1.4;

  @override
  double get height => text.height;

  @override
  bool get fits => text.fits;

  @override
  void paint(PaintContext ctx, Offset at) {
    text.paint(ctx, at);
    final g = text.lastGlyph.shift(at);
    final h = g.height * 0.78;
    ctx.canvas.drawRect(
      Rect.fromLTWH(
        g.right + cursorWidth * 0.3,
        g.top + (g.height - h) / 2,
        cursorWidth,
        h,
      ),
      Paint()..color = color,
    );
  }

  @override
  void dispose() => text.dispose();
}

/// A terminal session: the command, the word in bold with an amber block
/// cursor, key: value lines, a dashed rule, "> example" and the counter.
class TerminalLayout extends StyleLayout {
  const TerminalLayout({this.glow = false});

  /// Phosphor glow: the title and the accents get a faint halo.
  final bool glow;

  @override
  String get id => glow ? 'terminal_glow' : 'terminal';

  @override
  LayoutReport paint(
    Canvas canvas,
    Size size,
    WallpaperContent c,
    Palette p,
    FontPair f,
    BackgroundResult bg,
  ) => placeContent(canvas, size, bg, grow: 1.25, (u, width) {
    final mono = Ts(
      family: f.body,
      size: 0.042,
      weight: f.bodyWeight,
      color: p.ink,
      height: 1.36,
    );
    final titleStyle = Ts(
      family: f.display,
      size: c.isWord ? 0.135 : 0.068,
      weight: f.displayWeight,
      color: p.ink,
      height: 1.12,
      glow: glow ? p.accent.withValues(alpha: 0.45) : null,
    );
    final cursor = u(titleStyle.size * 0.55);
    final pairs = c.isWord
        ? [
            (c.labels.keyLevel, c.level!),
            (c.labels.keyType, c.partOfSpeechName ?? c.categoryLabel),
            if (c.subtitle != null) (c.labels.keyMeaning, c.subtitle!),
          ]
        : [(c.labels.keyCategory, c.categoryLabel)];
    final keyWidth =
        pairs.fold(0.0, (w, kv) {
          final t = TextPiece.plain(u, '${kv.$1}:', mono, maxWidth: width);
          final r = math.max(w, t.width);
          t.dispose();
          return r;
        }) +
        u(0.04);
    Piece line(String prefix, Color prefixColor, String text, Ts style) =>
        TextPiece(u, [
          (prefix, style.copyWith(color: prefixColor)),
          (text, style),
        ], maxWidth: width);
    return VBox([
      line(
        '\$ ',
        p.accent,
        'today --lang ${c.language}',
        mono.copyWith(color: p.muted),
      ),
      Gap(u(0.03)),
      _CursorTitle(
        TextPiece.plain(
          u,
          c.title,
          c.isWord
              ? fitOneLine(u, c.title, titleStyle, width - cursor * 1.4)
              : titleStyle,
          maxWidth: width - cursor * 1.4,
        ),
        cursor,
        p.accent,
      ),
      Gap(u(0.026)),
      for (final (k, v) in pairs)
        HBox([
          SizedPiece(
            TextPiece.plain(
              u,
              '$k:',
              mono.copyWith(color: p.muted),
              maxWidth: keyWidth,
            ),
            keyWidth,
          ),
          TextPiece.plain(u, v, mono, maxWidth: width - keyWidth),
        ], align: RowAlign.top),
      Rule(
        width,
        u.line(0.0018),
        p.muted,
        style: RuleStyle.dashed,
        padding: u(0.024),
      ),
      if (c.body != null)
        line('> ', p.accent, c.body!, mono.copyWith(size: 0.044)),
      if (c.footnote != null) ...[
        Gap(u(0.01)),
        line(
          '# ',
          p.muted,
          c.footnote!,
          mono.copyWith(size: 0.04, color: p.muted),
        ),
      ],
      Gap(u(0.036)),
      TextPiece(u, [
        (
          '[${c.labels.dayOfYear}/${c.labels.daysInYear}]',
          mono.copyWith(size: 0.036, color: p.accent),
        ),
        ('  ${c.labels.longDate}', mono.copyWith(size: 0.036, color: p.muted)),
      ], maxWidth: width),
    ]);
  });
}

/// A tear-off calendar sheet: year and month, the weekday in red, a huge
/// red day number with the day of the year beside it, a heavy rule and the
/// day's word or note.
class CalendarLayout extends StyleLayout {
  const CalendarLayout();

  @override
  String get id => 'calendar';

  @override
  LayoutReport paint(
    Canvas canvas,
    Size size,
    WallpaperContent c,
    Palette p,
    FontPair f,
    BackgroundResult bg,
  ) => placeContent(canvas, size, bg, grow: 1.4, (u, width) {
    final display = Ts(
      family: f.display,
      size: 0.04,
      weight: f.displayWeight,
      color: p.ink,
      height: 1.05,
    );
    final body = Ts(
      family: f.body,
      size: 0.04,
      weight: f.bodyWeight,
      color: p.ink,
      height: 1.3,
    );
    final label = display.copyWith(
      size: 0.042,
      weight: 600,
      spacing: 0.12,
      color: p.muted,
    );
    // On a flat page the day number is the hero; on the hanging sheet it
    // leaves room for the binding.
    final flat = !bg.onSheet;
    final number = TextPiece.plain(
      u,
      '${c.labels.dayOfMonth}',
      display.copyWith(
        size: flat ? 0.48 : 0.36,
        weight: 800,
        color: p.accent,
        height: flat ? 0.88 : 0.92,
      ),
      maxWidth: width * (flat ? 0.66 : 0.6),
    );
    final side = width - number.width - u(0.05);
    final section = c.isWord
        ? '${c.labels.wordOfDay} · ${c.level}'
        : c.categoryLabel;
    return VBox([
      HBox([
        TextPiece.plain(
          u,
          '${c.labels.year} · ${upperFor(c.labels.month, c.language)}',
          label,
          maxWidth: width * 0.6,
        ),
        TextPiece.plain(
          u,
          upperFor(c.labels.weekday, c.language),
          label.copyWith(color: p.accent, weight: 800),
          maxWidth: width * 0.38,
        ),
      ], spread: width),
      Gap(u(0.012)),
      HBox(
        [
          number,
          VBox([
            TextPiece.plain(
              u,
              c.labels.dayOfYearText,
              body.copyWith(size: 0.042, weight: 650),
              maxWidth: side,
            ),
            Gap(u(0.008)),
            TextPiece.plain(
              u,
              c.labels.daysLeftText,
              body.copyWith(size: 0.038, color: p.muted),
              maxWidth: side,
            ),
          ]),
        ],
        gap: u(0.05),
        align: RowAlign.center,
      ),
      Rule(width, u.line(0.006), p.ink, padding: u(0.028)),
      TextPiece.plain(
        u,
        upperFor(section, c.language),
        label.copyWith(size: 0.034, color: p.accent, weight: 800),
        maxWidth: width,
      ),
      Gap(u(0.018)),
      () {
        final s = display.copyWith(
          size: c.isWord ? 0.1 : 0.064,
          weight: 700,
          height: 1.08,
        );
        return TextPiece.plain(
          u,
          c.title,
          c.isWord ? fitOneLine(u, c.title, s, width) : s,
          maxWidth: width,
        );
      }(),
      if (c.subtitle != null) ...[
        Gap(u(0.012)),
        TextPiece.plain(
          u,
          c.subtitle!,
          body.copyWith(size: 0.044),
          maxWidth: width,
        ),
      ],
      if (c.body != null) ...[
        Gap(u(0.018)),
        TextPiece.plain(
          u,
          c.body!,
          body.copyWith(size: 0.038, italic: c.isWord, color: p.muted),
          maxWidth: width,
        ),
      ],
    ]);
  });
}

/// Paints a copy of the title in the accent color, shifted like a
/// misregistered print plate, under the real one (multiply).
class _OffsetTitle extends Piece {
  _OffsetTitle(this.main, this.copy, this.shift, this.accent);

  final TextPiece main;
  final TextPiece copy;
  final double shift;
  final Color accent;

  @override
  double get width => main.width + shift;

  @override
  double get height => main.height + shift;

  @override
  bool get fits => main.fits;

  @override
  void paint(PaintContext ctx, Offset at) {
    final bounds = Rect.fromLTWH(
      at.dx - shift,
      at.dy - shift,
      width + shift * 3,
      height + shift * 3,
    );
    ctx.canvas.saveLayer(bounds, Paint()..blendMode = BlendMode.multiply);
    ctx.canvas.drawParagraph(copy.paragraph, at.translate(shift, shift));
    ctx.canvas.restore();
    main.paint(
      ctx.withUnder([
        ...ctx.under,
        for (final u in ctx.under) multiply(accent, u),
      ]),
      at,
    );
  }

  @override
  void dispose() {
    main.dispose();
    copy.dispose();
  }
}

/// [a] multiplied over [b].
Color multiply(Color a, Color b) =>
    Color.from(alpha: 1, red: a.r * b.r, green: a.g * b.g, blue: a.b * b.b);

/// A poster: black label, huge heavy title, the rest below. With
/// [offsetPrint] the title has a pink misregistered copy (risograph).
class PosterLayout extends StyleLayout {
  const PosterLayout({this.offsetPrint = false});

  final bool offsetPrint;

  @override
  String get id => offsetPrint ? 'poster_offset' : 'poster';

  /// The accent is only the misregistered copy, never readable text.
  @override
  Set<String> get textRoles => const {'ink', 'muted'};

  @override
  LayoutReport paint(
    Canvas canvas,
    Size size,
    WallpaperContent c,
    Palette p,
    FontPair f,
    BackgroundResult bg,
  ) => placeContent(canvas, size, bg, grow: 1.15, (u, width) {
    final title = Ts(
      family: f.display,
      size: c.isWord ? 0.19 : 0.092,
      weight: f.displayWeight,
      color: p.ink,
      height: c.isWord ? 0.98 : 1.04,
      spacing: -0.02,
    );
    final body = Ts(
      family: f.body,
      size: 0.042,
      weight: f.bodyWeight,
      color: p.ink,
      height: 1.32,
    );
    final shift = math.max(2.0, size.width * 3 / 1080);
    final fitted = c.isWord
        ? fitOneLine(u, c.title, title, width - shift)
        : title;
    final main = TextPiece.plain(u, c.title, fitted, maxWidth: width - shift);
    return VBox([
      BoxPiece(
        TextPiece.plain(
          u,
          upperFor(c.badge, c.language),
          body.copyWith(size: 0.03, weight: 750, spacing: 0.14, color: p.paper),
          maxWidth: width - u(0.04),
        ),
        padX: u(0.02),
        padY: u(0.008),
        fill: p.ink,
      ),
      Gap(u(0.045)),
      offsetPrint
          ? _OffsetTitle(
              main,
              TextPiece.plain(
                u,
                c.title,
                fitted.copyWith(color: p.accent),
                maxWidth: width - shift,
              ),
              shift,
              p.accent,
            )
          : main,
      if (c.subtitle != null) ...[
        Gap(u(0.03)),
        TextPiece.plain(
          u,
          c.subtitle!,
          body.copyWith(size: 0.05, weight: 650),
          maxWidth: width,
        ),
      ],
      if (c.body != null) ...[
        Gap(u(0.03)),
        TextPiece.plain(u, c.body!, body, maxWidth: width),
      ],
      if (c.footnote != null) ...[
        Gap(u(0.014)),
        TextPiece.plain(
          u,
          c.footnote!,
          body.copyWith(size: 0.038, color: p.muted),
          maxWidth: width,
        ),
      ],
      Gap(u(0.05)),
      TextPiece.plain(
        u,
        'No. ${c.labels.dayOfYear} · ${c.labels.longDate}',
        body.copyWith(size: 0.03, color: p.muted, spacing: 0.06),
        maxWidth: width,
      ),
    ]);
  });
}

/// Text in a translucent card, mono labels (topographic, waves).
class CardLayout extends StyleLayout {
  const CardLayout();

  @override
  String get id => 'card';

  @override
  LayoutReport paint(
    Canvas canvas,
    Size size,
    WallpaperContent c,
    Palette p,
    FontPair f,
    BackgroundResult bg,
  ) => placeContent(
    canvas,
    size,
    bg,
    card: PanelStyle(color: p.paper, border: p.decor),
    grow: 1.1,
    (u, width) {
      final mono = Ts(
        family: f.mono,
        size: 0.028,
        color: p.muted,
        spacing: 0.1,
      );
      final body = Ts(
        family: f.body,
        size: 0.04,
        weight: f.bodyWeight,
        color: p.ink,
        height: 1.35,
      );
      final dict = [
        if (c.ipa != null) '/${c.ipa}/',
        if (c.partOfSpeech != null) c.partOfSpeech!,
      ].join('  ');
      return VBox([
        HBox([
          TextPiece.plain(
            u,
            upperFor(c.badge, c.language),
            mono.copyWith(color: p.accent, weight: 600),
            maxWidth: width * 0.75,
          ),
          TextPiece.plain(
            u,
            '#${c.labels.dayOfYear}',
            mono,
            maxWidth: width * 0.2,
          ),
        ], spread: width),
        Gap(u(0.04)),
        () {
          final s = Ts(
            family: f.display,
            size: c.isWord ? 0.13 : 0.066,
            weight: f.displayWeight,
            color: p.ink,
            height: 1.08,
          );
          return TextPiece.plain(
            u,
            c.title,
            c.isWord ? fitOneLine(u, c.title, s, width) : s,
            maxWidth: width,
          );
        }(),
        if (dict.isNotEmpty) ...[
          Gap(u(0.012)),
          TextPiece.plain(
            u,
            dict,
            mono.copyWith(size: 0.032, spacing: 0),
            maxWidth: width,
          ),
        ],
        if (c.subtitle != null) ...[
          Gap(u(0.022)),
          TextPiece.plain(
            u,
            c.subtitle!,
            body.copyWith(size: 0.046, weight: 600, color: p.accent),
            maxWidth: width,
          ),
        ],
        if (c.body != null) ...[
          Gap(u(0.03)),
          TextPiece.plain(u, c.body!, body, maxWidth: width),
        ],
        if (c.footnote != null) ...[
          Gap(u(0.014)),
          TextPiece.plain(
            u,
            c.footnote!,
            body.copyWith(size: 0.036, color: p.muted),
            maxWidth: width,
          ),
        ],
        Rule(width, u.line(0.0014), p.decor, padding: u(0.03)),
        TextPiece.plain(u, c.labels.longDate, mono, maxWidth: width),
      ]);
    },
  );
}

/// A notebook page: highlighted category, issue number and date on top,
/// then the title and the rest like a handwritten note.
class NoteLayout extends StyleLayout {
  const NoteLayout();

  @override
  String get id => 'note';

  @override
  LayoutReport paint(
    Canvas canvas,
    Size size,
    WallpaperContent c,
    Palette p,
    FontPair f,
    BackgroundResult bg,
  ) => placeContent(canvas, size, bg, grow: 1.3, (u, width) {
    final body = Ts(
      family: f.body,
      size: 0.058,
      weight: f.bodyWeight,
      color: p.ink,
      height: 1.3,
    );
    final dict = [
      if (c.ipa != null) '/${c.ipa}/',
      if (c.partOfSpeech != null) c.partOfSpeech!,
    ].join('  ');
    return VBox([
      HBox([
        BoxPiece(
          TextPiece.plain(
            u,
            upperFor(c.badge, c.language),
            body.copyWith(size: 0.036, weight: 750, spacing: 0.1, color: p.ink),
            maxWidth: width * 0.55,
          ),
          padX: u(0.016),
          padY: u(0.006),
          fill: blend(p.accent2, p.paper, 0.32),
          radius: u(0.006),
        ),
        TextPiece(u, [
          (
            'No. ${c.labels.dayOfYear}  ',
            body.copyWith(size: 0.036, color: p.accent, weight: 700),
          ),
          (c.labels.longDate, body.copyWith(size: 0.036, color: p.muted)),
        ], maxWidth: width * 0.43),
      ], spread: width),
      Gap(u(0.034)),
      () {
        final s = Ts(
          family: f.display,
          size: c.isWord ? 0.2 : 0.1,
          weight: f.displayWeight,
          color: p.ink,
          height: 1.04,
        );
        return TextPiece.plain(
          u,
          c.title,
          c.isWord ? fitOneLine(u, c.title, s, width) : s,
          maxWidth: width,
        );
      }(),
      if (dict.isNotEmpty) ...[
        Gap(u(0.008)),
        TextPiece.plain(
          u,
          dict,
          body.copyWith(size: 0.048, color: p.muted, italic: true),
          maxWidth: width,
        ),
      ],
      if (c.subtitle != null) ...[
        Gap(u(0.018)),
        TextPiece(u, [
          ('— ', body.copyWith(color: p.accent, weight: 700)),
          (c.subtitle!, body.copyWith(size: 0.062, weight: 600)),
        ], maxWidth: width),
      ],
      if (c.body != null) ...[
        Gap(u(0.022)),
        TextPiece.plain(u, c.body!, body, maxWidth: width),
      ],
      if (c.footnote != null) ...[
        Gap(u(0.01)),
        TextPiece.plain(
          u,
          c.footnote!,
          body.copyWith(size: 0.05, color: p.muted),
          maxWidth: width,
        ),
      ],
    ]);
  });
}
