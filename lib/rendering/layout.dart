import 'package:flutter/painting.dart';

/// Where text may go on a wallpaper.
///
/// The lock screen clock (large on Android 12+) sits in the top part, and
/// on the home screen the app icons start at about 65% of the height (Pixel
/// launcher, 1080x2400, measured on the emulator). Text is kept in a band
/// above the icons, with side margins.
abstract final class WallpaperSafeArea {
  static const double top = 0.30;
  static const double bottom = 0.62;
  static const double side = 0.08;

  static Rect textBox(Size size) => Rect.fromLTRB(
    size.width * side,
    size.height * top,
    size.width * (1 - side),
    size.height * bottom,
  );
}

/// Minimum WCAG contrast for every text on a wallpaper (normal-text AA).
const double minTextContrast = 4.5;
