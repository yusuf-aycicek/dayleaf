/// Date texts of a wallpaper, already in the wallpaper's language.
class WallpaperLabels {
  const WallpaperLabels({
    required this.longDate,
    required this.year,
    required this.month,
    required this.weekday,
    required this.dayOfMonth,
    required this.dayOfYear,
    required this.daysInYear,
    required this.dayOfYearText,
    required this.daysLeftText,
    required this.wordOfDay,
    required this.keyLevel,
    required this.keyType,
    required this.keyMeaning,
    required this.keyCategory,
  });

  /// "10 Kasım 2026" / "November 10, 2026".
  final String longDate;
  final int year;

  /// Month and weekday names, as written in running text ("Kasım", "Salı").
  final String month;
  final String weekday;
  final int dayOfMonth;
  final int dayOfYear;
  final int daysInYear;

  /// "Yılın 314. günü", "Kalan 51 gün".
  final String dayOfYearText;
  final String daysLeftText;

  /// "Günün kelimesi".
  final String wordOfDay;

  /// Keys of the terminal layout: "seviye", "tür", "anlam", "kategori".
  final String keyLevel;
  final String keyType;
  final String keyMeaning;
  final String keyCategory;
}

/// The text of one wallpaper, already resolved to one language.
///
/// English word: [title] the word, [subtitle] the meaning, [body] the
/// English example and [footnote] its translation (null when the interface
/// is English). Other categories: [title] the text and [body] the detail.
class WallpaperContent {
  const WallpaperContent({
    required this.language,
    required this.categoryId,
    required this.categoryLabel,
    required this.day,
    required this.labels,
    required this.title,
    String? titleLanguage,
    this.level,
    this.subtitle,
    this.body,
    this.footnote,
    this.syllables,
    this.ipa,
    this.partOfSpeech,
    this.partOfSpeechName,
  }) : titleLanguage = titleLanguage ?? language;

  final String language;
  final String categoryId;
  final String categoryLabel;

  /// Day index (days since 1970-01-01); seeds the background.
  final int day;
  final WallpaperLabels labels;

  final String title;

  /// English words keep English casing rules even on a Turkish wallpaper.
  final String titleLanguage;

  /// CEFR level code for English words ("B1"), null otherwise.
  final String? level;
  final String? subtitle;
  final String? body;
  final String? footnote;

  /// Dictionary details of English words, when the content has them.
  final String? syllables;
  final String? ipa;

  /// "adj." and its localized name ("sıfat").
  final String? partOfSpeech;
  final String? partOfSpeechName;

  bool get isWord => level != null;

  /// "B1 · İngilizce kelime" or the category label.
  String get badge => level == null ? categoryLabel : '$level · $categoryLabel';
}

/// `toUpperCase` that knows Turkish dotted/dotless i (i→İ, ı→I).
String upperFor(String text, String language) {
  if (language == 'tr' || language == 'az') {
    text = text.replaceAll('i', 'İ').replaceAll('ı', 'I');
  }
  return text.toUpperCase();
}
