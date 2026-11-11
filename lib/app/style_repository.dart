import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/style_selector.dart';
import '../rendering/style/style_book.dart';

/// Loads `assets/styles/recipes.json` once. Invalid recipes are skipped and
/// logged; `test/rendering/style_book_test.dart` keeps the file clean.
class StyleRepository {
  StyleRepository({AssetBundle? bundle, required this.languages})
    : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final List<String> languages;
  StyleBook? _cache;

  Future<StyleBook> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final book = StyleBook.parse(
      jsonDecode(await _bundle.loadString(StyleBook.assetPath))
          as Map<String, Object?>,
      languages: languages,
    );
    for (final e in book.errors) {
      debugPrint('dayleaf: style: $e');
    }
    return _cache = book;
  }
}

extension StyleChoices on StyleBook {
  List<StyleChoice> get choices => [
    for (final r in recipes) StyleChoice(r.name, r.family.id, r.family.fits),
  ];
}
