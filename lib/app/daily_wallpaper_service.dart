import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../core/app_config.dart';
import '../core/clock.dart';
import '../data/app_store.dart';
import '../data/content_repository.dart';
import '../domain/content_selector.dart';
import '../domain/progress.dart';
import '../domain/user_settings.dart';
import '../l10n/gen/app_localizations.dart';
import '../platform/wallpaper_port.dart';
import '../rendering/background.dart';
import '../rendering/templates.dart';
import '../rendering/wallpaper_content.dart';
import '../rendering/wallpaper_renderer.dart';

enum ApplyTrigger { appOpen, background, user, settingsChanged }

enum ApplyOutcome {
  applied,

  /// Today's wallpaper with these settings is already set: nothing to do.
  alreadyApplied,
  notConfigured,
  dailyChangeOff,
  noContent,
  failed,
}

class ApplyResult {
  const ApplyResult(this.outcome, {this.pick, this.error});

  final ApplyOutcome outcome;
  final DailyPick? pick;
  final Object? error;

  @override
  String toString() =>
      'ApplyResult(${outcome.name}${pick == null ? '' : ', ${pick!.item.id}'}${error == null ? '' : ', $error'})';
}

/// Orchestrates one day: choose content, render it, set it as wallpaper.
/// Used by the UI and by the background job, so both behave the same.
class DailyWallpaperService {
  DailyWallpaperService({
    required this.store,
    required this.content,
    required this.port,
    this.clock = const SystemClock(),
    this.systemLanguage,
  });

  final AppStore store;
  final ContentRepository content;
  final WallpaperPort port;
  final Clock clock;

  /// Overrides the platform locale (tests).
  final String? systemLanguage;

  static const _fallbackSize = (1080, 2400);
  Future<void>? _running;

  /// Today, honoring the debug "pretend it is N days later" offset.
  Future<int> today() async {
    final offset = kDebugMode ? await store.loadDebugDayOffset() : 0;
    return dayIndexOf(clock.now()) + offset;
  }

  String languageFor(UserSettings settings) {
    final code =
        settings.languageCode ??
        systemLanguage ??
        ui.PlatformDispatcher.instance.locale.languageCode;
    final supported = AppLocalizations.supportedLocales.map(
      (l) => l.languageCode,
    );
    return supported.contains(code) ? code : 'en';
  }

  /// Makes sure today's wallpaper is set. Cheap when it already is: the
  /// check uses only stored settings and progress, without loading content
  /// or rendering, so the periodic job exits in milliseconds.
  Future<ApplyResult> ensureToday({
    required ApplyTrigger trigger,
    bool force = false,
  }) async {
    // Serialize calls in this engine (e.g. app open + settings change).
    while (_running != null) {
      await _running;
    }
    final done = Completer<void>();
    _running = done.future;
    try {
      final result = await _ensureToday(trigger, force);
      if (trigger == ApplyTrigger.background) {
        await store.appendBackgroundLog(
          '${DateTime.now().toIso8601String().substring(0, 19)} ${result.outcome.name}'
          '${result.pick == null ? '' : ' ${result.pick!.item.id}'}',
        );
      }
      return result;
    } finally {
      _running = null;
      done.complete();
    }
  }

  Future<ApplyResult> _ensureToday(ApplyTrigger trigger, bool force) async {
    final settings = await store.loadSettings();
    if (!settings.onboardingComplete) {
      return const ApplyResult(ApplyOutcome.notConfigured);
    }
    if (trigger == ApplyTrigger.background && !settings.dailyChangeEnabled) {
      return const ApplyResult(ApplyOutcome.dailyChangeOff);
    }
    final day = await today();
    var progress = await store.loadProgress();
    final language = languageFor(settings);

    // Fast path: nothing changed since the last apply today.
    final entry = progress.entryFor(day);
    if (!force &&
        entry != null &&
        settings.categoryIds.contains(entry.categoryId) &&
        progress.lastApplied?.day == day &&
        progress.lastApplied?.key ==
            applyKey(entry.itemId, settings, language)) {
      return const ApplyResult(ApplyOutcome.alreadyApplied);
    }

    try {
      final library = await content.load();
      final (pick, picked) = ContentSelector(library)
          .pickForDay(day, settings, progress);
      progress = picked;
      if (pick == null) {
        await store.saveProgress(progress);
        return const ApplyResult(ApplyOutcome.noContent);
      }
      final key = applyKey(pick.item.id, settings, language);
      if (!force &&
          progress.lastApplied?.day == day &&
          progress.lastApplied?.key == key) {
        await store.saveProgress(progress);
        return ApplyResult(ApplyOutcome.alreadyApplied, pick: pick);
      }

      final (width, height) = await _displaySize();
      final rendered = await render(
        pick,
        settings,
        width: width,
        height: height,
      );
      try {
        final rgba = await WallpaperRenderer.encodeRgba(rendered.image);
        await port.apply(rgba, width, height, settings.target);
      } finally {
        rendered.dispose();
      }
      await store.saveProgress(
        progress.copyWith(
          lastApplied: AppliedWallpaper(day: day, key: key),
        ),
      );
      return ApplyResult(ApplyOutcome.applied, pick: pick);
    } catch (e, st) {
      debugPrint('dailywall: applying the wallpaper failed: $e\n$st');
      // Keep the pick so the same content is retried, not a new one.
      await store.saveProgress(progress);
      return ApplyResult(ApplyOutcome.failed, error: e);
    }
  }

  /// Today's content without applying it (home screen preview).
  Future<DailyPick?> todaysPick() async {
    final settings = await store.loadSettings();
    final library = await content.load();
    final (pick, progress) = ContentSelector(library)
        .pickForDay(await today(), settings, await store.loadProgress());
    await store.saveProgress(progress);
    return pick;
  }

  Future<RenderedWallpaper> render(
    DailyPick pick,
    UserSettings settings, {
    required int width,
    required int height,
  }) {
    final language = languageFor(settings);
    final l10n = lookupAppLocalizations(ui.Locale(language));
    final wallpaperContent = WallpaperContent.fromItem(
      pick.item,
      language: language,
      categoryLabel: categoryLabel(l10n, pick.categoryId),
    );
    return WallpaperRenderer.render(
      content: wallpaperContent,
      template: WallpaperTemplates.byId(settings.templateId),
      background: BackgroundSpec.forDay(pick.day, pick.categoryId),
      width: width,
      height: height,
    );
  }

  /// PNG of [pick] with the watermark, for sharing.
  Future<Uint8List> sharePng(DailyPick pick, UserSettings settings) async {
    final (w, h) = await _displaySize();
    final rendered = await render(pick, settings, width: w, height: h);
    try {
      final marked = await WallpaperRenderer.withWatermark(
        rendered.image,
        AppConfig.appName,
      );
      try {
        return await WallpaperRenderer.encodePng(marked);
      } finally {
        marked.dispose();
      }
    } finally {
      rendered.dispose();
    }
  }

  Future<(int, int)> _displaySize() async {
    try {
      final size = await port.displaySize();
      if (size != null) {
        await store.saveDisplaySize(size.$1, size.$2);
        return size;
      }
    } catch (e) {
      debugPrint('dailywall: display size unavailable: $e');
    }
    return await store.loadDisplaySize() ?? _fallbackSize;
  }

  /// Everything that changes the picture. Bump the trailing version when
  /// the rendering changes so existing users get the new look.
  static String applyKey(String itemId, UserSettings s, String language) =>
      '$itemId|${s.templateId}|${s.target.name}|$language|r1';
}

String categoryLabel(AppLocalizations l10n, String categoryId) =>
    switch (categoryId) {
      'english_words' => l10n.categoryEnglishWords,
      'software_tips' => l10n.categorySoftwareTips,
      'motivation' => l10n.categoryMotivation,
      'general_knowledge' => l10n.categoryGeneralKnowledge,
      _ => categoryId,
    };

/// Interface languages, which are also the content languages.
List<String> get appLanguages =>
    AppLocalizations.supportedLocales.map((l) => l.languageCode).toList();

/// Builds the service with the real platform pieces.
DailyWallpaperService createDailyWallpaperService({
  Clock clock = const SystemClock(),
}) => DailyWallpaperService(
  store: AppStore(),
  content: ContentRepository(languages: appLanguages, throwOnErrors: false),
  port: const AndroidWallpaperPort(),
  clock: clock,
);
