import 'dart:convert';
import 'dart:io';

import 'package:dayleaf/data/content_models.dart';
import 'package:dayleaf/rendering/style/backgrounds.dart';
import 'package:dayleaf/rendering/style/layouts.dart';
import 'package:dayleaf/rendering/style/style_book.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/samples.dart';

Map<String, Object?> fileJson() =>
    jsonDecode(File(StyleBook.assetPath).readAsStringSync())
        as Map<String, Object?>;

StyleBook parse(Map<String, Object?> json) =>
    StyleBook.parse(json, languages: const ['en', 'tr']);

/// The file with one more recipe line (and palette) appended.
Map<String, Object?> plus({
  Map<String, Object?>? recipe,
  Map<String, Object?>? palette,
}) {
  final json = fileJson();
  if (recipe != null) json['recipes'] = [...json['recipes'] as List, recipe];
  if (palette != null) {
    json['palettes'] = [...json['palettes'] as List, palette];
  }
  return json;
}

Map<String, Object?> recipe(
  String name, {
  Map<String, Object?> set = const {},
}) => {
  'name': name,
  'family': 'terminal',
  'background': 'terminal',
  'layout': 'terminal',
  'palette': 'term_amber',
  'fonts': 'jetbrains',
  'premium': false,
  ...set,
};

void main() {
  final book = loadStyleBook();

  test('recipes.json is valid', () {
    expect(book.errors, isEmpty);
  });

  test('at least 40 recipes, 4 to 8 in every family', () {
    expect(book.recipes.length, greaterThanOrEqualTo(40));
    for (final f in book.families) {
      expect(book.ofFamily(f.id).length, inInclusiveRange(4, 8), reason: f.id);
    }
  });

  test('every part in the code is used, every category has a family', () {
    expect({
      for (final r in book.recipes) r.background.id,
    }, StyleBackgrounds.all.keys.toSet());
    expect({
      for (final r in book.recipes) r.layout.id,
    }, StyleLayouts.all.keys.toSet());
    final categories = {for (final c in ContentCatalog.categories) c.id};
    for (final f in book.families) {
      expect(f.fits, isNotEmpty, reason: f.id);
      expect(categories.containsAll(f.fits), isTrue, reason: f.id);
    }
    for (final c in categories) {
      expect(book.families.any((f) => f.fits.contains(c)), isTrue, reason: c);
    }
  });

  test('adding a style is one line', () {
    final more = parse(plus(recipe: recipe('terminal_extra')));
    expect(more.errors, isEmpty);
    expect(more.recipes.length, book.recipes.length + 1);
    expect(more.byName('terminal_extra')!.palette.id, 'term_amber');
  });

  test('a recipe with an unknown part is rejected', () {
    for (final (key, value) in [
      ('family', 'nope'),
      ('background', 'marble'),
      ('layout', 'spiral'),
      ('palette', 'rainbow'),
      ('fonts', 'comic'),
    ]) {
      final r = parse(plus(recipe: recipe('broken', set: {key: value})));
      expect(r.errors, [contains('unknown $key "$value"')], reason: key);
      expect(r.byName('broken'), isNull);
    }
  });

  test('duplicate and badly named recipes are rejected', () {
    expect(parse(plus(recipe: recipe('terminal_amber'))).errors, [
      contains('duplicate name'),
    ]);
    expect(parse(plus(recipe: recipe('Terminal Amber'))).errors, [
      contains('lower_snake_case'),
    ]);
  });

  test('low text contrast is rejected', () {
    final grey = {
      'id': 'grey',
      'ground': '#777777',
      'paper': '#777777',
      'ink': '#FFFFFF',
      'muted': '#DDDDDD',
      'accent': '#FFD000',
      'accent2': '#000000',
      'decor': '#666666',
    };
    expect(
      parse(plus(palette: grey)).errors.single,
      startsWith('palette grey: text contrast'),
    );

    // The accent is text in the terminal, only a shape in the riso poster.
    final pink = {
      ...grey,
      'id': 'pink',
      'paper': '#F3EFE6',
      'ink': '#141414',
      'muted': '#4D4A45',
      'accent': '#FF5C8A',
    };
    final terminal = parse(
      plus(
        palette: pink,
        recipe: recipe('pink_term', set: {'palette': 'pink'}),
      ),
    );
    expect(terminal.errors.single, contains('accent'));
    final riso = parse(
      plus(
        palette: pink,
        recipe: recipe(
          'pink_riso',
          set: {'palette': 'pink', 'layout': 'poster_offset'},
        ),
      ),
    );
    expect(riso.errors, isEmpty);
  });

  test('fonts that are not bundled are rejected', () {
    final json = fileJson();
    json['fonts'] = [
      ...json['fonts'] as List,
      {'id': 'comic', 'display': 'ComicSans', 'body': 'Manrope'},
    ];
    expect(parse(json).errors, [contains('not bundled: ComicSans')]);
  });

  test('family names exist in every language', () {
    final json = fileJson();
    json['families'] = [
      ...json['families'] as List,
      {
        'id': 'x',
        'name': {'en': 'X'},
        'fits': <String>[],
      },
    ];
    expect(
      parse(json).errors,
      containsAll([
        contains('missing name for tr'),
        contains('family x has no recipes'),
      ]),
    );
  });
}
