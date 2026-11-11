import 'package:dayleaf/data/app_store.dart';
import 'package:dayleaf/domain/progress.dart';
import 'package:dayleaf/domain/spaced_repetition.dart';
import 'package:dayleaf/domain/user_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('defaults when nothing is stored', () async {
    final store = AppStore();
    expect((await store.loadSettings()).onboardingComplete, isFalse);
    expect((await store.loadProgress()).history, isEmpty);
    expect(await store.loadDisplaySize(), isNull);
  });

  test('settings and progress round-trip', () async {
    final store = AppStore();
    await store.saveSettings(
      const UserSettings(categoryIds: ['motivation'], onboardingComplete: true),
    );
    var progress = SpacedRepetition.markRepeat(
      const ProgressState(),
      'en_0001',
      10,
    ).toggleFavorite('mo_0002');
    progress = progress.copyWith(
      lastApplied: const AppliedWallpaper(day: 10, key: 'k'),
    );
    await store.saveProgress(progress);

    // A second instance sees the data: no stale cache between engines.
    final other = AppStore();
    expect((await other.loadSettings()).categoryIds, ['motivation']);
    final loaded = await other.loadProgress();
    expect(loaded.favorites, {'mo_0002'});
    expect(loaded.reviews['en_0001'], const ReviewState(stage: 0, dueDay: 12));
    expect(loaded.lastApplied?.key, 'k');
  });

  test('corrupt data falls back to defaults', () async {
    await SharedPreferencesAsync().setString('progress.v1', '{not json');
    expect((await AppStore().loadProgress()).history, isEmpty);
  });

  test('background log keeps the newest 20 lines', () async {
    final store = AppStore();
    for (var i = 0; i < 25; i++) {
      await store.appendBackgroundLog('run $i');
    }
    final log = await store.loadBackgroundLog();
    expect(log, hasLength(20));
    expect(log.first, 'run 24');
  });

  test('display size round-trips', () async {
    final store = AppStore();
    await store.saveDisplaySize(1080, 2400);
    expect(await store.loadDisplaySize(), (1080, 2400));
  });
}
