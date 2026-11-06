import 'dart:typed_data';

import 'package:wallpaper_bridge/wallpaper_bridge.dart';

import '../domain/user_settings.dart';

/// What the app needs from the operating system. Android implements it
/// with WallpaperManager; an iOS version would live next to it (iOS has no
/// API to set the wallpaper, so it would save to Photos instead).
abstract interface class WallpaperPort {
  /// Physical portrait screen size in pixels, or null if unknown.
  Future<(int, int)?> displaySize();

  Future<bool> isSupported();

  Future<void> apply(
    Uint8List rgba,
    int width,
    int height,
    WallpaperTarget target,
  );
}

class AndroidWallpaperPort implements WallpaperPort {
  const AndroidWallpaperPort();

  @override
  Future<(int, int)?> displaySize() => WallpaperBridge.displaySize();

  @override
  Future<bool> isSupported() => WallpaperBridge.isSupported();

  @override
  Future<void> apply(
    Uint8List rgba,
    int width,
    int height,
    WallpaperTarget target,
  ) => WallpaperBridge.setWallpaper(
    rgba: rgba,
    width: width,
    height: height,
    target: target.name,
  );
}
