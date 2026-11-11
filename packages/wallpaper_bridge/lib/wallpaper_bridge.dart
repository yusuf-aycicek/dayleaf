import 'package:flutter/services.dart';

/// Thin Dart side of the Android plugin. The app talks to it through
/// `lib/platform/wallpaper_port.dart`, never directly.
abstract final class WallpaperBridge {
  static const MethodChannel channel = MethodChannel(
    'com.yusufaycicek.dayleaf/wallpaper',
  );

  /// Physical portrait size of the default display, in pixels.
  static Future<(int, int)?> displaySize() async {
    final map = await channel.invokeMapMethod<String, int>('displaySize');
    final w = map?['width'], h = map?['height'];
    return w == null || h == null ? null : (w, h);
  }

  /// False on devices or profiles where apps may not change the wallpaper.
  static Future<bool> isSupported() async =>
      await channel.invokeMethod<bool>('isSupported') ?? false;

  /// [target] is `lock`, `home` or `both`. [rgba] must hold width*height*4
  /// bytes in R, G, B, A order.
  static Future<void> setWallpaper({
    required Uint8List rgba,
    required int width,
    required int height,
    required String target,
  }) => channel.invokeMethod<bool>('setWallpaper', {
    'rgba': rgba,
    'width': width,
    'height': height,
    'target': target,
  });
}
