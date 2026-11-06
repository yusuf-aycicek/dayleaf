import '../data/content_models.dart';

/// The text of one wallpaper, already resolved to one language.
class WallpaperContent {
  const WallpaperContent({
    required this.language,
    required this.badge,
    required this.title,
    String? titleLanguage,
    this.subtitle,
    this.body,
    this.footnote,
  }) : titleLanguage = titleLanguage ?? language;

  /// English word: badge "B1 · English word", title the word, subtitle the
  /// meaning, body the English example, footnote its translation (omitted
  /// when the interface is English). Other categories: title the text and
  /// body the detail.
  factory WallpaperContent.fromItem(
    ContentItem item, {
    required String language,
    required String categoryLabel,
  }) => switch (item) {
    WordItem() => WallpaperContent(
      language: language,
      badge: '${item.level.code} · $categoryLabel',
      title: item.word,
      titleLanguage: 'en',
      subtitle: item.meaning.resolve(language),
      body: item.example.values['en'] ?? item.example.resolve(language),
      footnote: language == 'en' ? null : item.example.values[language],
    ),
    TextItem() => WallpaperContent(
      language: language,
      badge: categoryLabel,
      title: item.text.resolve(language),
      body: item.detail.resolve(language),
    ),
  };

  final String language;
  final String badge;
  final String title;

  /// English words keep English casing rules even on a Turkish wallpaper.
  final String titleLanguage;
  final String? subtitle;
  final String? body;
  final String? footnote;
}

/// `toUpperCase` that knows Turkish dotted/dotless i (i→İ, ı→I).
String upperFor(String text, String language) {
  if (language == 'tr' || language == 'az') {
    text = text.replaceAll('i', 'İ').replaceAll('ı', 'I');
  }
  return text.toUpperCase();
}
