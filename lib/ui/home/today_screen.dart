import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/daily_wallpaper_service.dart';
import '../../app/providers.dart';
import '../../core/app_config.dart';
import '../../data/content_models.dart';
import '../../domain/content_selector.dart';
import '../../l10n/gen/app_localizations.dart';
import '../labels.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  bool _applying = false;
  bool _sharing = false;

  Future<void> _apply() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _applying = true);
    final result = await ref
        .read(serviceProvider)
        .ensureToday(trigger: ApplyTrigger.user, force: true);
    ref.invalidate(progressProvider);
    if (!mounted) return;
    setState(() => _applying = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.outcome == ApplyOutcome.applied
              ? l10n.applied
              : l10n.applyFailed,
        ),
      ),
    );
  }

  Future<void> _share(DailyPick pick) async {
    setState(() => _sharing = true);
    try {
      final settings = await ref.read(settingsProvider.future);
      final png = await ref.read(serviceProvider).sharePng(pick, settings);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              png,
              mimeType: 'image/png',
              name: '${AppConfig.appName}.png',
            ),
          ],
          fileNameOverrides: ['${AppConfig.appName}.png'],
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final today = ref.watch(todayProvider);
    final progress = ref.watch(progressProvider).value;
    final preview = ref.watch(previewProvider);
    final size = ref.watch(displaySizeProvider).value ?? (1080, 2400);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeTitle)),
      body: today.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (pick) {
          if (pick == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.noContent, textAlign: TextAlign.center),
              ),
            );
          }
          final isFavorite =
              progress?.favorites.contains(pick.item.id) ?? false;
          final isWord = pick.item is WordItem;
          final known = progress?.known.contains(pick.item.id) ?? false;
          final repeat = progress?.reviews.containsKey(pick.item.id) ?? false;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Center(
                child: ConstrainedBox(
                  // Leaves room for the buttons, even with large text.
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.58,
                  ),
                  child: AspectRatio(
                    aspectRatio: size.$1 / size.$2,
                    child: Semantics(
                      image: true,
                      label: l10n.previewLabel,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: switch (preview) {
                          AsyncValue(value: final bytes?) => Image.memory(
                            bytes,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                          _ => ColoredBox(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  Chip(
                    avatar: Icon(categoryIcon(pick.categoryId), size: 18),
                    label: Text(l10n.category(pick.categoryId)),
                  ),
                  if (pick.isReview)
                    Chip(
                      avatar: const Icon(Icons.replay_rounded, size: 18),
                      label: Text(l10n.reviewBadge),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _applying ? null : _apply,
                icon: _applying
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wallpaper_rounded),
                label: Text(l10n.applyNow),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => ref
                          .read(progressProvider.notifier)
                          .toggleFavorite(pick.item.id),
                      icon: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                      ),
                      label: Text(
                        isFavorite ? l10n.unfavorite : l10n.favorite,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _sharing ? null : () => _share(pick),
                      icon: const Icon(Icons.share_rounded),
                      label: Text(l10n.share, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
              if (isWord) ...[
                const SizedBox(height: 8),
                _WordButtons(
                  itemId: pick.item.id,
                  known: known,
                  repeat: repeat,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _WordButtons extends ConsumerWidget {
  const _WordButtons({
    required this.itemId,
    required this.known,
    required this.repeat,
  });

  final String itemId;
  final bool known;
  final bool repeat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(progressProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    void say(String text) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));

    return SegmentedButton<String>(
      emptySelectionAllowed: true,
      segments: [
        ButtonSegment(
          value: 'known',
          icon: const Icon(Icons.check_rounded),
          label: Text(l10n.iKnowThis),
        ),
        ButtonSegment(
          value: 'repeat',
          icon: const Icon(Icons.replay_rounded),
          label: Text(l10n.showAgain),
        ),
      ],
      selected: {if (known) 'known', if (repeat) 'repeat'},
      onSelectionChanged: (selection) async {
        if (selection.contains('known') && !known) {
          await notifier.markKnown(itemId);
          say(l10n.knownMarked);
        } else if (selection.contains('repeat') && !repeat) {
          await notifier.markRepeat(itemId);
          say(l10n.repeatMarked);
        } else {
          await notifier.clearMark(itemId);
        }
      },
    );
  }
}
