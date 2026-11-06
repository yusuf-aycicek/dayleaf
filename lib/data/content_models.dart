// Pure Dart: no Flutter imports, so `tools/validate_content.dart` can use it
// with `dart run`.

/// CEFR levels used by the English words category.
enum CefrLevel {
  a1('A1'),
  a2('A2'),
  b1('B1'),
  b2('B2'),
  c1('C1');

  const CefrLevel(this.code);
  final String code;

  static CefrLevel? tryParse(Object? code) {
    for (final level in values) {
      if (level.code == code) return level;
    }
    return null;
  }
}

/// How a category's items are shaped.
enum ContentKind {
  /// `word`, `level`, `meaning{}`, `example{}`.
  word,

  /// `text{}`, `detail{}`.
  text,
}

/// A string in several languages, keyed by language code (`tr`, `en`, ...).
class LocalizedText {
  const LocalizedText(this.values);

  final Map<String, String> values;

  /// The text in [language], falling back to English, then to any value.
  String resolve(String language) =>
      values[language] ?? values['en'] ?? values.values.first;

  bool has(String language) => (values[language] ?? '').trim().isNotEmpty;
}

/// One piece of daily content.
sealed class ContentItem {
  const ContentItem({
    required this.id,
    required this.categoryId,
    this.isPremium = false,
  });

  final String id;
  final String categoryId;

  /// Reserved for a future premium tier. Everything is free for now.
  final bool isPremium;
}

final class WordItem extends ContentItem {
  const WordItem({
    required super.id,
    required super.categoryId,
    super.isPremium,
    required this.word,
    required this.level,
    required this.meaning,
    required this.example,
  });

  /// The English word or phrase.
  final String word;
  final CefrLevel level;

  /// Meaning of the word in each interface language.
  final LocalizedText meaning;

  /// Example sentence: `en` is the sentence, other languages translate it.
  final LocalizedText example;
}

final class TextItem extends ContentItem {
  const TextItem({
    required super.id,
    required super.categoryId,
    super.isPremium,
    required this.text,
    required this.detail,
  });

  final LocalizedText text;
  final LocalizedText detail;
}

/// A category the user can subscribe to. Adding one: create
/// `assets/content/<id>.json`, add an entry to [ContentCatalog.categories]
/// and a label in the ARB files.
class ContentCategory {
  const ContentCategory({
    required this.id,
    required this.kind,
    required this.idPrefix,
    this.isPremium = false,
  });

  final String id;
  final ContentKind kind;

  /// Every item id in this category looks like `<idPrefix>_0001`.
  final String idPrefix;

  /// Reserved for a future premium tier. Everything is free for now.
  final bool isPremium;

  String get assetPath => 'assets/content/$id.json';
}

abstract final class ContentCatalog {
  static const englishWords = ContentCategory(
    id: 'english_words',
    kind: ContentKind.word,
    idPrefix: 'en',
  );
  static const softwareTips = ContentCategory(
    id: 'software_tips',
    kind: ContentKind.text,
    idPrefix: 'sw',
  );
  static const motivation = ContentCategory(
    id: 'motivation',
    kind: ContentKind.text,
    idPrefix: 'mo',
  );
  static const generalKnowledge = ContentCategory(
    id: 'general_knowledge',
    kind: ContentKind.text,
    idPrefix: 'gk',
  );

  /// Display and rotation order.
  static const List<ContentCategory> categories = [
    englishWords,
    softwareTips,
    motivation,
    generalKnowledge,
  ];

  static ContentCategory? byId(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// All loaded content, by category id.
class ContentLibrary {
  const ContentLibrary(this.itemsByCategory);

  final Map<String, List<ContentItem>> itemsByCategory;

  List<ContentItem> itemsOf(String categoryId) =>
      itemsByCategory[categoryId] ?? const [];

  ContentItem? findById(String id) {
    for (final items in itemsByCategory.values) {
      for (final item in items) {
        if (item.id == id) return item;
      }
    }
    return null;
  }
}
