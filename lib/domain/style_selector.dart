import '../core/seeded_random.dart';
import 'user_settings.dart';

/// What the selector needs to know about a style recipe.
class StyleChoice {
  const StyleChoice(this.name, this.family, this.fits);

  final String name;
  final String family;

  /// Categories the recipe's family suits.
  final List<String> fits;
}

/// Chooses the style recipe of a day.
abstract final class StyleSelector {
  /// With "Surprise me" off: the user's recipe (or the first one if it no
  /// longer exists). With it on: a recipe from the chosen families
  /// (every family if none is chosen), preferring those that suit the
  /// day's category. [today] is kept if it is still allowed, so the day
  /// keeps its look; otherwise the pick is seeded by the day and the
  /// category, and is never [yesterday]'s recipe when there is another.
  static String? pick({
    required int day,
    required String categoryId,
    required UserSettings settings,
    required List<StyleChoice> choices,
    String? today,
    String? yesterday,
  }) {
    if (choices.isEmpty) return null;
    if (!settings.styleSurprise) {
      return choices.any((c) => c.name == settings.styleName)
          ? settings.styleName
          : choices.first.name;
    }
    var pool = [
      for (final c in choices)
        if (settings.styleFamilies.contains(c.family)) c,
    ];
    if (pool.isEmpty) pool = choices;
    final fitting = [
      for (final c in pool)
        if (c.fits.contains(categoryId)) c,
    ];
    if (fitting.isNotEmpty) pool = fitting;
    if (today != null &&
        today != yesterday &&
        pool.any((c) => c.name == today)) {
      return today;
    }
    if (pool.length > 1) {
      pool = [
        for (final c in pool)
          if (c.name != yesterday) c,
      ];
    }
    return SeededRandom.of(['style', day, categoryId]).pick(pool).name;
  }
}
