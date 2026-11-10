import 'package:flutter/painting.dart';

import '../color_math.dart';
import '../layout.dart';
import 'backgrounds.dart';
import 'fonts.dart';
import 'layouts.dart';

/// Colors of one recipe. Text is drawn in [ink], [muted] and [accent]; the
/// background generators use [ground], [paper], [accent2] and [decor].
class Palette {
  const Palette({
    required this.id,
    required this.ground,
    required this.paper,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.accent2,
    required this.decor,
  });

  final String id;

  /// The whole canvas (the wall behind a hanging sheet, for example).
  final Color ground;

  /// What the text sits on: the sheet, the card, or the ground itself.
  final Color paper;
  final Color ink;

  /// Secondary text.
  final Color muted;

  /// Highlights that are also text ("adj.", numbers, the day number).
  final Color accent;

  /// Shapes only, never text (risograph blue, the calendar binding).
  final Color accent2;

  /// Pattern strokes and dots (contours, ruled lines, halftone).
  final Color decor;

  /// Colors that can be used for text.
  Map<String, Color> get textColors => {
    'ink': ink,
    'muted': muted,
    'accent': accent,
  };

  /// Empty if every color in [roles] reads on the paper; otherwise which
  /// do not, with their contrast.
  String lowContrast(Set<String> roles) {
    final low = [
      for (final MapEntry(:key, :value) in textColors.entries)
        if (roles.contains(key) &&
            contrastRatio(value, paper) < minTextContrast)
          '$key ${contrastRatio(value, paper).toStringAsFixed(2)}:1',
    ];
    return low.isEmpty
        ? ''
        : 'text contrast on paper below $minTextContrast:1 (${low.join(', ')})';
  }
}

/// A display face for headlines and a body face for running text.
class FontPair {
  const FontPair({
    required this.id,
    required this.display,
    required this.displayWeight,
    required this.body,
    required this.bodyWeight,
    this.mono = BundledFonts.jetBrainsMono,
  });

  final String id;
  final String display;
  final double displayWeight;
  final String body;
  final double bodyWeight;

  /// For labels, keys and numbers in layouts that use a monospace accent.
  final String mono;
}

/// A group of recipes that look alike, shown as one row in the picker.
class StyleFamily {
  const StyleFamily({
    required this.id,
    required this.names,
    required this.fits,
  });

  final String id;

  /// Display name per language.
  final Map<String, String> names;

  /// Categories this family suits; "Surprise me" prefers these.
  final List<String> fits;

  String name(String language) => names[language] ?? names['en'] ?? id;
}

/// One wallpaper style: which background, layout, palette and fonts.
class StyleRecipe {
  const StyleRecipe({
    required this.name,
    required this.family,
    required this.background,
    required this.layout,
    required this.palette,
    required this.fonts,
    this.isPremium = false,
  });

  final String name;
  final StyleFamily family;
  final StyleBackground background;
  final StyleLayout layout;
  final Palette palette;
  final FontPair fonts;

  /// Reserved for a future premium tier. Everything is free for now.
  final bool isPremium;
}

/// Every recipe in `assets/styles/recipes.json`, validated.
class StyleBook {
  StyleBook._(this.families, this.recipes, this.errors);

  static const assetPath = 'assets/styles/recipes.json';

  final List<StyleFamily> families;
  final List<StyleRecipe> recipes;

  /// Problems found while reading; invalid recipes are left out.
  final List<String> errors;

  StyleRecipe? byName(String? name) {
    for (final r in recipes) {
      if (r.name == name) return r;
    }
    return null;
  }

  List<StyleRecipe> ofFamily(String familyId) => [
    for (final r in recipes)
      if (r.family.id == familyId) r,
  ];

  static final _namePattern = RegExp(r'^[a-z][a-z0-9_]*$');

  /// Reads the JSON. Unknown parts, duplicate names, fonts that are not
  /// bundled and text colors below [minTextContrast] on the paper are
  /// errors; the recipe (or palette) with the error is dropped.
  factory StyleBook.parse(
    Map<String, Object?> json, {
    required List<String> languages,
    Map<String, StyleBackground>? backgrounds,
    Map<String, StyleLayout>? layouts,
    Set<String>? fontFamilies,
  }) {
    backgrounds ??= StyleBackgrounds.all;
    layouts ??= StyleLayouts.all;
    fontFamilies ??= BundledFonts.families;
    final errors = <String>[];
    List<Map<String, Object?>> list(String key) {
      final v = json[key];
      if (v is! List) {
        errors.add('"$key" must be a list');
        return const [];
      }
      final out = <Map<String, Object?>>[];
      for (final e in v) {
        if (e is Map<String, Object?>) {
          out.add(e);
        } else {
          errors.add('"$key" has an entry that is not an object');
        }
      }
      return out;
    }

    String? str(Map<String, Object?> m, String key, String where) {
      final v = m[key];
      if (v is String && v.isNotEmpty) return v;
      errors.add('$where: "$key" is required');
      return null;
    }

    final families = <String, StyleFamily>{};
    for (final f in list('families')) {
      final id = str(f, 'id', 'family');
      if (id == null) continue;
      final rawNames = f['name'];
      final names = <String, String>{
        if (rawNames is Map)
          for (final e in rawNames.entries)
            if (e.value is String) e.key as String: e.value as String,
      };
      final missing = [
        for (final l in languages)
          if (!names.containsKey(l)) l,
      ];
      if (missing.isNotEmpty) {
        errors.add('family $id: missing name for ${missing.join(', ')}');
      }
      final fits = f['fits'];
      if (families.containsKey(id)) errors.add('family $id: duplicate id');
      families[id] = StyleFamily(
        id: id,
        names: names,
        fits: [
          if (fits is List)
            for (final c in fits)
              if (c is String) c,
        ],
      );
    }

    final palettes = <String, Palette>{};
    for (final p in list('palettes')) {
      final id = str(p, 'id', 'palette');
      if (id == null) continue;
      Color? color(String key) {
        final v = p[key];
        final m = v is String
            ? RegExp(r'^#([0-9A-Fa-f]{6})$').firstMatch(v)
            : null;
        if (m == null) {
          errors.add('palette $id: "$key" must be a color like #1A2B3C');
          return null;
        }
        return Color(0xFF000000 | int.parse(m.group(1)!, radix: 16));
      }

      final c = {
        for (final k in [
          'ground',
          'paper',
          'ink',
          'muted',
          'accent',
          'accent2',
          'decor',
        ])
          k: color(k),
      };
      if (c.values.any((v) => v == null)) continue;
      final palette = Palette(
        id: id,
        ground: c['ground']!,
        paper: c['paper']!,
        ink: c['ink']!,
        muted: c['muted']!,
        accent: c['accent']!,
        accent2: c['accent2']!,
        decor: c['decor']!,
      );
      final low = palette.lowContrast(const {'ink', 'muted'});
      if (low.isNotEmpty) {
        errors.add('palette $id: $low');
        continue;
      }
      if (palettes.containsKey(id)) errors.add('palette $id: duplicate id');
      palettes[id] = palette;
    }

    final fonts = <String, FontPair>{};
    for (final f in list('fonts')) {
      final id = str(f, 'id', 'font pair');
      final display = str(f, 'display', 'font pair $id');
      final body = str(f, 'body', 'font pair $id');
      final mono = f['mono'] as String? ?? BundledFonts.jetBrainsMono;
      if (id == null || display == null || body == null) continue;
      final unknown = [
        for (final family in [display, body, mono])
          if (!fontFamilies.contains(family)) family,
      ];
      if (unknown.isNotEmpty) {
        errors.add('font pair $id: not bundled: ${unknown.join(', ')}');
        continue;
      }
      double weight(String key) => (f[key] as num?)?.toDouble() ?? 400;
      fonts[id] = FontPair(
        id: id,
        display: display,
        displayWeight: weight('displayWeight'),
        body: body,
        bodyWeight: weight('bodyWeight'),
        mono: mono,
      );
    }

    final recipes = <StyleRecipe>[];
    final names = <String>{};
    for (final r in list('recipes')) {
      final name = str(r, 'name', 'recipe');
      if (name == null) continue;
      final where = 'recipe $name';
      if (!_namePattern.hasMatch(name)) {
        errors.add('$where: name must be lower_snake_case');
        continue;
      }
      if (!names.add(name)) {
        errors.add('$where: duplicate name');
        continue;
      }
      T? part<T>(String key, Map<String, T> from) {
        final id = r[key];
        final value = from[id];
        if (value == null) errors.add('$where: unknown $key "$id"');
        return value;
      }

      final family = part('family', families);
      final background = part('background', backgrounds);
      final layout = part('layout', layouts);
      final palette = part('palette', palettes);
      final pair = part('fonts', fonts);
      if (palette != null && layout != null) {
        final low = palette.lowContrast(layout.textRoles);
        if (low.isNotEmpty) {
          errors.add('$where: ${layout.id} draws text in $low');
          continue;
        }
      }
      final premium = r['premium'] ?? false;
      if (premium is! bool) errors.add('$where: "premium" must be a bool');
      if (family == null ||
          background == null ||
          layout == null ||
          palette == null ||
          pair == null ||
          premium is! bool) {
        continue;
      }
      recipes.add(
        StyleRecipe(
          name: name,
          family: family,
          background: background,
          layout: layout,
          palette: palette,
          fonts: pair,
          isPremium: premium,
        ),
      );
    }

    final used = {for (final r in recipes) r.family.id};
    for (final f in families.keys) {
      if (!used.contains(f)) errors.add('family $f has no recipes');
    }
    return StyleBook._(
      [
        for (final f in families.values)
          if (used.contains(f.id)) f,
      ],
      recipes,
      errors,
    );
  }
}
