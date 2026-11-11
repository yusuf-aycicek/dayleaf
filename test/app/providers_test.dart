import 'package:dayleaf/app/daily_wallpaper_service.dart';
import 'package:dayleaf/app/providers.dart';
import 'package:dayleaf/core/clock.dart';
import 'package:dayleaf/data/app_store.dart';
import 'package:dayleaf/data/content_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Regression: finishing onboarding while the Today screen listens to
  // todayProvider threw a Riverpod CircularDependencyError on the device.
  test(
    'finishing onboarding updates today without a circular dependency',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      var scheduled = 0;
      final container = ProviderContainer(
        overrides: [
          serviceProvider.overrideWithValue(
            DailyWallpaperService(
              store: AppStore(),
              content: ContentRepository(
                bundle: rootBundle,
                languages: const ['en', 'tr'],
              ),
              port: FakePort(),
              clock: FixedClock(DateTime(2026, 11, 9, 9)),
              systemLanguage: 'en',
            ),
          ),
          scheduleDailyProvider.overrideWithValue((_) async => scheduled++),
        ],
      );
      addTearDown(container.dispose);
      container.listen(todayProvider, (_, _) {});
      expect(await container.read(todayProvider.future), isNull);

      final settings = container.read(settingsProvider.notifier);
      await settings.change((s) => s.copyWith(categoryIds: ['software_tips']));
      await settings.change((s) => s.copyWith(onboardingComplete: true));

      final pick = await container.read(todayProvider.future);
      expect(pick, isNotNull);
      expect(pick!.categoryId, 'software_tips');
      expect(scheduled, 1);
    },
  );
}
