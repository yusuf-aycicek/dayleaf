import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/content_models.dart';
import '../domain/content_selector.dart';
import '../domain/progress.dart';
import '../domain/spaced_repetition.dart';
import '../domain/user_settings.dart';
import '../platform/background_tasks.dart';
import '../rendering/wallpaper_renderer.dart';
import 'daily_wallpaper_service.dart';

/// Overridden in tests with fakes.
final serviceProvider = Provider<DailyWallpaperService>(
  (ref) => createDailyWallpaperService(),
);

/// Turns the background job on or off. Overridden in widget tests.
final scheduleDailyProvider = Provider<Future<void> Function(bool enabled)>(
  (ref) =>
      (enabled) =>
          enabled ? BackgroundTasks.schedule() : BackgroundTasks.cancel(),
);

final contentLibraryProvider = FutureProvider<ContentLibrary>(
  (ref) => ref.watch(serviceProvider).content.load(),
);

class SettingsNotifier extends AsyncNotifier<UserSettings> {
  @override
  Future<UserSettings> build() =>
      ref.watch(serviceProvider).store.loadSettings();

  /// Saves [change] and, once onboarding is done, keeps the job schedule
  /// and today's wallpaper in sync with it.
  Future<void> change(UserSettings Function(UserSettings) change) async {
    final current = state.value ?? await future;
    final next = change(current);
    state = AsyncData(next);
    final service = ref.read(serviceProvider);
    await service.store.saveSettings(next);
    if (!next.onboardingComplete) return;
    if (next.dailyChangeEnabled != current.dailyChangeEnabled ||
        !current.onboardingComplete) {
      await ref.read(scheduleDailyProvider)(next.dailyChangeEnabled);
    }
    ref.invalidate(todayProvider);
    if (current.onboardingComplete) {
      unawaited(
        service
            .ensureToday(trigger: ApplyTrigger.settingsChanged)
            .then((_) => ref.invalidate(progressProvider)),
      );
    }
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, UserSettings>(
  SettingsNotifier.new,
);

class ProgressNotifier extends AsyncNotifier<ProgressState> {
  @override
  Future<ProgressState> build() =>
      ref.watch(serviceProvider).store.loadProgress();

  Future<void> _save(ProgressState Function(ProgressState) change) async {
    // Re-read: the background job may have written in the meantime.
    final store = ref.read(serviceProvider).store;
    final next = change(await store.loadProgress());
    await store.saveProgress(next);
    state = AsyncData(next);
  }

  Future<void> toggleFavorite(String itemId) =>
      _save((p) => p.toggleFavorite(itemId));

  Future<void> markKnown(String itemId) =>
      _save((p) => SpacedRepetition.markKnown(p, itemId));

  Future<void> markRepeat(String itemId) async {
    final today = await ref.read(serviceProvider).today();
    await _save((p) => SpacedRepetition.markRepeat(p, itemId, today));
  }

  Future<void> clearMark(String itemId) =>
      _save((p) => SpacedRepetition.clear(p, itemId));
}

final progressProvider = AsyncNotifierProvider<ProgressNotifier, ProgressState>(
  ProgressNotifier.new,
);

/// Today's pick (selecting it records it in the history).
final todayProvider = FutureProvider<DailyPick?>((ref) async {
  final settings = await ref.watch(settingsProvider.future);
  if (!settings.onboardingComplete) return null;
  final pick = await ref.read(serviceProvider).todaysPick();
  ref.invalidate(progressProvider);
  return pick;
});

/// PNG preview of today's wallpaper, rendered at half the screen
/// resolution (the layout is proportional, so it looks the same). Bytes
/// rather than a ui.Image: the widget can keep showing the previous
/// preview while a new one renders without touching a disposed image.
final previewProvider = FutureProvider.autoDispose<Uint8List?>((ref) async {
  final pick = await ref.watch(todayProvider.future);
  final settings = await ref.watch(settingsProvider.future);
  if (pick == null) return null;
  final service = ref.read(serviceProvider);
  final (w, h) = await ref.watch(displaySizeProvider.future);
  final rendered = await service.render(
    pick,
    settings,
    width: w ~/ 2,
    height: h ~/ 2,
  );
  try {
    return await WallpaperRenderer.encodePng(rendered.image);
  } finally {
    rendered.dispose();
  }
});

final displaySizeProvider = FutureProvider<(int, int)>((ref) async {
  final service = ref.read(serviceProvider);
  try {
    final size = await service.port.displaySize();
    if (size != null) return size;
  } catch (e) {
    debugPrint('dailywall: $e');
  }
  return await service.store.loadDisplaySize() ?? (1080, 2400);
});
