import 'package:dayleaf/data/content_models.dart';
import 'package:dayleaf/domain/content_selector.dart';
import 'package:dayleaf/domain/progress.dart';
import 'package:dayleaf/domain/spaced_repetition.dart';
import 'package:dayleaf/domain/user_settings.dart';
import 'package:flutter_test/flutter_test.dart';

const lt = LocalizedText({'en': 'x', 'tr': 'x'});

TextItem textItem(String category, String prefix, int n) => TextItem(
  id: '${prefix}_${n.toString().padLeft(4, '0')}',
  categoryId: category,
  text: lt,
  detail: lt,
);

WordItem wordItem(int n, CefrLevel level) => WordItem(
  id: 'en_${n.toString().padLeft(4, '0')}',
  categoryId: 'english_words',
  word: 'word$n',
  level: level,
  meaning: lt,
  example: lt,
);

final library = ContentLibrary({
  'english_words': [
    for (var i = 1; i <= 5; i++) wordItem(i, CefrLevel.b1),
    for (var i = 6; i <= 8; i++) wordItem(i, CefrLevel.a1),
  ],
  'motivation': [for (var i = 1; i <= 6; i++) textItem('motivation', 'mo', i)],
  'software_tips': [
    for (var i = 1; i <= 4; i++) textItem('software_tips', 'sw', i),
  ],
  'general_knowledge': const [],
});

const day0 = 20000;
final selector = ContentSelector(library);

/// Runs [days] consecutive days and returns the picks and final state.
(List<DailyPick>, ProgressState) run(
  UserSettings settings, {
  int days = 1,
  int start = day0,
  ProgressState state = const ProgressState(),
  ContentSelector? sel,
}) {
  sel ??= selector;
  final picks = <DailyPick>[];
  for (var d = start; d < start + days; d++) {
    final (pick, next) = sel.pickForDay(d, settings, state);
    if (pick != null) picks.add(pick);
    state = next;
  }
  return (picks, state);
}

void main() {
  const motivationOnly = UserSettings(categoryIds: ['motivation']);

  test('same day returns the same content and does not change state', () {
    final (first, state) = selector.pickForDay(
      day0,
      motivationOnly,
      const ProgressState(),
    );
    final (again, state2) = selector.pickForDay(day0, motivationOnly, state);
    expect(again!.item.id, first!.item.id);
    expect(identical(state, state2), isTrue);
  });

  test('is deterministic: two fresh runs give the same sequence', () {
    final (a, _) = run(motivationOnly, days: 20);
    final (b, _) = run(motivationOnly, days: 20);
    expect(a.map((p) => p.item.id), b.map((p) => p.item.id));
  });

  test('a category never repeats before every item was shown', () {
    final (picks, _) = run(motivationOnly, days: 6 * 4);
    final ids = picks.map((p) => p.item.id).toList();
    for (var cycle = 0; cycle < 4; cycle++) {
      final pass = ids.sublist(cycle * 6, cycle * 6 + 6);
      expect(pass.toSet(), hasLength(6), reason: 'pass $cycle: $pass');
    }
  });

  test(
    'consecutive passes use different orders and never repeat at the seam',
    () {
      final (picks, _) = run(motivationOnly, days: 6 * 5);
      final ids = picks.map((p) => p.item.id).toList();
      final orders = {
        for (var c = 0; c < 5; c++) ids.sublist(c * 6, c * 6 + 6).join(','),
      };
      expect(orders.length, greaterThan(1));
      for (var i = 1; i < ids.length; i++) {
        expect(ids[i], isNot(ids[i - 1]), reason: 'day $i');
      }
    },
  );

  test('several categories take turns in catalog order', () {
    const settings = UserSettings(categoryIds: ['software_tips', 'motivation']);
    final (picks, _) = run(settings, days: 6, start: 0);
    // Catalog order is english, software, motivation, general.
    expect(picks.map((p) => p.categoryId), [
      'software_tips',
      'motivation',
      'software_tips',
      'motivation',
      'software_tips',
      'motivation',
    ]);
  });

  test('an empty category is skipped and the next one fills the day', () {
    const settings = UserSettings(
      categoryIds: ['general_knowledge', 'motivation'],
    );
    final (picks, _) = run(settings, days: 4);
    expect(picks, hasLength(4));
    expect(picks.every((p) => p.categoryId == 'motivation'), isTrue);
  });

  test('no category selected gives no pick', () {
    final (pick, _) = selector.pickForDay(
      day0,
      const UserSettings(),
      const ProgressState(),
    );
    expect(pick, isNull);
  });

  test('only words of the selected level are shown', () {
    const b1 = UserSettings(
      categoryIds: ['english_words'],
      englishLevel: CefrLevel.b1,
    );
    const a1 = UserSettings(
      categoryIds: ['english_words'],
      englishLevel: CefrLevel.a1,
    );
    final (b1Picks, _) = run(b1, days: 10);
    final (a1Picks, _) = run(a1, days: 10);
    expect(b1Picks.map((p) => (p.item as WordItem).level).toSet(), {
      CefrLevel.b1,
    });
    expect(a1Picks.map((p) => (p.item as WordItem).level).toSet(), {
      CefrLevel.a1,
    });
  });

  test('known words never come back', () {
    const settings = UserSettings(categoryIds: ['english_words']);
    var (picks, state) = run(settings);
    final known = picks.single.item.id;
    state = SpacedRepetition.markKnown(state, known);
    final (later, _) = run(settings, start: day0 + 1, days: 30, state: state);
    expect(later.map((p) => p.item.id), isNot(contains(known)));
    expect(later, hasLength(30));
  });

  test('"show again" brings a word back after 2, then 5, then 10 days', () {
    const settings = UserSettings(categoryIds: ['english_words']);
    var (picks, state) = run(settings);
    final word = picks.single.item.id;
    state = SpacedRepetition.markRepeat(state, word, day0);

    final (later, _) = run(settings, start: day0 + 1, days: 40, state: state);
    final reviews = [
      for (final p in later)
        if (p.isReview) p,
    ];
    expect(reviews.map((p) => p.item.id).toSet(), {word});
    expect(reviews.map((p) => p.day - day0), [2, 2 + 5, 2 + 5 + 10]);
    // While scheduled, the word is not also shown as a "new" word.
    final asNewWhileScheduled = later.where(
      (p) => p.item.id == word && !p.isReview && p.day < day0 + 17,
    );
    expect(asNewWhileScheduled, isEmpty);
  });

  test('reviews only replace new words on English days', () {
    const settings = UserSettings(categoryIds: ['english_words', 'motivation']);
    // Day 20000 is even: index 0 = english_words.
    var (picks, state) = run(settings);
    final word = picks.single.item.id;
    state = SpacedRepetition.markRepeat(state, word, day0);
    // Due on day0+2 (English day). day0+1 is a motivation day.
    final (later, _) = run(settings, start: day0 + 1, days: 2, state: state);
    expect(later[0].categoryId, 'motivation');
    expect(later[1].item.id, word);
  });

  test('deselecting today\'s category picks again from the others', () {
    final (picks, state) = run(motivationOnly);
    expect(picks.single.categoryId, 'motivation');
    const now = UserSettings(categoryIds: ['software_tips']);
    final (pick, next) = selector.pickForDay(day0, now, state);
    expect(pick!.categoryId, 'software_tips');
    expect(next.history.where((h) => h.day == day0), hasLength(1));
  });

  test('locked premium items are not eligible', () {
    final premiumLibrary = ContentLibrary({
      'motivation': [
        const TextItem(
          id: 'mo_0001',
          categoryId: 'motivation',
          text: lt,
          detail: lt,
          isPremium: true,
        ),
        textItem('motivation', 'mo', 2),
      ],
    });
    final locked = ContentSelector(premiumLibrary, premiumUnlocked: false);
    final (picks, _) = run(motivationOnly, days: 5, sel: locked);
    expect(picks.map((p) => p.item.id).toSet(), {'mo_0002'});
  });

  test('history is capped', () {
    final (_, state) = run(
      motivationOnly,
      days: ProgressState.historyLimit + 20,
    );
    expect(state.history, hasLength(ProgressState.historyLimit));
    expect(state.history.last.day, day0 + ProgressState.historyLimit + 19);
  });

  test('progress survives a JSON round trip mid-cycle', () {
    final (_, state) = run(motivationOnly, days: 3);
    final restored = ProgressState.fromJson(state.toJson());
    final (a, _) = run(motivationOnly, start: day0 + 3, days: 9, state: state);
    final (b, _) = run(
      motivationOnly,
      start: day0 + 3,
      days: 9,
      state: restored,
    );
    expect(b.map((p) => p.item.id), a.map((p) => p.item.id));
  });
}
