import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/daily_wallpaper_service.dart';
import 'app/providers.dart';
import 'platform/background_tasks.dart';
import 'rendering/style/fonts.dart';
import 'ui/home/home_shell.dart';
import 'ui/onboarding/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicenses();
  await BackgroundTasks.initialize();
  runApp(const ProviderScope(child: DailyWallRoot()));
}

/// Picks the language and the first screen from the saved settings, and
/// applies today's wallpaper whenever the app comes to the foreground
/// (Android does not promise when the periodic job runs).
class DailyWallRoot extends ConsumerStatefulWidget {
  const DailyWallRoot({super.key});

  @override
  ConsumerState<DailyWallRoot> createState() => _DailyWallRootState();
}

class _DailyWallRootState extends ConsumerState<DailyWallRoot>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _onForeground(first: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onForeground();
  }

  Future<void> _onForeground({bool first = false}) async {
    final settings = await ref.read(settingsProvider.future);
    if (!settings.onboardingComplete) return;
    if (first && settings.dailyChangeEnabled) {
      // Idempotent (policy "update"); also repairs a schedule lost to a
      // force-stop or an app update.
      await ref.read(scheduleDailyProvider)(true);
    }
    final result = await ref
        .read(serviceProvider)
        .ensureToday(trigger: ApplyTrigger.appOpen);
    if (kDebugMode) debugPrint('dailywall app open: $result');
    if (result.outcome == ApplyOutcome.applied || !first) {
      ref
        ..invalidate(progressProvider)
        ..invalidate(todayProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final value = settings.value;
    return DailyWallApp(
      locale: value?.languageCode == null ? null : Locale(value!.languageCode!),
      home: switch (value) {
        null => const Scaffold(),
        final s when s.onboardingComplete => const HomeShell(),
        _ => const OnboardingScreen(),
      },
    );
  }
}

void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (family, file) in BundledFonts.licenses) {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString('assets/fonts/$file'));
    }
  });
}
