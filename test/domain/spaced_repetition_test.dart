import 'package:dayleaf/domain/progress.dart';
import 'package:dayleaf/domain/spaced_repetition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const today = 100;
  const empty = ProgressState();

  test('show again schedules the first review 2 days later', () {
    final s = SpacedRepetition.markRepeat(empty, 'en_0001', today);
    expect(s.reviews['en_0001'], const ReviewState(stage: 0, dueDay: 102));
  });

  test('each review moves on to the next interval, then finishes', () {
    var review = const ReviewState(stage: 0, dueDay: 102);
    review = SpacedRepetition.afterShown(review, 102)!;
    expect(review, const ReviewState(stage: 1, dueDay: 107));
    review = SpacedRepetition.afterShown(review, 107)!;
    expect(review, const ReviewState(stage: 2, dueDay: 117));
    expect(SpacedRepetition.afterShown(review, 117), isNull);
  });

  test('a late review is scheduled from the day it was actually shown', () {
    final next = SpacedRepetition.afterShown(
      const ReviewState(stage: 0, dueDay: 102),
      104,
    );
    expect(next, const ReviewState(stage: 1, dueDay: 109));
  });

  test('show again on a scheduled word restarts at 2 days', () {
    var s = SpacedRepetition.markRepeat(empty, 'w', today);
    s = s.copyWith(reviews: {'w': const ReviewState(stage: 2, dueDay: 130)});
    s = SpacedRepetition.markRepeat(s, 'w', 120);
    expect(s.reviews['w'], const ReviewState(stage: 0, dueDay: 122));
  });

  test('I know this removes a scheduled review and the reverse', () {
    var s = SpacedRepetition.markRepeat(empty, 'w', today);
    s = SpacedRepetition.markKnown(s, 'w');
    expect(s.known, {'w'});
    expect(s.reviews, isEmpty);
    s = SpacedRepetition.markRepeat(s, 'w', today);
    expect(s.known, isEmpty);
    expect(s.reviews.keys, ['w']);
    s = SpacedRepetition.clear(s, 'w');
    expect(s.known, isEmpty);
    expect(s.reviews, isEmpty);
  });

  test('due reviews are ordered by due day, then id', () {
    final s = empty.copyWith(
      reviews: {
        'b': const ReviewState(stage: 0, dueDay: 99),
        'a': const ReviewState(stage: 0, dueDay: 99),
        'c': const ReviewState(stage: 0, dueDay: 97),
        'future': const ReviewState(stage: 0, dueDay: 101),
      },
    );
    expect(SpacedRepetition.dueOn(s, today), ['c', 'a', 'b']);
  });

  test('marks do not mutate the original state', () {
    final s = SpacedRepetition.markKnown(empty, 'w');
    expect(empty.known, isEmpty);
    expect(s.known, {'w'});
  });
}
