import 'progress.dart';

/// "I know this" / "Show again" for English words.
///
/// "Show again" brings a word back after 2 days; each time it comes back it
/// is scheduled again after 5, then 10 days, and then it is done (it can
/// still appear again in a later full pass of the category). "I know this"
/// removes the word for good.
abstract final class SpacedRepetition {
  static const List<int> intervals = [2, 5, 10];

  static ProgressState markRepeat(
    ProgressState state,
    String itemId,
    int today,
  ) => state.copyWith(
    known: {...state.known}..remove(itemId),
    reviews: {
      ...state.reviews,
      itemId: ReviewState(stage: 0, dueDay: today + intervals.first),
    },
  );

  static ProgressState markKnown(ProgressState state, String itemId) =>
      state.copyWith(
        known: {...state.known, itemId},
        reviews: {...state.reviews}..remove(itemId),
      );

  /// Undo both marks.
  static ProgressState clear(ProgressState state, String itemId) =>
      state.copyWith(
        known: {...state.known}..remove(itemId),
        reviews: {...state.reviews}..remove(itemId),
      );

  /// The schedule after a review was shown on [shownDay]; null when done.
  static ReviewState? afterShown(ReviewState review, int shownDay) {
    final next = review.stage + 1;
    if (next >= intervals.length) return null;
    return ReviewState(stage: next, dueDay: shownDay + intervals[next]);
  }

  /// Reviews due on or before [today], most overdue first (ties by id, so
  /// the order is deterministic).
  static List<String> dueOn(ProgressState state, int today) {
    final due =
        [
          for (final e in state.reviews.entries)
            if (e.value.dueDay <= today && !state.known.contains(e.key)) e,
        ]..sort((a, b) {
          final byDay = a.value.dueDay.compareTo(b.value.dueDay);
          return byDay != 0 ? byDay : a.key.compareTo(b.key);
        });
    return [for (final e in due) e.key];
  }
}
