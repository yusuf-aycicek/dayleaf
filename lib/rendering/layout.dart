import 'package:flutter/painting.dart';

import 'color_math.dart';

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

const Color lightInk = Color(0xFFFFFFFF);
const Color darkInk = Color(0xFF111318);

/// The text color and, if needed, a translucent scrim behind the text.
class ColorPlan {
  const ColorPlan({required this.text, this.scrim, this.scrimAlpha = 0});

  final Color text;

  /// Drawn behind the text block when the background alone is not enough.
  final Color? scrim;
  final double scrimAlpha;

  /// The colors the text actually sits on, after the scrim.
  List<Color> effective(List<Color> under) => scrim == null
      ? under
      : [for (final c in under) blend(scrim!, c, scrimAlpha)];

  /// Picks light or dark ink, whichever reads better; adds the lightest
  /// scrim that brings the contrast to [minTextContrast].
  factory ColorPlan.forBackground(List<Color> under) {
    final light = minContrast(lightInk, under);
    final dark = minContrast(darkInk, under);
    final text = light >= dark ? lightInk : darkInk;
    if ((light >= dark ? light : dark) >= minTextContrast) {
      return ColorPlan(text: text);
    }
    final scrim = text == lightInk
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
    for (var alpha = 0.1; alpha <= 1.0001; alpha += 0.05) {
      final blended = [for (final c in under) blend(scrim, c, alpha)];
      if (minContrast(text, blended) >= minTextContrast) {
        return ColorPlan(text: text, scrim: scrim, scrimAlpha: alpha);
      }
    }
    return ColorPlan(text: text, scrim: scrim, scrimAlpha: 1);
  }
}
