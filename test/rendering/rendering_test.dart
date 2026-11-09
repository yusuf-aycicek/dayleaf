import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dailywall/data/content_models.dart';
import 'package:dailywall/data/content_schema.dart';
import 'package:dailywall/rendering/background.dart';
import 'package:dailywall/rendering/color_math.dart';
import 'package:dailywall/rendering/layout.dart';
import 'package:dailywall/rendering/templates.dart';
import 'package:dailywall/rendering/wallpaper_content.dart';
import 'package:dailywall/rendering/wallpaper_renderer.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fonts.dart';

/// Phone-ish physical resolutions, including a short 16:9 and a tall one.
const sizes = [
  Size(720, 1600),
  Size(1080, 2400),
  Size(1440, 3120),
  Size(1080, 1920),
  Size(1344, 2992),
];

List<ContentItem> realItems() => [
  for (final c in ContentCatalog.categories)
    ...validateCategory(
      c,
      jsonDecode(File(c.assetPath).readAsStringSync()),
      languages: const ['en', 'tr'],
    ).items,
];

/// The longest real items plus synthetic ones at the schema's length limits.
List<WallpaperContent> stressContents() {
  final items = realItems();
  int len(ContentItem i) => switch (i) {
    WordItem() =>
      i.word.length +
          i.meaning.resolve('tr').length +
          i.example.values.values.join().length,
    TextItem() => i.text.resolve('tr').length + i.detail.resolve('tr').length,
  };
  items.sort((a, b) => len(b).compareTo(len(a)));
  String words(int n) =>
      List.filled(n ~/ 6 + 1, 'kelime').join(' ').substring(0, n);
  return [
    for (final i in items.take(6))
      for (final lang in ['tr', 'en'])
        WallpaperContent.fromItem(
          i,
          language: lang,
          categoryLabel: 'Genel kültür bilgisi',
        ),
    WallpaperContent(
      language: 'tr',
      badge: 'C1 · İngilizce kelime',
      title: 'w' * ContentLimits.word,
      subtitle: words(ContentLimits.meaning),
      body: words(ContentLimits.example),
      footnote: words(ContentLimits.example),
    ),
    WallpaperContent(
      language: 'tr',
      badge: 'Motivasyon',
      title: words(ContentLimits.text),
      body: words(ContentLimits.detail),
    ),
  ];
}

LayoutReport record(
  WallpaperTemplate t,
  Size size,
  WallpaperContent c,
  BackgroundSpec bg,
) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  bg.paint(canvas, size);
  final report = t.paint(canvas, size, c, bg);
  recorder.endRecording().dispose();
  return report;
}

void main() {
  setUpAll(loadAppFonts);

  group('background', () {
    test('same day and category give the same background', () {
      final a = BackgroundSpec.forDay(20400, 'motivation');
      final b = BackgroundSpec.forDay(20400, 'motivation');
      expect(a.colors, b.colors);
      expect(
        (a.style, a.pattern, a.angle, a.patternSeed),
        (b.style, b.pattern, b.angle, b.patternSeed),
      );
    });

    test('days and categories vary the background', () {
      final specs = [
        for (var d = 0; d < 30; d++)
          BackgroundSpec.forDay(20400 + d, 'motivation'),
        BackgroundSpec.forDay(20400, 'software_tips'),
      ];
      expect(
        specs.map((s) => s.colors.first.toARGB32()).toSet().length,
        greaterThan(25),
      );
      expect(
        specs.map((s) => s.style).toSet(),
        hasLength(BackgroundStyle.values.length),
      );
      expect(specs.map((s) => s.pattern).toSet().length, greaterThan(3));
    });
  });

  group('contrast', () {
    test(
      'every template keeps text at WCAG AA on 600 generated backgrounds',
      () {
        const content = WallpaperContent(
          language: 'en',
          badge: 'B1 · English word',
          title: 'resilient',
          subtitle: 'dayanıklı',
          body: 'Example.',
          footnote: 'Örnek.',
        );
        for (var d = 0; d < 200; d++) {
          for (final cat in ['english_words', 'software_tips', 'motivation']) {
            final bg = BackgroundSpec.forDay(20000 + d, cat);
            for (final t in WallpaperTemplates.all) {
              final r = record(t, const Size(540, 1200), content, bg);
              final worst = minContrast(r.textColor, r.textBackgrounds);
              expect(
                worst,
                greaterThanOrEqualTo(minTextContrast),
                reason: '${t.id} day $d $cat: $worst',
              );
            }
          }
        }
      },
    );

    test(
      'light text is chosen on dark backgrounds and dark text on light ones',
      () {
        expect(
          ColorPlan.forBackground([const Color(0xFF101020)]).text,
          lightInk,
        );
        expect(
          ColorPlan.forBackground([const Color(0xFFF2F0E8)]).text,
          darkInk,
        );
      },
    );

    test('a mid-tone background gets a scrim', () {
      final plan = ColorPlan.forBackground([
        const Color(0xFF777777),
        const Color(0xFF777777),
      ]);
      expect(plan.scrim, isNotNull);
      expect(
        minContrast(
          plan.text,
          plan.effective([const Color(0xFF777777), const Color(0xFF777777)]),
        ),
        greaterThanOrEqualTo(minTextContrast),
      );
    });

    test('contrast ratio matches WCAG reference values', () {
      expect(
        contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 0.01),
      );
      expect(
        contrastRatio(const Color(0xFF777777), const Color(0xFFFFFFFF)),
        closeTo(4.48, 0.01),
      );
    });
  });

  group('layout', () {
    final contents = stressContents();
    for (final size in sizes) {
      for (final t in WallpaperTemplates.all) {
        test(
          '${t.id} ${size.width.toInt()}x${size.height.toInt()}: text stays in the safe area and never overflows',
          () {
            for (final c in contents) {
              final r = record(
                t,
                size,
                c,
                BackgroundSpec.forDay(20000, 'motivation'),
              );
              expect(r.overflowed, isFalse, reason: c.title);
              final box = r.safeBox.inflate(0.5);
              for (final rect in r.blockRects) {
                expect(
                  box.contains(rect.topLeft) && box.contains(rect.bottomRight),
                  isTrue,
                  reason: '${t.id} "${c.title}" $rect outside $box',
                );
              }
              if (r.panel != null) {
                expect(
                  box.contains(r.panel!.outerRect.topLeft) &&
                      box.contains(r.panel!.outerRect.bottomRight),
                  isTrue,
                );
              }
            }
          },
        );
      }
    }

    test(
      'the safe area avoids the lock-screen clock and the bottom shortcuts',
      () {
        final box = WallpaperSafeArea.textBox(const Size(1080, 2400));
        expect(box.top, greaterThanOrEqualTo(2400 * 0.29));
        // Home-screen icons start at ~65% (Pixel launcher, measured).
        expect(box.bottom, lessThanOrEqualTo(2400 * 0.63));
        expect(box.height, greaterThanOrEqualTo(2400 * 0.3));
      },
    );

    test('short text keeps full size, long text shrinks', () {
      const short = WallpaperContent(
        language: 'en',
        badge: 'Motivation',
        title: 'Rest.',
        body: 'Short.',
      );
      final long = stressContents().last;
      final bg = BackgroundSpec.forDay(20000, 'motivation');
      expect(
        record(
          WallpaperTemplates.minimal,
          const Size(1080, 2400),
          short,
          bg,
        ).scale,
        1,
      );
      expect(
        record(
          WallpaperTemplates.minimal,
          const Size(1080, 2400),
          long,
          bg,
        ).scale,
        lessThan(1),
      );
    });
  });

  test('Turkish-aware uppercase', () {
    expect(upperFor('istanbul ılık', 'tr'), 'İSTANBUL ILIK');
    expect(upperFor('istanbul', 'en'), 'ISTANBUL');
  });

  testWidgets('renders at the exact physical size; the watermark keeps it', (
    tester,
  ) async {
    await tester.runAsync(() async {
      const content = WallpaperContent(
        language: 'tr',
        badge: 'Motivasyon',
        title: 'Küçük adımlar birikir.',
        body: 'Günde on dakika.',
      );
      final r = await WallpaperRenderer.render(
        content: content,
        template: WallpaperTemplates.card,
        background: BackgroundSpec.forDay(20000, 'motivation'),
        width: 1080,
        height: 2400,
      );
      expect((r.image.width, r.image.height), (1080, 2400));
      final shared = await WallpaperRenderer.withWatermark(
        r.image,
        'dailywall',
      );
      expect((shared.width, shared.height), (1080, 2400));
      final rgba = await WallpaperRenderer.encodeRgba(r.image);
      expect(rgba.length, 1080 * 2400 * 4);
      final png = await WallpaperRenderer.encodePng(shared);
      expect(png.sublist(1, 4), 'PNG'.codeUnits);
      shared.dispose();
      r.dispose();
    });
  });
}
