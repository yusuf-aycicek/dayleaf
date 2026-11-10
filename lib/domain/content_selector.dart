import '../core/seeded_random.dart';
import '../data/content_models.dart';
import 'progress.dart';
import 'spaced_repetition.dart';
import 'user_settings.dart';

class DailyPick {
  const DailyPick({
    required this.day,
    required this.item,
    this.isReview = false,
    this.styleName,
  });

  final int day;
  final ContentItem item;
  final bool isReview;

  /// The style recipe chosen for the day (set by the service).
  final String? styleName;

  DailyPick withStyle(String? name) =>
      DailyPick(day: day, item: item, isReview: isReview, styleName: name);

  String get categoryId => item.categoryId;
}

/// Chooses the content of a day.
///
/// The choice is a pure function of (day, settings, progress, content):
/// * Same day, same content: once a day has an entry in the history it is
///   returned unchanged.
/// * Categories take turns: day `d` starts with `selected[d % n]`.
/// * Within a category the items are walked in a seeded shuffled order;
///   nothing repeats until every eligible item was shown (one "cycle"),
///   then a new order is drawn.
/// * On an English-words day a due "show again" word wins over a new word.
class ContentSelector {
  const ContentSelector(this.library, {this.premiumUnlocked = true});

  final ContentLibrary library;

  /// Everything is free for now. When billing arrives, locked premium items
  /// are simply not eligible.
  final bool premiumUnlocked;

  /// Today's pick and the progress that records it. Returns `(null, state)`
  /// when no category is selected or every selected category is empty.
  (DailyPick?, ProgressState) pickForDay(
    int day,
    UserSettings settings,
    ProgressState state,
  ) {
    final existing = state.entryFor(day);
    if (existing != null) {
      final item = library.findById(existing.itemId);
      if (item != null && settings.categoryIds.contains(existing.categoryId)) {
        return (
          DailyPick(day: day, item: item, isReview: existing.isReview),
          state,
        );
      }
      // The category was deselected (or the item removed): choose again.
      state = state.copyWith(
        history: [...state.history]..removeWhere((h) => h.day == day),
      );
    }

    final categories = [
      for (final c in ContentCatalog.categories)
        if (settings.categoryIds.contains(c.id) && _allowed(c)) c,
    ];
    if (categories.isEmpty) return (null, state);

    final start = day % categories.length;
    for (var offset = 0; offset < categories.length; offset++) {
      final category = categories[(start + offset) % categories.length];
      final result = _pickFrom(category, day, settings, state);
      if (result != null) return result;
    }
    return (null, state);
  }

  (DailyPick, ProgressState)? _pickFrom(
    ContentCategory category,
    int day,
    UserSettings settings,
    ProgressState state,
  ) {
    if (category.kind == ContentKind.word) {
      for (final id in SpacedRepetition.dueOn(state, day)) {
        final item = library.findById(id);
        if (item == null ||
            item.categoryId != category.id ||
            !_allowedItem(item)) {
          continue;
        }
        final next = SpacedRepetition.afterShown(state.reviews[id]!, day);
        final reviews = {...state.reviews};
        next == null ? reviews.remove(id) : reviews[id] = next;
        return (
          DailyPick(day: day, item: item, isReview: true),
          state.copyWith(
            history: _append(
              state.history,
              HistoryEntry(
                day: day,
                itemId: id,
                categoryId: category.id,
                isReview: true,
              ),
            ),
            reviews: reviews,
          ),
        );
      }
    }

    final pool = [
      for (final item in library.itemsOf(category.id))
        if (_eligibleNew(item, settings, state)) item.id,
    ]..sort();
    if (pool.isEmpty) return null;

    var cycle = state.cycles[category.id] ?? const CategoryCycle();
    var candidates = _order(
      category.id,
      cycle.cycle,
      pool,
    ).where((id) => !cycle.seen.contains(id)).toList();
    if (candidates.isEmpty) {
      // Category exhausted: start the next pass with a fresh order, but
      // never repeat yesterday's item on the first day of the new pass.
      cycle = CategoryCycle(cycle: cycle.cycle + 1);
      candidates = _order(category.id, cycle.cycle, pool);
      final last = _lastShownIn(state.history, category.id);
      if (candidates.length > 1 && candidates.first == last) {
        candidates = [...candidates.skip(1), candidates.first];
      }
    }

    final id = candidates.first;
    final item = library.findById(id)!;
    return (
      DailyPick(day: day, item: item),
      state.copyWith(
        history: _append(
          state.history,
          HistoryEntry(day: day, itemId: id, categoryId: category.id),
        ),
        cycles: {
          ...state.cycles,
          category.id: CategoryCycle(
            cycle: cycle.cycle,
            seen: {...cycle.seen, id},
          ),
        },
      ),
    );
  }

  bool _allowed(ContentCategory c) => premiumUnlocked || !c.isPremium;

  bool _allowedItem(ContentItem item) => premiumUnlocked || !item.isPremium;

  bool _eligibleNew(
    ContentItem item,
    UserSettings settings,
    ProgressState state,
  ) {
    if (!_allowedItem(item)) return false;
    if (item is WordItem) {
      if (item.level != settings.englishLevel) return false;
      if (state.known.contains(item.id)) return false;
      // Scheduled words come back through the review path, not as new.
      if (state.reviews.containsKey(item.id)) return false;
    }
    return true;
  }

  static List<String> _order(
    String categoryId,
    int cycle,
    List<String> sortedPool,
  ) => SeededRandom.of(['order', categoryId, cycle]).shuffled(sortedPool);

  static String? _lastShownIn(List<HistoryEntry> history, String categoryId) {
    for (var i = history.length - 1; i >= 0; i--) {
      if (history[i].categoryId == categoryId) return history[i].itemId;
    }
    return null;
  }

  static List<HistoryEntry> _append(
    List<HistoryEntry> history,
    HistoryEntry entry,
  ) {
    final next = [...history, entry]..sort((a, b) => a.day.compareTo(b.day));
    return next.length > ProgressState.historyLimit
        ? next.sublist(next.length - ProgressState.historyLimit)
        : next;
  }
}
