// Validates the real files in assets/content with the app's own rules,
// so CI fails if a content edit breaks the schema.

import 'dart:convert';
import 'dart:io';

import 'package:dailywall/data/content_models.dart';
import 'package:dailywall/data/content_repository.dart';
import 'package:dailywall/data/content_schema.dart';
import 'package:dailywall/l10n/gen/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final languages = AppLocalizations.supportedLocales
    .map((l) => l.languageCode)
    .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final results = [
    for (final category in ContentCatalog.categories)
      validateCategory(
        category,
        jsonDecode(File(category.assetPath).readAsStringSync()),
        languages: languages,
      ),
  ];

  for (final r in results) {
    group(r.category.id, () {
      test('has no validation issues', () {
        expect(r.issues, isEmpty, reason: r.issues.join('\n'));
      });
      test('has at least 30 items', () {
        expect(r.items.length, greaterThanOrEqualTo(30));
      });
    });
  }

  test('ids are unique across categories', () {
    expect(validateAcrossCategories(results), isEmpty);
  });

  test('every CEFR level has English words', () {
    final words = results
        .firstWhere((r) => r.category == ContentCatalog.englishWords)
        .items
        .whereType<WordItem>();
    for (final level in CefrLevel.values) {
      expect(
        words.where((w) => w.level == level),
        isNotEmpty,
        reason: level.code,
      );
    }
  });

  test('everything is free for now', () {
    expect(ContentCatalog.categories.where((c) => c.isPremium), isEmpty);
    expect(results.expand((r) => r.items).where((i) => i.isPremium), isEmpty);
  });

  test('repository loads all categories from the asset bundle', () async {
    final repo = ContentRepository(bundle: rootBundle, languages: languages);
    final library = await repo.load();
    for (final c in ContentCatalog.categories) {
      expect(
        library.itemsOf(c.id),
        hasLength(greaterThanOrEqualTo(30)),
        reason: c.id,
      );
    }
    expect(repo.issues, isEmpty);
    expect(library.findById('en_0013'), isA<WordItem>());
  });
}
