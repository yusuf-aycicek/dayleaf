import 'dart:ui' as ui;

import 'package:dayleaf/app/wallpaper_text.dart';
import 'package:dayleaf/rendering/color_math.dart';
import 'package:dayleaf/rendering/layout.dart';
import 'package:dayleaf/rendering/style/layouts.dart';
import 'package:dayleaf/rendering/style/style_book.dart';
import 'package:dayleaf/rendering/wallpaper_content.dart';
import 'package:dayleaf/rendering/wallpaper_renderer.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/samples.dart';
import 'test_fonts.dart';

/// Phone-ish physical resolutions, including a short 16:9 and a tall one.
const sizes = [Size(720, 1600), Size(1080, 2400), Size(1080, 1920)];

LayoutReport record(StyleRecipe r, Size size, WallpaperContent c) {
  final recorder = ui.PictureRecorder();
  final report = WallpaperRenderer.paint(Canvas(recorder), size, c, r);
  recorder.endRecording().dispose();
  return report;
}

void main() {
  setUpAll(loadAppFonts);
  final book = loadStyleBook();
  final contents = stressContents();

  for (final r in book.recipes) {
    test('${r.name}: text fits the safe area and reads at WCAG AA', () {
      for (final size in sizes) {
        for (final c in contents) {
          final report = record(r, size, c);
          final where = '${r.name} ${size.width}x${size.height} "${c.title}"';
          expect(report.overflowed, isFalse, reason: where);
          expect(report.texts, isNotEmpty);
          final box = WallpaperSafeArea.textBox(size).inflate(0.5);
          expect(
            box.contains(report.safeBox.topLeft) &&
                box.contains(report.safeBox.bottomRight),
            isTrue,
          );
          for (final t in report.texts) {
            expect(
              box.contains(t.rect.topLeft) && box.contains(t.rect.bottomRight),
              isTrue,
              reason: '$where: ${t.rect} outside $box',
            );
            for (final color in t.colors) {
              final worst = minContrast(color, t.under);
              expect(
                worst,
                greaterThanOrEqualTo(minTextContrast),
                reason: '$where: $color at ${worst.toStringAsFixed(2)}:1',
              );
            }
          }
          if (report.panel != null) {
            expect(
              box.contains(report.panel!.topLeft) &&
                  box.contains(report.panel!.bottomRight),
              isTrue,
            );
          }
        }
      }
    });
  }

  test('short text grows, long text shrinks', () {
    final r = book.byName('riso_pink_blue')!;
    const size = Size(1080, 2400);
    final short = WallpaperContent(
      language: 'en',
      categoryId: 'motivation',
      categoryLabel: 'Motivation',
      day: sampleDay,
      labels: wallpaperLabels(l10nFor('en'), sampleDay),
      title: 'Rest.',
      body: 'Short.',
    );
    expect(record(r, size, short).scale, greaterThan(1));
    expect(record(r, size, contents.last).scale, lessThan(1));
  });

  testWidgets('the same day gives the same picture, another day changes it', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final r = book.byName('topo_forest')!;
      Future<List<int>> pixels(WallpaperContent c) async {
        final w = await WallpaperRenderer.render(
          content: c,
          recipe: r,
          width: 108,
          height: 240,
        );
        final bytes = await WallpaperRenderer.encodeRgba(w.image);
        w.dispose();
        return bytes;
      }

      final c = sampleFor('software_tips');
      final next = wallpaperContentFor(
        realItems().firstWhere((i) => i.categoryId == 'software_tips'),
        l10n: l10nFor('tr'),
        day: sampleDay + 1,
      );
      expect(await pixels(c), await pixels(c));
      expect(await pixels(next), isNot(await pixels(c)));
    });
  });

  test('date labels: day of year, days left, names', () {
    final tr = wallpaperLabels(l10nFor('tr'), sampleDay);
    expect(
      (tr.longDate, tr.weekday, tr.dayOfYearText, tr.daysLeftText),
      ('10 Kasım 2026', 'Salı', 'Yılın 314. günü', 'Kalan 51 gün'),
    );
    final en = wallpaperLabels(l10nFor('en'), sampleDay);
    expect((en.longDate, en.weekday), ('November 10, 2026', 'Tuesday'));
  });

  test('meanings are split into numbered senses', () {
    expect(splitMeanings('dayanıklı, çabuk toparlanan'), [
      'dayanıklı',
      'çabuk toparlanan',
    ]);
    expect(splitMeanings('the first meal of the day'), [
      'the first meal of the day',
    ]);
  });

  test('Turkish-aware uppercase', () {
    expect(upperFor('istanbul ılık', 'tr'), 'İSTANBUL ILIK');
    expect(upperFor('istanbul', 'en'), 'ISTANBUL');
  });

  testWidgets('renders at the exact physical size; the watermark keeps it', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final r = await WallpaperRenderer.render(
        content: sampleFor('motivation'),
        recipe: book.recipes.first,
        width: 1080,
        height: 2400,
      );
      expect((r.image.width, r.image.height), (1080, 2400));
      final shared = await WallpaperRenderer.withWatermark(r.image, 'Dayleaf');
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
