import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/progress.dart';
import '../domain/user_settings.dart';

/// Persists settings and progress as JSON in shared_preferences.
///
/// Uses [SharedPreferencesAsync] (no in-memory cache) on purpose: the
/// background job runs in a separate Flutter engine, and a cached instance
/// in the UI would not see what the job wrote.
class AppStore {
  AppStore([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const _settingsKey = 'settings.v1';
  static const _progressKey = 'progress.v1';
  static const _displaySizeKey = 'displaySize.v1';
  static const _backgroundLogKey = 'backgroundLog.v1';
  static const _debugDayOffsetKey = 'debugDayOffset.v1';

  Future<UserSettings> loadSettings() async =>
      _decode(await _prefs.getString(_settingsKey), UserSettings.fromJson) ??
      const UserSettings();

  Future<void> saveSettings(UserSettings settings) =>
      _prefs.setString(_settingsKey, jsonEncode(settings.toJson()));

  Future<ProgressState> loadProgress() async =>
      _decode(await _prefs.getString(_progressKey), ProgressState.fromJson) ??
      const ProgressState();

  Future<void> saveProgress(ProgressState progress) =>
      _prefs.setString(_progressKey, jsonEncode(progress.toJson()));

  /// Last known physical screen size, for when the platform cannot be asked.
  Future<(int, int)?> loadDisplaySize() async {
    final list = await _prefs.getStringList(_displaySizeKey);
    if (list == null || list.length != 2) return null;
    final w = int.tryParse(list[0]), h = int.tryParse(list[1]);
    return w == null || h == null ? null : (w, h);
  }

  Future<void> saveDisplaySize(int width, int height) =>
      _prefs.setStringList(_displaySizeKey, ['$width', '$height']);

  /// Short log of background runs (newest first), shown in the debug panel.
  Future<List<String>> loadBackgroundLog() async =>
      await _prefs.getStringList(_backgroundLogKey) ?? const [];

  Future<void> appendBackgroundLog(String line) async {
    final log = [line, ...await loadBackgroundLog()];
    await _prefs.setStringList(_backgroundLogKey, log.take(20).toList());
  }

  /// Debug only: pretend today is N days later.
  Future<int> loadDebugDayOffset() async =>
      await _prefs.getInt(_debugDayOffsetKey) ?? 0;

  Future<void> saveDebugDayOffset(int days) =>
      _prefs.setInt(_debugDayOffsetKey, days);

  static T? _decode<T>(String? raw, T Function(Map<String, Object?>) fromJson) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      return json is Map<String, Object?> ? fromJson(json) : null;
    } on Object {
      // Corrupt data must never brick the app; start fresh instead.
      return null;
    }
  }
}
