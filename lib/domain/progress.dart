/// The user's history with the content. Immutable; every change returns a
/// new [ProgressState], which keeps the selection logic a pure function.
class ProgressState {
  const ProgressState({
    this.history = const [],
    this.cycles = const {},
    this.known = const {},
    this.reviews = const {},
    this.favorites = const {},
    this.lastApplied,
  });

  /// One entry per day, oldest first, at most [historyLimit] entries.
  final List<HistoryEntry> history;

  /// Per category: which pass through the items we are in and what was
  /// already shown in it. Nothing repeats until a category is exhausted.
  final Map<String, CategoryCycle> cycles;

  /// Words marked "I know this": never shown again.
  final Set<String> known;

  /// Words marked "show again", by item id.
  final Map<String, ReviewState> reviews;
  final Set<String> favorites;

  /// What was last set as the wallpaper, so the daily job can exit early.
  final AppliedWallpaper? lastApplied;

  static const int historyLimit = 365;

  HistoryEntry? entryFor(int day) {
    for (var i = history.length - 1; i >= 0; i--) {
      if (history[i].day == day) return history[i];
      if (history[i].day < day) break;
    }
    return null;
  }

  ProgressState copyWith({
    List<HistoryEntry>? history,
    Map<String, CategoryCycle>? cycles,
    Set<String>? known,
    Map<String, ReviewState>? reviews,
    Set<String>? favorites,
    AppliedWallpaper? lastApplied,
  }) => ProgressState(
    history: history ?? this.history,
    cycles: cycles ?? this.cycles,
    known: known ?? this.known,
    reviews: reviews ?? this.reviews,
    favorites: favorites ?? this.favorites,
    lastApplied: lastApplied ?? this.lastApplied,
  );

  /// Records the style of [day] in its history entry, if there is one.
  ProgressState withStyle(int day, String? styleName) => copyWith(
    history: [
      for (final h in history) h.day == day ? h.withStyle(styleName) : h,
    ],
  );

  ProgressState toggleFavorite(String itemId) {
    final next = {...favorites};
    if (!next.remove(itemId)) next.add(itemId);
    return copyWith(favorites: next);
  }

  Map<String, Object?> toJson() => {
    'history': [for (final h in history) h.toJson()],
    'cycles': {for (final e in cycles.entries) e.key: e.value.toJson()},
    'known': known.toList()..sort(),
    'reviews': {for (final e in reviews.entries) e.key: e.value.toJson()},
    'favorites': favorites.toList()..sort(),
    'lastApplied': lastApplied?.toJson(),
  };

  factory ProgressState.fromJson(Map<String, Object?> json) {
    Map<String, Object?> obj(Object? v) =>
        v is Map<String, Object?> ? v : const {};
    List<Object?> list(Object? v) => v is List<Object?> ? v : const [];
    return ProgressState(
      history: [
        for (final h in list(json['history']))
          if (h is Map<String, Object?>) HistoryEntry.fromJson(h),
      ],
      cycles: {
        for (final e in obj(json['cycles']).entries)
          if (e.value is Map<String, Object?>)
            e.key: CategoryCycle.fromJson(e.value as Map<String, Object?>),
      },
      known: {
        for (final id in list(json['known']))
          if (id is String) id,
      },
      reviews: {
        for (final e in obj(json['reviews']).entries)
          if (e.value is Map<String, Object?>)
            e.key: ReviewState.fromJson(e.value as Map<String, Object?>),
      },
      favorites: {
        for (final id in list(json['favorites']))
          if (id is String) id,
      },
      lastApplied: json['lastApplied'] is Map<String, Object?>
          ? AppliedWallpaper.fromJson(
              json['lastApplied'] as Map<String, Object?>,
            )
          : null,
    );
  }
}

class HistoryEntry {
  const HistoryEntry({
    required this.day,
    required this.itemId,
    required this.categoryId,
    this.isReview = false,
    this.styleName,
  });

  final int day;
  final String itemId;
  final String categoryId;

  /// The style recipe of that day, so the day keeps its look and
  /// "Surprise me" never repeats yesterday's.
  final String? styleName;

  HistoryEntry withStyle(String? name) => HistoryEntry(
    day: day,
    itemId: itemId,
    categoryId: categoryId,
    isReview: isReview,
    styleName: name,
  );

  /// True when the item came back because of "show again".
  final bool isReview;

  Map<String, Object?> toJson() => {
    'day': day,
    'itemId': itemId,
    'categoryId': categoryId,
    if (isReview) 'isReview': true,
    if (styleName != null) 'styleName': styleName,
  };

  factory HistoryEntry.fromJson(Map<String, Object?> json) => HistoryEntry(
    day: json['day'] as int,
    itemId: json['itemId'] as String,
    categoryId: json['categoryId'] as String,
    isReview: json['isReview'] as bool? ?? false,
    styleName: json['styleName'] as String?,
  );
}

class CategoryCycle {
  const CategoryCycle({this.cycle = 0, this.seen = const {}});

  final int cycle;
  final Set<String> seen;

  Map<String, Object?> toJson() => {
    'cycle': cycle,
    'seen': seen.toList()..sort(),
  };

  factory CategoryCycle.fromJson(Map<String, Object?> json) => CategoryCycle(
    cycle: json['cycle'] as int? ?? 0,
    seen: {
      for (final id in (json['seen'] as List<Object?>? ?? const []))
        if (id is String) id,
    },
  );
}

class ReviewState {
  const ReviewState({required this.stage, required this.dueDay});

  /// Index into [SpacedRepetition.intervals] of the interval that led to
  /// [dueDay].
  final int stage;
  final int dueDay;

  Map<String, Object?> toJson() => {'stage': stage, 'dueDay': dueDay};

  factory ReviewState.fromJson(Map<String, Object?> json) =>
      ReviewState(stage: json['stage'] as int, dueDay: json['dueDay'] as int);

  @override
  bool operator ==(Object other) =>
      other is ReviewState && other.stage == stage && other.dueDay == dueDay;

  @override
  int get hashCode => Object.hash(stage, dueDay);

  @override
  String toString() => 'ReviewState(stage: $stage, dueDay: $dueDay)';
}

/// Identifies one applied wallpaper. If today's key equals the last applied
/// key, the daily job has nothing to do.
class AppliedWallpaper {
  const AppliedWallpaper({required this.day, required this.key});

  final int day;

  /// Item, style, target and language: changing any of them means the
  /// wallpaper must be rendered again.
  final String key;

  Map<String, Object?> toJson() => {'day': day, 'key': key};

  factory AppliedWallpaper.fromJson(Map<String, Object?> json) =>
      AppliedWallpaper(day: json['day'] as int, key: json['key'] as String);
}
