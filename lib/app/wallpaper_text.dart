import '../core/clock.dart';
import '../data/content_models.dart';
import '../l10n/gen/app_localizations.dart';
import '../rendering/wallpaper_content.dart';
import 'daily_wallpaper_service.dart' show categoryLabel;

/// Date texts of [day] in the language of [l10n]. Month and weekday names
/// come from the ARB files, so this works in the background engine too
/// (no date-format data to load).
WallpaperLabels wallpaperLabels(AppLocalizations l10n, int day) {
  final date = dateOfDayIndex(day);
  final months = l10n.wpMonths.split(',');
  final weekdays = l10n.wpWeekdays.split(',');
  final dayOfYear = date.difference(DateTime.utc(date.year)).inDays + 1;
  final daysInYear = DateTime.utc(date.year + 1)
      .difference(DateTime.utc(date.year))
      .inDays;
  final month = months[date.month - 1].trim();
  return WallpaperLabels(
    longDate: l10n.wpLongDate(date.day, month, date.year),
    year: date.year,
    month: month,
    weekday: weekdays[date.weekday - 1].trim(),
    dayOfMonth: date.day,
    dayOfYear: dayOfYear,
    daysInYear: daysInYear,
    dayOfYearText: l10n.wpDayOfYear(dayOfYear),
    daysLeftText: l10n.wpDaysLeft(daysInYear - dayOfYear),
    wordOfDay: l10n.wpWordOfDay,
    keyLevel: l10n.wpKeyLevel,
    keyType: l10n.wpKeyType,
    keyMeaning: l10n.wpKeyMeaning,
    keyCategory: l10n.wpKeyCategory,
  );
}

String partOfSpeechName(AppLocalizations l10n, PartOfSpeech p) => switch (p) {
  PartOfSpeech.noun => l10n.posNoun,
  PartOfSpeech.verb => l10n.posVerb,
  PartOfSpeech.adj => l10n.posAdj,
  PartOfSpeech.adv => l10n.posAdv,
  PartOfSpeech.phrase => l10n.posPhrase,
};

/// The wallpaper text of [item] on [day] in the language of [l10n].
WallpaperContent wallpaperContentFor(
  ContentItem item, {
  required AppLocalizations l10n,
  required int day,
}) {
  final language = l10n.localeName.split('_').first;
  final labels = wallpaperLabels(l10n, day);
  final label = categoryLabel(l10n, item.categoryId);
  return switch (item) {
    WordItem() => WallpaperContent(
      language: language,
      categoryId: item.categoryId,
      categoryLabel: label,
      day: day,
      labels: labels,
      level: item.level.code,
      title: item.word,
      titleLanguage: 'en',
      subtitle: item.meaning.resolve(language),
      body: item.example.values['en'] ?? item.example.resolve(language),
      footnote: language == 'en' ? null : item.example.values[language],
      syllables: item.syllables,
      ipa: item.ipa,
      partOfSpeech: item.partOfSpeech?.abbreviation,
      partOfSpeechName: item.partOfSpeech == null
          ? null
          : partOfSpeechName(l10n, item.partOfSpeech!),
    ),
    TextItem() => WallpaperContent(
      language: language,
      categoryId: item.categoryId,
      categoryLabel: label,
      day: day,
      labels: labels,
      title: item.text.resolve(language),
      body: item.detail.resolve(language),
    ),
  };
}
