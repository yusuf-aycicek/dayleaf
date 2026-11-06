import 'package:dailywall/domain/user_settings.dart';
import 'package:dailywall/platform/wallpaper_port.dart';
import 'package:flutter/services.dart';

class FakePort implements WallpaperPort {
  final applied = <(int, int, WallpaperTarget, int)>[];
  bool fail = false;

  @override
  Future<(int, int)?> displaySize() async => (360, 800);

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<void> apply(
    Uint8List rgba,
    int width,
    int height,
    WallpaperTarget target,
  ) async {
    if (fail) throw PlatformException(code: 'SET_FAILED');
    applied.add((width, height, target, rgba.length));
  }
}
