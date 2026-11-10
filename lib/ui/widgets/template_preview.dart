import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/daily_wallpaper_service.dart' show categoryLabel;
import '../../app/providers.dart';
import '../../data/content_models.dart';
import '../../domain/user_settings.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../rendering/background.dart';
import '../../rendering/templates.dart';
import '../../rendering/wallpaper_content.dart';
import '../../rendering/wallpaper_renderer.dart';
import '../labels.dart';

/// What the style previews show: a real item from the user's first
/// interest (at their English level for words), so the badge and the text
/// always match. Until the content has loaded, a motivation line with the
/// motivation badge.
WallpaperContent previewSample({
  required ContentLibrary? library,
  required UserSettings settings,
  required String language,
  required AppLocalizations l10n,
}) {
  final categoryId = settings.categoryIds.firstOrNull;
  final items = categoryId == null || library == null
      ? const <ContentItem>[]
      : library.itemsOf(categoryId);
  if (categoryId != null && items.isNotEmpty) {
    final item = items.firstWhere(
      (i) => i is! WordItem || i.level == settings.englishLevel,
      orElse: () => items.first,
    );
    return WallpaperContent.fromItem(
      item,
      language: language,
      categoryLabel: categoryLabel(l10n, categoryId),
    );
  }
  return WallpaperContent(
    language: language,
    badge: categoryLabel(l10n, 'motivation'),
    title: language == 'tr' ? 'Küçük adımlar birikir.' : 'Small steps add up.',
    body: language == 'tr'
        ? 'Günde on dakika, bir yılda 60 saatten fazla eder.'
        : 'Ten minutes a day is more than 60 hours a year.',
  );
}

/// Three small live renders, one per template, to choose from.
class TemplatePicker extends ConsumerWidget {
  const TemplatePicker({
    super.key,
    required this.selected,
    required this.settings,
    required this.onSelected,
  });

  final String selected;
  final UserSettings settings;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final lang = Localizations.localeOf(context).languageCode;
    final sample = previewSample(
      library: ref.watch(contentLibraryProvider).value,
      settings: settings,
      language: lang,
      l10n: l10n,
    );
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final t in WallpaperTemplates.all)
          Semantics(
            button: true,
            selected: t.id == selected,
            label: l10n.template(t.id),
            child: GestureDetector(
              onTap: () => onSelected(t.id),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: t.id == selected
                            ? scheme.primary
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 96,
                        height: 200,
                        child: _LiveRender(template: t, content: sample),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ExcludeSemantics(child: Text(l10n.template(t.id))),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _LiveRender extends StatefulWidget {
  const _LiveRender({required this.template, required this.content});

  final WallpaperTemplate template;
  final WallpaperContent content;

  @override
  State<_LiveRender> createState() => _LiveRenderState();
}

class _LiveRenderState extends State<_LiveRender> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _render();
  }

  @override
  void didUpdateWidget(_LiveRender old) {
    super.didUpdateWidget(old);
    if (old.content.title != widget.content.title ||
        old.content.badge != widget.content.badge) {
      _render();
    }
  }

  Future<void> _render() async {
    final r = await WallpaperRenderer.render(
      content: widget.content,
      template: widget.template,
      background: BackgroundSpec.forDay(
        20400 + WallpaperTemplates.all.indexOf(widget.template),
        'preview',
      ),
      width: 288,
      height: 600,
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
      ? ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest)
      : RawImage(image: _image, fit: BoxFit.cover);
}
