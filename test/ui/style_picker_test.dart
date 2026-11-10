import 'package:dailywall/data/content_models.dart';
import 'package:dailywall/data/content_repository.dart';
import 'package:dailywall/domain/user_settings.dart';
import 'package:dailywall/l10n/gen/app_localizations.dart';
import 'package:dailywall/ui/widgets/style_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/samples.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final en = lookupAppLocalizations(const Locale('en'));
  final tr = lookupAppLocalizations(const Locale('tr'));
  final book = loadStyleBook();
  late ContentLibrary library;

  setUpAll(() async {
    library = await ContentRepository(
      bundle: rootBundle,
      languages: const ['en', 'tr'],
    ).load();
  });

  // Regression: the previews said "ENGLISH WORD" above a motivation line.
  test('the preview shows an item of the badge category', () {
    for (final c in ContentCatalog.categories) {
      final sample = previewSample(
        library: library,
        categoryId: c.id,
        level: CefrLevel.b2,
        l10n: en,
      );
      expect(sample.categoryId, c.id);
      final item = library
          .itemsOf(c.id)
          .firstWhere(
            (i) =>
                sample.title ==
                (i is WordItem ? i.word : (i as TextItem).text.resolve('en')),
          );
      if (item is WordItem) expect(item.level, CefrLevel.b2);
    }
  });

  test('before the content loads the sample is a motivation line', () {
    final sample = previewSample(
      library: null,
      categoryId: 'english_words',
      level: CefrLevel.b1,
      l10n: en,
    );
    expect(sample.badge, 'Motivation');
  });

  test("a family previews one of the user's interests it suits", () {
    final terminal = book.families.firstWhere((f) => f.id == 'terminal');
    expect(
      previewCategory(
        terminal,
        const UserSettings(categoryIds: ['english_words', 'motivation']),
      ),
      'english_words',
    );
    expect(
      previewCategory(
        terminal,
        const UserSettings(categoryIds: ['motivation']),
      ),
      'software_tips',
    );
  });

  test('family toggling: empty means all, the last one stays', () {
    final all = [for (final f in book.families) f.id];
    final withoutRiso = toggleFamily(book, const [], 'riso')!;
    expect(withoutRiso, [
      for (final id in all)
        if (id != 'riso') id,
    ]);
    expect(toggleFamily(book, withoutRiso, 'riso'), isEmpty);
    expect(toggleFamily(book, const ['riso'], 'riso'), isNull);
  });

  test('settings summary and recipe names', () {
    expect(
      styleSummary(tr, book, const UserSettings()),
      'Sürpriz · bütün aileler',
    );
    expect(
      styleSummary(
        tr,
        book,
        const UserSettings(styleFamilies: ['riso', 'terminal']),
      ),
      'Sürpriz · 2 aile',
    );
    expect(
      styleSummary(
        tr,
        book,
        const UserSettings(styleSurprise: false, styleName: 'terminal_ocean'),
      ),
      'Terminal 3',
    );
  });
}
