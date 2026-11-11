import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../app/daily_wallpaper_service.dart';

/// The daily job, scheduled with WorkManager.
///
/// Android does not run periodic work at an exact time, so the job runs
/// every [period] and does real work at most once a day: if today's
/// wallpaper is already set it returns after reading two preferences.
/// Opening the app also applies today's wallpaper if the job has not yet.
abstract final class BackgroundTasks {
  static const uniqueName = 'dayleaf.daily';
  static const taskName = 'applyDailyWallpaper';
  static const debugTaskName = 'applyDailyWallpaperNow';

  /// Short enough that the new wallpaper appears soon after midnight, long
  /// enough to be negligible for the battery (each early exit takes ms).
  static const period = Duration(hours: 6);

  static Future<void> initialize() =>
      Workmanager().initialize(callbackDispatcher);

  static Future<void> schedule() => Workmanager().registerPeriodicTask(
    uniqueName,
    taskName,
    frequency: period,
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    constraints: Constraints(
      networkType: NetworkType.notRequired,
      requiresBatteryNotLow: true,
    ),
  );

  static Future<void> cancel() => Workmanager().cancelByUniqueName(uniqueName);

  /// Debug: run the job once (the same code path as the daily run), now
  /// or after [delay]. A delay leaves time to close the app, so the job
  /// runs in a fresh process; WorkManager will not run the periodic job
  /// early, even when it is forced with `adb shell cmd jobscheduler run`.
  static Future<void> runOnceNow({Duration delay = Duration.zero}) =>
      Workmanager().registerOneOffTask(
        'dayleaf.debug.${DateTime.now().millisecondsSinceEpoch}',
        debugTaskName,
        existingWorkPolicy: ExistingWorkPolicy.append,
        initialDelay: delay,
      );
}

/// Entry point of the background engine. Must be a top-level function
/// kept by the compiler (`vm:entry-point`).
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    final result = await createDailyWallpaperService().ensureToday(
      trigger: ApplyTrigger.background,
    );
    // Shows up in `adb logcat -s flutter`.
    debugPrint('dayleaf background task "$task": $result');
    // A failure is retried by WorkManager with backoff; a skip is a success.
    return result.outcome != ApplyOutcome.failed;
  });
}
