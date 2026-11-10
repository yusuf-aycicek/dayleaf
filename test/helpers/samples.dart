import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:dailywall/app/wallpaper_text.dart';
import 'package:dailywall/core/clock.dart';
import 'package:dailywall/data/content_models.dart';
import 'package:dailywall/data/content_schema.dart';
import 'package:dailywall/l10n/gen/app_localizations.dart';
import 'package:dailywall/rendering/style/style_book.dart';
import 'package:dailywall/rendering/wallpaper_content.dart';

/// 10 November 2026, the day of the reference designs.
final sampleDay = dayIndexOf(DateTime(2026, 11, 10));

AppLocalizations l10nFor(String language) =>
    lookupAppLocalizations(Locale(language));

List<ContentItem> realItems() => [
  for (final c in ContentCatalog.categories)
    ...validateCategory(
      c,
      jsonDecode(File(c.assetPath).readAsStringSync()),
      languages: const ['en', 'tr'],
    ).items,
];

StyleBook loadStyleBook() => StyleBook.parse(
  jsonDecode(File(StyleBook.assetPath).readAsStringSync())
      as Map<String, Object?>,
  languages: const ['en', 'tr'],
);

/// One real item per category: "resilient" for words.
WallpaperContent sampleFor(String categoryId, {String language = 'tr'}) {
  final items = realItems().where((i) => i.categoryId == categoryId);
  final item = categoryId == ContentCatalog.englishWords.id
      ? items.firstWhere((i) => (i as WordItem).word == 'resilient')
      : items.first;
  return wallpaperContentFor(item, l10n: l10nFor(language), day: sampleDay);
}

/// The longest real items in both languages plus synthetic ones at the
/// schema's length limits.
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
  final labels = wallpaperLabels(l10nFor('tr'), sampleDay);
  return [
    for (final i in [
      ...items.take(4),
      ...items.whereType<WordItem>().where((w) => w.word == 'opportunity'),
    ])
      for (final lang in ['tr', 'en'])
        wallpaperContentFor(i, l10n: l10nFor(lang), day: sampleDay),
    WallpaperContent(
      language: 'tr',
      categoryId: 'english_words',
      categoryLabel: 'İngilizce kelime',
      day: sampleDay,
      labels: labels,
      level: 'C1',
      title: 'w' * ContentLimits.word,
      titleLanguage: 'en',
      syllables: 'w' * ContentLimits.word,
      ipa: 'ɪ' * ContentLimits.ipa,
      partOfSpeech: 'adj.',
      partOfSpeechName: 'sıfat',
      subtitle: words(ContentLimits.meaning),
      body: words(ContentLimits.example),
      footnote: words(ContentLimits.example),
    ),
    WallpaperContent(
      language: 'tr',
      categoryId: 'general_knowledge',
      categoryLabel: 'Genel kültür bilgisi',
      day: sampleDay,
      labels: labels,
      title: words(ContentLimits.text),
      body: words(ContentLimits.detail),
    ),
  ];
}
