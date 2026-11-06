import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/progress.dart';
import '../../l10n/gen/app_localizations.dart';
import '../widgets/content_tile.dart';
import '../widgets/empty_state.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final progress = ref.watch(progressProvider).value;
    final library = ref.watch(contentLibraryProvider).value;
    // Newest first: the order in which they appeared in the history.
    final lastSeen = {
      for (final h in progress?.history ?? const <HistoryEntry>[])
        h.itemId: h.day,
    };
    final favorites = [
      if (progress != null && library != null)
        for (final id in progress.favorites) ?library.findById(id),
    ]..sort((a, b) => (lastSeen[b.id] ?? 0).compareTo(lastSeen[a.id] ?? 0));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.favoritesTitle)),
      body: favorites.isEmpty
          ? EmptyState(
              icon: Icons.favorite_border_rounded,
              text: l10n.favoritesEmpty,
            )
          : ListView.separated(
              itemCount: favorites.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) => ContentTile(
                item: favorites[i],
                day: lastSeen[favorites[i].id],
                isFavorite: true,
                onToggleFavorite: () => ref
                    .read(progressProvider.notifier)
                    .toggleFavorite(favorites[i].id),
              ),
            ),
    );
  }
}
