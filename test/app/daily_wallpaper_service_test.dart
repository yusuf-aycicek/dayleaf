import 'package:dailywall/app/daily_wallpaper_service.dart';
import 'package:dailywall/core/clock.dart';
import 'package:dailywall/data/app_store.dart';
import 'package:dailywall/data/content_repository.dart';
import 'package:dailywall/domain/user_settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakePort port;
  late FixedClock clock;
  late AppStore store;

  DailyWallpaperService service() => DailyWallpaperService(
    store: store,
    content: ContentRepository(
      bundle: rootBundle,
      languages: const ['en', 'tr'],
    ),
    port: port,
    clock: clock,
    systemLanguage: 'tr',
  );

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    port = FakePort();
    clock = FixedClock(DateTime(2026, 11, 6, 9));
    store = AppStore();
    await store.saveSettings(
      const UserSettings(
        categoryIds: ['motivation', 'software_tips'],
        onboardingComplete: true,
        target: WallpaperTarget.lock,
      ),
    );
  });

  // Called inside tester.runAsync: rendering needs real (not fake) async.
  Future<ApplyResult> run(
    DailyWallpaperService s, [
    ApplyTrigger t = ApplyTrigger.background,
  ]) => s.ensureToday(trigger: t);

  testWidgets('applies once per day, then exits early', (tester) async {
    await tester.runAsync(() async {
      final s = service();
      expect((await run(s)).outcome, ApplyOutcome.applied);
      expect(port.applied.single, (
        360,
        800,
        WallpaperTarget.lock,
        360 * 800 * 4,
      ));

      expect((await run(s)).outcome, ApplyOutcome.alreadyApplied);
      expect(
        (await run(service(), ApplyTrigger.appOpen)).outcome,
        ApplyOutcome.alreadyApplied,
      );
      expect(port.applied, hasLength(1));

      clock.value = DateTime(2026, 11, 7, 0, 30);
      expect((await run(s)).outcome, ApplyOutcome.applied);
      expect(port.applied, hasLength(2));
      expect(await store.loadBackgroundLog(), hasLength(3));
    });
  });

  testWidgets('a settings change re-renders the same content', (tester) async {
    await tester.runAsync(() async {
      final s = service();
      final first = await run(s);
      final settings = await store.loadSettings();
      await store.saveSettings(
        settings.copyWith(styleSurprise: false, styleName: 'terminal_amber'),
      );
      final second = await run(s, ApplyTrigger.settingsChanged);
      expect(second.outcome, ApplyOutcome.applied);
      expect(second.pick!.item.id, first.pick!.item.id);
      expect(second.pick!.styleName, 'terminal_amber');
    });
  });

  testWidgets('a day keeps its style; the next day gets another one', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final s = service();
      final first = await run(s);
      expect(first.pick!.styleName, isNotNull);
      final again = await s.ensureToday(
        trigger: ApplyTrigger.user,
        force: true,
      );
      expect(again.pick!.styleName, first.pick!.styleName);
      final progress = await store.loadProgress();
      expect(
        progress.entryFor(first.pick!.day)!.styleName,
        first.pick!.styleName,
      );
      clock.value = clock.value.add(const Duration(days: 1));
      final next = await run(s);
      expect(next.outcome, ApplyOutcome.applied);
      expect(next.pick!.styleName, isNot(first.pick!.styleName));
    });
  });

  testWidgets('background run respects the daily change switch', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final settings = await store.loadSettings();
      await store.saveSettings(settings.copyWith(dailyChangeEnabled: false));
      expect((await run(service())).outcome, ApplyOutcome.dailyChangeOff);
      expect(
        (await run(service(), ApplyTrigger.user)).outcome,
        ApplyOutcome.applied,
      );
    });
  });

  testWidgets('nothing happens before onboarding', (tester) async {
    await tester.runAsync(() async {
      await store.saveSettings(const UserSettings(categoryIds: ['motivation']));
      expect((await run(service())).outcome, ApplyOutcome.notConfigured);
      expect(port.applied, isEmpty);
    });
  });

  testWidgets('a platform failure keeps the pick for the retry', (
    tester,
  ) async {
    await tester.runAsync(() async {
      port.fail = true;
      final failed = await run(service());
      expect(failed.outcome, ApplyOutcome.failed);
      port.fail = false;
      final retried = await run(service());
      expect(retried.outcome, ApplyOutcome.applied);
      final progress = await store.loadProgress();
      expect(progress.history, hasLength(1));
      expect(progress.history.single.itemId, retried.pick!.item.id);
    });
  });

  testWidgets('share image is a PNG at screen size', (tester) async {
    await tester.runAsync(() async {
      final s = service();
      final pick = await s.todaysPick();
      final png = await s.sharePng(pick!, await store.loadSettings());
      expect(png.sublist(1, 4), 'PNG'.codeUnits);
    });
  });

  test('unsupported system language falls back to English', () {
    final s = DailyWallpaperService(
      store: AppStore(),
      content: ContentRepository(languages: const ['en', 'tr']),
      port: FakePort(),
      systemLanguage: 'de',
    );
    expect(s.languageFor(const UserSettings()), 'en');
    expect(s.languageFor(const UserSettings(languageCode: 'tr')), 'tr');
  });
}
