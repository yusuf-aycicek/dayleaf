// Pure Dart: used by the app at startup, by the tests and by
// `dart run tools/validate_content.dart`.

import 'content_models.dart';

/// Upper bounds that keep every item readable on a phone wallpaper.
abstract final class ContentLimits {
  static const int word = 32;
  static const int meaning = 100;
  static const int example = 160;
  static const int text = 120;
  static const int detail = 220;
}

enum IssueSeverity { error, warning }

class ContentIssue {
  const ContentIssue(this.severity, this.categoryId, this.itemId, this.message);

  final IssueSeverity severity;
  final String categoryId;

  /// Null when the issue concerns the whole file.
  final String? itemId;
  final String message;

  bool get isError => severity == IssueSeverity.error;

  @override
  String toString() =>
      '[${severity.name}] $categoryId${itemId == null ? '' : '/$itemId'}: $message';
}

/// Result of validating one category file.
class CategoryValidation {
  CategoryValidation(this.category);

  final ContentCategory category;
  final List<ContentItem> items = [];
  final List<ContentIssue> issues = [];

  /// Ids of items that failed validation and were left out of [items].
  final Set<String> rejectedIds = {};

  bool get hasErrors => issues.any((i) => i.isError);
}

/// Validates the decoded JSON of one category file.
///
/// Items with errors are rejected (not added to [CategoryValidation.items]),
/// so the app can keep running with the valid rest. [languages] are the
/// interface languages; every translatable field must have all of them.
CategoryValidation validateCategory(
  ContentCategory category,
  Object? json, {
  required List<String> languages,
}) {
  final result = CategoryValidation(category);
  void fileError(String message) => result.issues.add(
    ContentIssue(IssueSeverity.error, category.id, null, message),
  );

  if (json is! Map<String, Object?>) {
    fileError('root must be a JSON object');
    return result;
  }
  if (json['category'] != category.id) {
    fileError('"category" must be "${category.id}", found ${json['category']}');
  }
  if (json['kind'] != category.kind.name) {
    fileError('"kind" must be "${category.kind.name}", found ${json['kind']}');
  }
  final items = json['items'];
  if (items is! List<Object?>) {
    fileError('"items" must be a list');
    return result;
  }

  final idPattern = RegExp('^${RegExp.escape(category.idPrefix)}_\\d{4}\$');
  final seenIds = <String>{};
  final seenTexts = <String, String>{};

  for (var index = 0; index < items.length; index++) {
    final raw = items[index];
    final label = raw is Map && raw['id'] is String
        ? raw['id'] as String
        : '#${index + 1}';
    final itemIssues = <ContentIssue>[];
    void error(String m) => itemIssues.add(
      ContentIssue(IssueSeverity.error, category.id, label, m),
    );
    void warning(String m) => itemIssues.add(
      ContentIssue(IssueSeverity.warning, category.id, label, m),
    );

    if (raw is! Map<String, Object?>) {
      error('item must be an object');
      result.issues.addAll(itemIssues);
      continue;
    }

    final id = raw['id'];
    if (id is! String || !idPattern.hasMatch(id)) {
      error('"id" must look like ${category.idPrefix}_0001');
    } else if (!seenIds.add(id)) {
      error('duplicate id');
    }

    final premium = raw['isPremium'];
    if (premium != null && premium is! bool) {
      error('"isPremium" must be true or false');
    }

    final allowedKeys = switch (category.kind) {
      ContentKind.word => {
        'id',
        'level',
        'word',
        'meaning',
        'example',
        'isPremium',
      },
      ContentKind.text => {'id', 'text', 'detail', 'isPremium'},
    };
    for (final key in raw.keys) {
      if (!allowedKeys.contains(key)) {
        warning('unknown field "$key" is ignored');
      }
    }

    LocalizedText? localized(
      String field,
      int maxLength, {
      List<String>? required,
    }) {
      final value = raw[field];
      if (value is! Map<String, Object?>) {
        error('"$field" must be an object of translations');
        return null;
      }
      final map = <String, String>{};
      for (final MapEntry(:key, value: text) in value.entries) {
        if (text is! String) {
          error('"$field.$key" must be a string');
          continue;
        }
        final trimmed = text.trim();
        if (trimmed.isEmpty) continue;
        if (trimmed.length > maxLength) {
          error(
            '"$field.$key" is ${trimmed.length} characters, limit is $maxLength',
          );
        }
        map[key] = trimmed;
      }
      for (final language in required ?? languages) {
        if (!map.containsKey(language)) {
          error('missing translation "$field.$language"');
        }
      }
      return LocalizedText(map);
    }

    String? duplicateKey;
    ContentItem? item;
    switch (category.kind) {
      case ContentKind.word:
        final word = raw['word'];
        final level = CefrLevel.tryParse(raw['level']);
        if (word is! String || word.trim().isEmpty) {
          error('"word" is required');
        } else if (word.trim().length > ContentLimits.word) {
          error('"word" is longer than ${ContentLimits.word} characters');
        }
        if (level == null) {
          error(
            '"level" must be one of ${CefrLevel.values.map((l) => l.code).join(', ')}',
          );
        }
        final meaning = localized('meaning', ContentLimits.meaning);
        // The example sentence is English; the other languages translate it.
        final example = localized(
          'example',
          ContentLimits.example,
          required: {'en', ...languages}.toList(),
        );
        if (word is String) duplicateKey = _normalize(word);
        if (itemIssues.every((i) => !i.isError)) {
          item = WordItem(
            id: id as String,
            categoryId: category.id,
            isPremium: premium == true,
            word: (word as String).trim(),
            level: level!,
            meaning: meaning!,
            example: example!,
          );
        }
      case ContentKind.text:
        final text = localized('text', ContentLimits.text);
        final detail = localized('detail', ContentLimits.detail);
        if (text != null && text.has('en')) {
          duplicateKey = _normalize(text.values['en']!);
        }
        if (itemIssues.every((i) => !i.isError)) {
          item = TextItem(
            id: id as String,
            categoryId: category.id,
            isPremium: premium == true,
            text: text!,
            detail: detail!,
          );
        }
    }

    if (duplicateKey != null) {
      final previous = seenTexts[duplicateKey];
      if (previous != null) {
        error('same content as $previous');
        item = null;
      } else {
        seenTexts[duplicateKey] = label;
      }
    }

    result.issues.addAll(itemIssues);
    if (item != null) {
      result.items.add(item);
    } else if (id is String) {
      result.rejectedIds.add(id);
    }
  }
  return result;
}

/// Checks that ids are unique across categories (prefixes normally
/// guarantee it, but a copy-pasted id would slip through per-file checks).
List<ContentIssue> validateAcrossCategories(
  Iterable<CategoryValidation> results,
) {
  final owner = <String, String>{};
  final issues = <ContentIssue>[];
  for (final result in results) {
    for (final item in result.items) {
      final other = owner[item.id];
      if (other != null && other != result.category.id) {
        issues.add(
          ContentIssue(
            IssueSeverity.error,
            result.category.id,
            item.id,
            'id is also used in $other',
          ),
        );
      }
      owner[item.id] = result.category.id;
    }
  }
  return issues;
}

String _normalize(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .trim();
