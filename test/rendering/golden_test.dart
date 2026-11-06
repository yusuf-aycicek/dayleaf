// Pixel comparisons. Excluded on CI (fonts rasterize differently on Linux).
//   flutter test --tags golden                     run locally
//   flutter test --tags golden --update-goldens    regenerate after a design change
@Tags(['golden'])
library;

import 'package:dailywall/rendering/background.dart';
import 'package:dailywall/rendering/templates.dart';
import 'package:dailywall/rendering/wallpaper_content.dart';
import 'package:dailywall/rendering/wallpaper_renderer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fonts.dart';

const word = WallpaperContent(
  language: 'tr',
  badge: 'B1 · İngilizce kelime',
  title: 'resilient',
  titleLanguage: 'en',
  subtitle: 'dayanıklı, çabuk toparlanan',
  body: 'Children are often more resilient than adults think.',
  footnote: 'Çocuklar çoğu zaman yetişkinlerin sandığından daha dayanıklıdır.',
);

const tip = WallpaperContent(
  language: 'en',
  badge: 'Software tip',
  title: 'Use git bisect to find the commit that broke something.',
  body: 'It binary-searches your history: even 1,000 commits take about 10 steps.',
);

void main() {
  setUpAll(loadAppFonts);

  for (final template in WallpaperTemplates.all) {
    for (final (name, content, day, category) in [
      ('word', word, 20400, 'english_words'),
      ('tip', tip, 20401, 'software_tips'),
    ]) {
      testWidgets('${template.id} $name', (tester) async {
        final image = await tester.runAsync(() async {
          final r = await WallpaperRenderer.render(
            content: content,
            template: template,
            background: BackgroundSpec.forDay(day, category),
            width: 540,
            height: 1200,
          );
          return r.image;
        });
        await expectLater(
          image!,
          matchesGoldenFile('goldens/${template.id}_$name.png'),
        );
        image.dispose();
      });
    }
  }

  testWidgets('shared image watermark', (tester) async {
    final image = await tester.runAsync(() async {
      final r = await WallpaperRenderer.render(
        content: tip,
        template: WallpaperTemplates.minimal,
        background: BackgroundSpec.forDay(20402, 'motivation'),
        width: 540,
        height: 1200,
      );
      return WallpaperRenderer.withWatermark(r.image, 'dailywall');
    });
    await expectLater(
      image!,
      matchesGoldenFile('goldens/shared_watermark.png'),
    );
  });
}
