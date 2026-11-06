import 'package:dailywall/app/app.dart';
import 'package:dailywall/app/daily_wallpaper_service.dart';
import 'package:dailywall/app/providers.dart';
import 'package:dailywall/core/app_config.dart';
import 'package:dailywall/core/clock.dart';
import 'package:dailywall/data/app_store.dart';
import 'package:dailywall/data/content_repository.dart';
import 'package:dailywall/domain/user_settings.dart';
import 'package:dailywall/ui/onboarding/onboarding_screen.dart';
import 'package:dailywall/ui/settings/about_screen.dart';
import 'package:dailywall/ui/settings/settings_screen.dart';
import 'package:dailywall/ui/widgets/ya_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../helpers/fakes.dart';

void main() {
  late AppStore store;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    store = AppStore();
    PackageInfo.setMockInitialValues(
      appName: 'dailywall',
      packageName: 'com.example',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  /// A phone-sized screen (360x690 dp) with the given system text scale.
  void phone(WidgetTester tester, {double textScale = 1}) {
    tester.view.physicalSize = const Size(1080, 2070);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Future<void> show(WidgetTester tester, Widget home) async {
    final service = DailyWallpaperService(
      store: store,
      content: ContentRepository(
        bundle: rootBundle,
        languages: const ['en', 'tr'],
      ),
      port: FakePort(),
      clock: FixedClock(DateTime(2026, 11, 6, 9)),
      systemLanguage: 'en',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serviceProvider.overrideWithValue(service),
          scheduleDailyProvider.overrideWithValue((_) async {}),
        ],
        child: DailyWallApp(locale: const Locale('en'), home: home),
      ),
    );
    await settle(tester);
  }

  testWidgets('logo and name sit on the first onboarding page only', (
    tester,
  ) async {
    phone(tester);
    await show(tester, const OnboardingScreen());
    expect(find.byType(YaLogo), findsOneWidget);
    expect(find.text(AppConfig.developerName), findsOneWidget);

    await tester.tap(find.text('Next'));
    await settle(tester);
    expect(find.byType(YaLogo), findsNothing);
    expect(find.text(AppConfig.developerName), findsNothing);
  });

  testWidgets('settings has no logo, About has it with version and links', (
    tester,
  ) async {
    phone(tester);
    await store.saveSettings(const UserSettings(onboardingComplete: true));
    await show(tester, const SettingsScreen());
    expect(find.byType(YaLogo), findsNothing);

    await show(tester, const AboutScreen());
    expect(find.byType(YaLogo), findsOneWidget);
    expect(find.text(AppConfig.developerName), findsOneWidget);
    expect(find.textContaining('1.0.0'), findsOneWidget);
    expect(find.text('github.com/${AppConfig.githubUser}'), findsOneWidget);
  });

  // Overflow ("RenderFlex overflowed") is reported as a test failure, so
  // these only need to visit the screens at a large system font size.
  for (final scale in [1.0, 2.0]) {
    testWidgets('onboarding steps lay out at text scale $scale', (
      tester,
    ) async {
      phone(tester, textScale: scale);
      await show(tester, const OnboardingScreen());
      // language → interests (pick English) → level → target. The template step renders real images and is covered by
      // the rendering tests.
      Future<void> next() async {
        await tester.tap(find.byType(FilledButton));
        await settle(tester);
      }

      await next();
      // At 2x the list is longer than the screen.
      await tester.scrollUntilVisible(find.text('English word'), 100);
      await tester.ensureVisible(find.text('English word'));
      await settle(tester);
      await tester.tap(find.text('English word'));
      await settle(tester);
      expect(find.text('Next'), findsOneWidget);
      await settle(tester);
      await next();
      await next();
      await tester.scrollUntilVisible(find.text('Lock screen'), 100);
      expect(find.text('Lock screen'), findsOneWidget);
    });

    testWidgets('settings and About lay out at text scale $scale', (
      tester,
    ) async {
      phone(tester, textScale: scale);
      await store.saveSettings(const UserSettings(onboardingComplete: true));
      await show(tester, const SettingsScreen());
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await settle(tester);
      await show(tester, const AboutScreen());
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await settle(tester);
    });
  }
}

/// pumpAndSettle never settles while the logo cursor blinks, so pump a
/// fixed amount of time instead; async storage gets real time to finish.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 100));
  }
}
