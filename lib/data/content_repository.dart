import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'content_models.dart';
import 'content_schema.dart';

/// Loads and validates every category file from the asset bundle.
///
/// Invalid items are skipped so one bad line never breaks the app. In debug
/// builds the problems are also thrown so they are noticed during
/// development; `test/data/content_files_test.dart` and
/// `tools/validate_content.dart` catch them before a release.
class ContentRepository {
  ContentRepository({
    AssetBundle? bundle,
    required this.languages,
    this.throwOnErrors = kDebugMode,
  }) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final List<String> languages;

  /// Debug builds fail loudly on invalid content; release builds skip it.
  final bool throwOnErrors;

  ContentLibrary? _cache;
  final List<ContentIssue> issues = [];

  Future<ContentLibrary> load() async {
    final cached = _cache;
    if (cached != null) return cached;

    final results = <CategoryValidation>[];
    for (final category in ContentCatalog.categories) {
      final raw = await _bundle.loadString(category.assetPath);
      results.add(
        validateCategory(category, jsonDecode(raw), languages: languages),
      );
    }
    issues
      ..clear()
      ..addAll(results.expand((r) => r.issues))
      ..addAll(validateAcrossCategories(results));

    final errors = issues.where((i) => i.isError).toList();
    if (errors.isNotEmpty) {
      debugPrint('dayleaf: ${errors.length} content error(s) skipped:');
      for (final e in errors) {
        debugPrint('  $e');
      }
      if (throwOnErrors) {
        throw FlutterError(
          'Invalid content in assets/content. Run '
          '`dart run tools/validate_content.dart` for a report.\n'
          '${errors.take(10).join('\n')}',
        );
      }
    }

    return _cache = ContentLibrary({
      for (final r in results) r.category.id: List.unmodifiable(r.items),
    });
  }
}
