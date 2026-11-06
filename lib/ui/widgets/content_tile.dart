import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/clock.dart';
import '../../data/content_models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../labels.dart';

/// One item in the history or favorites list. Tapping shows everything.
class ContentTile extends StatelessWidget {
  const ContentTile({
    super.key,
    required this.item,
    required this.isFavorite,
    required this.onToggleFavorite,
    this.day,
  });

  final ContentItem item;
  final int? day;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final (title, subtitle) = switch (item) {
      WordItem(:final word, :final meaning) => (word, meaning.resolve(lang)),
      TextItem(:final text) => (text.resolve(lang), null),
    };
    final date = day == null
        ? null
        : DateFormat.yMMMMd(lang).format(dateOfDayIndex(day!));
    final overline = [?date, l10n.category(item.categoryId)].join(' · ');
    return ListTile(
      leading: Icon(categoryIcon(item.categoryId)),
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle == null ? overline : '$subtitle\n$overline'),
      isThreeLine: subtitle != null,
      trailing: IconButton(
        tooltip: isFavorite ? l10n.unfavorite : l10n.favorite,
        onPressed: onToggleFavorite,
        icon: Icon(
          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        ),
      ),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => ContentDetail(item: item, language: lang),
      ),
    );
  }
}

class ContentDetail extends StatelessWidget {
  const ContentDetail({super.key, required this.item, required this.language});

  final ContentItem item;
  final String language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final muted = theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: switch (item) {
            WordItem(
              :final word,
              :final level,
              :final meaning,
              :final example,
            ) =>
              [
                Text(
                  '${level.code} · ${l10n.category(item.categoryId)}',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  word,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  meaning.resolve(language),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  example.values['en'] ?? '',
                  style: theme.textTheme.bodyLarge,
                ),
                if (language != 'en' && example.has(language)) ...[
                  const SizedBox(height: 4),
                  Text(example.values[language]!, style: muted),
                ],
              ],
            TextItem(:final text, :final detail) => [
              Text(
                l10n.category(item.categoryId),
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Text(
                text.resolve(language),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(detail.resolve(language), style: muted),
            ],
          },
        ),
      ),
    );
  }
}
