import 'package:dailywall/core/clock.dart';
import 'package:dailywall/core/seeded_random.dart';
import 'package:dailywall/data/content_models.dart';
import 'package:dailywall/domain/user_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('day index', () {
    test('is the local calendar day, independent of the time of day', () {
      expect(
        dayIndexOf(DateTime(2026, 11, 6, 0, 0)),
        dayIndexOf(DateTime(2026, 11, 6, 23, 59)),
      );
      expect(
        dayIndexOf(DateTime(2026, 11, 7)) - dayIndexOf(DateTime(2026, 11, 6)),
        1,
      );
      expect(dayIndexOf(DateTime(1970, 1, 1)), 0);
    });

    test('round-trips to the calendar date', () {
      final d = dateOfDayIndex(dayIndexOf(DateTime(2026, 3, 29, 12)));
      expect((d.year, d.month, d.day), (2026, 3, 29));
    });

    test('offset clock moves whole days', () {
      final base = FixedClock(DateTime(2026, 11, 6, 9));
      expect(
        dayIndexOf(OffsetClock(base, 3).now()) - dayIndexOf(base.now()),
        3,
      );
    });
  });

  group('seeded random', () {
    test('same seed, same sequence', () {
      final a = SeededRandom.of(['bg', 20000, 'motivation']);
      final b = SeededRandom.of(['bg', 20000, 'motivation']);
      expect(
        List.generate(20, (_) => a.nextUint32()),
        List.generate(20, (_) => b.nextUint32()),
      );
    });

    test('known values stay fixed across SDK updates', () {
      // If this fails, every user's wallpapers and orders would change.
      expect(SeededRandom.hashParts(['a']), 0xE40C292C);
      final r = SeededRandom(1);
      expect(
        [r.nextUint32(), r.nextUint32(), r.nextUint32()],
        [
          // Reference mulberry32(1) output.
          2693262067,
          11749833,
          2265367787,
        ],
      );
    });

    test('different seeds diverge', () {
      expect(
        SeededRandom.of(['x', 1]).nextUint32(),
        isNot(SeededRandom.of(['x', 2]).nextUint32()),
      );
    });

    test('doubles stay in range and shuffles keep every element', () {
      final r = SeededRandom(42);
      for (var i = 0; i < 1000; i++) {
        final v = r.nextDouble();
        expect(v >= 0 && v < 1, isTrue);
      }
      final items = List.generate(50, (i) => i);
      expect(r.shuffled(items)..sort(), items);
    });
  });

  test('settings survive a JSON round trip and drop unknown categories', () {
    const s = UserSettings(
      languageCode: 'tr',
      categoryIds: ['english_words', 'motivation'],
      englishLevel: CefrLevel.c1,
      target: WallpaperTarget.lock,
      styleSurprise: false,
      styleFamilies: ['terminal', 'riso'],
      styleName: 'riso_pink_blue',
      dailyChangeEnabled: false,
      onboardingComplete: true,
    );
    final json = s.toJson()
      ..['categoryIds'] = ['english_words', 'motivation', 'removed_category'];
    final r = UserSettings.fromJson(json);
    expect(r.toJson(), s.toJson());
  });
}
