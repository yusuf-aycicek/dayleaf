import 'package:dailywall/data/content_models.dart';
import 'package:dailywall/data/content_repository.dart';
import 'package:dailywall/domain/user_settings.dart';
import 'package:dailywall/l10n/gen/app_localizations.dart';
import 'package:dailywall/ui/widgets/template_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final en = lookupAppLocalizations(const Locale('en'));
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
        settings: UserSettings(categoryIds: [c.id], englishLevel: CefrLevel.b2),
        language: 'en',
        l10n: en,
      );
      final item = library
          .itemsOf(c.id)
          .firstWhere(
            (i) =>
                sample.title ==
                (i is WordItem ? i.word : (i as TextItem).text.resolve('en')),
          );
      expect(sample.badge, contains(en.categoryLabelFor(c.id)), reason: c.id);
      if (item is WordItem) expect(item.level, CefrLevel.b2);
    }
  });

  test('before the content loads the sample is a motivation line', () {
    final sample = previewSample(
      library: null,
      settings: const UserSettings(categoryIds: ['english_words']),
      language: 'en',
      l10n: en,
    );
    expect(sample.badge, 'Motivation');
  });
}

extension on AppLocalizations {
  String categoryLabelFor(String id) => switch (id) {
    'english_words' => categoryEnglishWords,
    'software_tips' => categorySoftwareTips,
    'motivation' => categoryMotivation,
    _ => categoryGeneralKnowledge,
  };
}
