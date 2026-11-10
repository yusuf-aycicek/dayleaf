import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/daily_wallpaper_service.dart' show categoryLabel;
import '../../app/providers.dart';
import '../../app/wallpaper_text.dart';
import '../../core/clock.dart';
import '../../data/content_models.dart';
import '../../domain/user_settings.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../rendering/style/style_book.dart';
import '../../rendering/wallpaper_content.dart';
import '../../rendering/wallpaper_renderer.dart';

/// What the style previews show: a real item of [categoryId] (at the
/// user's English level for words), so the badge and the text always
/// match. Until the content has loaded, a motivation line with the
/// motivation badge.
WallpaperContent previewSample({
  required ContentLibrary? library,
  required String? categoryId,
  required CefrLevel level,
  required AppLocalizations l10n,
  int? day,
}) {
  day ??= dayIndexOf(DateTime.now());
  final items = categoryId == null || library == null
      ? const <ContentItem>[]
      : library.itemsOf(categoryId);
  if (items.isNotEmpty) {
    final item = items.firstWhere(
      (i) => i is! WordItem || i.level == level,
      orElse: () => items.first,
    );
    return wallpaperContentFor(item, l10n: l10n, day: day);
  }
  final tr = l10n.localeName.startsWith('tr');
  return WallpaperContent(
    language: tr ? 'tr' : 'en',
    categoryId: 'motivation',
    categoryLabel: categoryLabel(l10n, 'motivation'),
    day: day,
    labels: wallpaperLabels(l10n, day),
    title: tr ? 'Küçük adımlar birikir.' : 'Small steps add up.',
    body: tr
        ? 'Günde on dakika, bir yılda 60 saatten fazla eder.'
        : 'Ten minutes a day is more than 60 hours a year.',
  );
}

/// The category a family's previews show: one of the user's interests the
/// family suits, else the family's first suited category.
String? previewCategory(StyleFamily family, UserSettings settings) {
  for (final c in family.fits) {
    if (settings.categoryIds.contains(c)) return c;
  }
  return family.fits.firstOrNull ?? settings.categoryIds.firstOrNull;
}

/// "Sözlük 2": the name of a recipe in the picker.
String recipeLabel(AppLocalizations l10n, StyleBook book, StyleRecipe r) {
  final lang = l10n.localeName.split('_').first;
  return l10n.styleNumbered(
    r.family.name(lang),
    book.ofFamily(r.family.id).indexOf(r) + 1,
  );
}

/// Summary for the settings row.
String styleSummary(AppLocalizations l10n, StyleBook? book, UserSettings s) {
  if (s.styleSurprise) {
    final n = book == null
        ? s.styleFamilies.length
        : book.families.where((f) => s.styleFamilies.contains(f.id)).length;
    return n == 0 || (book != null && n == book.families.length)
        ? l10n.styleSummaryAll
        : l10n.styleSummarySurprise(n);
  }
  final r = book?.byName(s.styleName) ?? book?.recipes.firstOrNull;
  return r == null || book == null ? '' : recipeLabel(l10n, book, r);
}

/// Adds or removes [family] from the surprise families. An empty list
/// means every family; the last family cannot be removed (returns null).
List<String>? toggleFamily(
  StyleBook book,
  List<String> selected,
  String family,
) {
  final all = [for (final f in book.families) f.id];
  final set = selected.isEmpty ? {...all} : {...selected};
  if (!set.remove(family)) set.add(family);
  if (set.isEmpty) return null;
  final ordered = [
    for (final id in all)
      if (set.contains(id)) id,
  ];
  return ordered.length == all.length ? const [] : ordered;
}

/// The "Surprise me" switch and the style families, each with small live
/// previews of its recipes. With the surprise on, families are toggled;
/// with it off, one recipe is chosen.
class StylePicker extends ConsumerWidget {
  const StylePicker({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final UserSettings settings;
  final void Function(UserSettings Function(UserSettings)) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final book = ref.watch(styleBookProvider).value;
    final library = ref.watch(contentLibraryProvider).value;
    final lang = Localizations.localeOf(context).languageCode;
    if (book == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final surprise = settings.styleSurprise;
    final chosen = book.byName(settings.styleName) ?? book.recipes.first;
    bool familyOn(String id) =>
        settings.styleFamilies.isEmpty || settings.styleFamilies.contains(id);

    void tapFamily(String id) {
      final next = toggleFamily(book, settings.styleFamilies, id);
      if (next == null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.styleKeepOne)));
        return;
      }
      onChanged((s) => s.copyWith(styleFamilies: next));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card.filled(
          margin: EdgeInsets.zero,
          child: SwitchListTile(
            secondary: const Icon(Icons.shuffle_rounded),
            title: Text(l10n.styleSurprise),
            subtitle: Text(l10n.styleSurpriseSubtitle),
            value: surprise,
            onChanged: (v) => onChanged(
              (s) => s.copyWith(
                styleSurprise: v,
                styleName: s.styleName ?? book.recipes.first.name,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(l10n.styleFamilies, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          surprise ? l10n.styleFamiliesHint : l10n.styleChooseHint,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        for (final family in book.families)
          _FamilyRow(
            family: family,
            recipes: book.ofFamily(family.id),
            language: lang,
            sample: previewSample(
              library: library,
              categoryId: previewCategory(family, settings),
              level: settings.englishLevel,
              l10n: l10n,
            ),
            surprise: surprise,
            familySelected: familyOn(family.id),
            chosen: surprise ? null : chosen.name,
            labelOf: (r) => recipeLabel(l10n, book, r),
            onFamilyTap: () => tapFamily(family.id),
            onRecipeTap: (r) => surprise
                ? tapFamily(family.id)
                : onChanged((s) => s.copyWith(styleName: r.name)),
          ),
      ],
    );
  }
}

class _FamilyRow extends StatelessWidget {
  const _FamilyRow({
    required this.family,
    required this.recipes,
    required this.language,
    required this.sample,
    required this.surprise,
    required this.familySelected,
    required this.chosen,
    required this.labelOf,
    required this.onFamilyTap,
    required this.onRecipeTap,
  });

  final StyleFamily family;
  final List<StyleRecipe> recipes;
  final String language;
  final WallpaperContent sample;
  final bool surprise;
  final bool familySelected;
  final String? chosen;
  final String Function(StyleRecipe) labelOf;
  final VoidCallback onFamilyTap;
  final ValueChanged<StyleRecipe> onRecipeTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dimmed = surprise && !familySelected;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (surprise)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: familySelected,
              title: Text(family.name(language)),
              onChanged: (_) => onFamilyTap(),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                family.name(language),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          SizedBox(
            height: 168,
            child: Opacity(
              opacity: dimmed ? 0.45 : 1,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recipes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final r = recipes[i];
                  final selected = r.name == chosen;
                  return Semantics(
                    button: true,
                    selected: surprise ? familySelected : selected,
                    label: labelOf(r),
                    child: GestureDetector(
                      onTap: () => onRecipeTap(r),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? scheme.primary
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 72,
                            height: 156,
                            child: StylePreview(recipe: r, content: sample),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small live render of [recipe] with [content].
class StylePreview extends StatefulWidget {
  const StylePreview({super.key, required this.recipe, required this.content});

  final StyleRecipe recipe;
  final WallpaperContent content;

  @override
  State<StylePreview> createState() => _StylePreviewState();
}

class _StylePreviewState extends State<StylePreview> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _render();
  }

  @override
  void didUpdateWidget(StylePreview old) {
    super.didUpdateWidget(old);
    if (old.recipe.name != widget.recipe.name ||
        old.content.title != widget.content.title ||
        old.content.language != widget.content.language) {
      _render();
    }
  }

  Future<void> _render() async {
    final r = await WallpaperRenderer.render(
      content: widget.content,
      recipe: widget.recipe,
      width: 216,
      height: 468,
    );
    if (!mounted) {
      r.dispose();
      return;
    }
    final old = _image;
    setState(() => _image = r.image);
    // Free the previous image only after the frame that replaced it.
    WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _image == null
      ? ColoredBox(color: widget.recipe.palette.ground)
      : RawImage(image: _image, fit: BoxFit.cover);
}
