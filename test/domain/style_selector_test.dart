import 'package:dailywall/domain/style_selector.dart';
import 'package:dailywall/domain/user_settings.dart';
import 'package:flutter_test/flutter_test.dart';

const choices = [
  StyleChoice('dict_a', 'dictionary', ['english_words']),
  StyleChoice('dict_b', 'dictionary', ['english_words']),
  StyleChoice('term_a', 'terminal', ['software_tips', 'english_words']),
  StyleChoice('term_b', 'terminal', ['software_tips', 'english_words']),
  StyleChoice('riso_a', 'riso', ['motivation']),
  StyleChoice('riso_b', 'riso', ['motivation']),
];

String pick(
  int day,
  String category, {
  UserSettings settings = const UserSettings(),
  String? today,
  String? yesterday,
}) => StyleSelector.pick(
  day: day,
  categoryId: category,
  settings: settings,
  choices: choices,
  today: today,
  yesterday: yesterday,
)!;

void main() {
  test('surprise off: the chosen recipe, or the first if it is gone', () {
    const s = UserSettings(styleSurprise: false, styleName: 'riso_b');
    expect(pick(1, 'english_words', settings: s), 'riso_b');
    expect(
      pick(1, 'english_words', settings: s.copyWith(styleName: 'removed')),
      'dict_a',
    );
  });

  test('the same day and category always give the same recipe', () {
    for (var d = 0; d < 50; d++) {
      expect(pick(d, 'motivation'), pick(d, 'motivation'));
    }
  });

  test('prefers families that suit the category', () {
    for (var d = 0; d < 50; d++) {
      expect(pick(d, 'motivation'), startsWith('riso'));
      expect(pick(d, 'software_tips'), startsWith('term'));
    }
  });

  test('only the chosen families; any of them if none suits', () {
    const s = UserSettings(styleFamilies: ['dictionary']);
    for (var d = 0; d < 30; d++) {
      expect(pick(d, 'software_tips', settings: s), startsWith('dict'));
    }
  });

  test("never yesterday's recipe; today's is kept", () {
    for (var d = 0; d < 100; d++) {
      final y = pick(d - 1, 'english_words');
      expect(pick(d, 'english_words', yesterday: y), isNot(y));
    }
    expect(pick(5, 'english_words', today: 'term_b'), 'term_b');
    // A stored pick that is no longer allowed is replaced.
    expect(
      pick(
        5,
        'english_words',
        today: 'term_b',
        settings: const UserSettings(styleFamilies: ['dictionary']),
      ),
      startsWith('dict'),
    );
  });

  test('200 days: never the same twice in a row, every recipe used', () {
    String? yesterday;
    final seen = <String>{};
    for (var d = 0; d < 200; d++) {
      final cat = ['english_words', 'motivation', 'software_tips'][d % 3];
      final today = pick(d, cat, yesterday: yesterday);
      expect(today, isNot(yesterday));
      seen.add(today);
      yesterday = today;
    }
    expect(seen, hasLength(choices.length));
  });
}
