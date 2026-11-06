import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/gen/app_localizations.dart';
import '../widgets/content_tile.dart';
import '../widgets/empty_state.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final progress = ref.watch(progressProvider).value;
    final library = ref.watch(contentLibraryProvider).value;
    final entries = [
      if (progress != null && library != null)
        for (final h in progress.history.reversed)
          if (library.findById(h.itemId) case final item?) (h, item),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.historyTitle)),
      body: entries.isEmpty
          ? EmptyState(icon: Icons.history_rounded, text: l10n.historyEmpty)
          : ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) {
                final (entry, item) = entries[i];
                return ContentTile(
                  item: item,
                  day: entry.day,
                  isFavorite: progress!.favorites.contains(item.id),
                  onToggleFavorite: () => ref
                      .read(progressProvider.notifier)
                      .toggleFavorite(item.id),
                );
              },
            ),
    );
  }
}
