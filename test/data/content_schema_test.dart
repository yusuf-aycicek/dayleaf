import 'package:dailywall/data/content_models.dart';
import 'package:dailywall/data/content_schema.dart';
import 'package:flutter_test/flutter_test.dart';

const langs = ['en', 'tr'];

Map<String, Object?> wordFile(List<Object?> items) => {
  'category': 'english_words',
  'kind': 'word',
  'items': items,
};

Map<String, Object?> textFile(List<Object?> items) => {
  'category': 'motivation',
  'kind': 'text',
  'items': items,
};

Map<String, Object?> word(
  String id, {
  String word = 'resilient',
  String level = 'B1',
}) => {
  'id': id,
  'level': level,
  'word': word,
  'meaning': {'tr': 'dayanıklı', 'en': 'able to recover quickly'},
  'example': {'en': 'She is resilient.', 'tr': 'O dayanıklıdır.'},
};

Map<String, Object?> text(String id, {String en = 'Small steps add up.'}) => {
  'id': id,
  'text': {'en': en, 'tr': 'Küçük adımlar birikir.'},
  'detail': {'en': 'Ten minutes a day.', 'tr': 'Günde on dakika.'},
};

List<String> messages(CategoryValidation r) =>
    r.issues.map((i) => i.message).toList();

void main() {
  test('valid word and text items pass', () {
    final w = validateCategory(
      ContentCatalog.englishWords,
      wordFile([word('en_0001')]),
      languages: langs,
    );
    final t = validateCategory(
      ContentCatalog.motivation,
      textFile([text('mo_0001')]),
      languages: langs,
    );
    expect(w.issues, isEmpty);
    expect(t.issues, isEmpty);
    final item = w.items.single as WordItem;
    expect(item.level, CefrLevel.b1);
    expect(item.meaning.resolve('tr'), 'dayanıklı');
  });

  test('missing translation is an error and the item is rejected', () {
    final bad = word('en_0001')
      ..['meaning'] = {'en': 'able to recover quickly'};
    final r = validateCategory(
      ContentCatalog.englishWords,
      wordFile([bad, word('en_0002', word: 'brave')]),
      languages: langs,
    );
    expect(messages(r), contains('missing translation "meaning.tr"'));
    expect(r.items.map((i) => i.id), ['en_0002']);
    expect(r.rejectedIds, {'en_0001'});
  });

  test('blank translation counts as missing', () {
    final bad = text('mo_0001')..['detail'] = {'en': 'x', 'tr': '   '};
    final r = validateCategory(
      ContentCatalog.motivation,
      textFile([bad]),
      languages: langs,
    );
    expect(messages(r), contains('missing translation "detail.tr"'));
  });

  test('a new interface language makes every item report it', () {
    final r = validateCategory(
      ContentCatalog.motivation,
      textFile([text('mo_0001')]),
      languages: [...langs, 'de'],
    );
    expect(
      messages(r),
      containsAll([
        'missing translation "text.de"',
        'missing translation "detail.de"',
      ]),
    );
  });

  test('duplicate ids and duplicate content are errors', () {
    final r = validateCategory(
      ContentCatalog.motivation,
      textFile([
        text('mo_0001'),
        text('mo_0001', en: 'Other text.'),
        text('mo_0003', en: 'small steps, add up!'),
      ]),
      languages: langs,
    );
    expect(messages(r), contains('duplicate id'));
    expect(messages(r), contains('same content as mo_0001'));
    expect(r.items.map((i) => i.id), ['mo_0001']);
  });

  test('id must use the category prefix', () {
    final r = validateCategory(
      ContentCatalog.motivation,
      textFile([text('sw_0001')]),
      languages: langs,
    );
    expect(messages(r).single, contains('mo_0001'));
  });

  test('too long text is an error', () {
    final r = validateCategory(
      ContentCatalog.motivation,
      textFile([text('mo_0001', en: 'a' * (ContentLimits.text + 1))]),
      languages: langs,
    );
    expect(messages(r).single, contains('limit is ${ContentLimits.text}'));
  });

  test('unknown level is an error', () {
    final r = validateCategory(
      ContentCatalog.englishWords,
      wordFile([word('en_0001', level: 'C2')]),
      languages: langs,
    );
    expect(messages(r).single, startsWith('"level" must be one of'));
  });

  test('dictionary details are optional and checked', () {
    final full = word('en_0001')
      ..['syllables'] = 're·sil·ient'
      ..['ipa'] = 'rɪˈzɪliənt'
      ..['pos'] = 'adj';
    final ok = validateCategory(
      ContentCatalog.englishWords,
      wordFile([full]),
      languages: langs,
    );
    expect(ok.issues, isEmpty);
    final item = ok.items.single as WordItem;
    expect(
      (item.syllables, item.ipa, item.partOfSpeech),
      ('re·sil·ient', 'rɪˈzɪliənt', PartOfSpeech.adj),
    );

    final bad = validateCategory(
      ContentCatalog.englishWords,
      wordFile([
        word('en_0001')..['syllables'] = 're·sil·ent',
        word('en_0002', word: 'brave')..['ipa'] = '/breɪv/',
        word('en_0003', word: 'calm')..['pos'] = 'adjective',
      ]),
      languages: langs,
    );
    expect(bad.items, isEmpty);
    expect(messages(bad), [
      startsWith('"syllables"'),
      startsWith('"ipa"'),
      startsWith('"pos"'),
    ]);
  });

  test('unknown fields are warnings, not errors', () {
    final item = text('mo_0001')..['author'] = 'someone';
    final r = validateCategory(
      ContentCatalog.motivation,
      textFile([item]),
      languages: langs,
    );
    expect(r.hasErrors, isFalse);
    expect(r.issues.single.severity, IssueSeverity.warning);
    expect(r.items, hasLength(1));
  });

  test('isPremium is read and must be a bool', () {
    final premium = text('mo_0001')..['isPremium'] = true;
    final wrong = text('mo_0002', en: 'Another.')..['isPremium'] = 'yes';
    final r = validateCategory(
      ContentCatalog.motivation,
      textFile([premium, wrong]),
      languages: langs,
    );
    expect(r.items.single.isPremium, isTrue);
    expect(messages(r), contains('"isPremium" must be true or false'));
  });

  test('wrong file header is reported', () {
    final r = validateCategory(ContentCatalog.motivation, {
      'category': 'other',
      'kind': 'word',
      'items': <Object?>[],
    }, languages: langs);
    expect(r.issues.where((i) => i.itemId == null), hasLength(2));
  });

  test('ids shared between categories are reported', () {
    final a = validateCategory(
      ContentCatalog.motivation,
      textFile([text('mo_0001')]),
      languages: langs,
    );
    final b = CategoryValidation(ContentCatalog.softwareTips)
      ..items.add(a.items.single);
    expect(
      validateAcrossCategories([a, b]).single.message,
      contains('also used in motivation'),
    );
  });
}
