import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Google Play limits for docs/store-listing.md.
void main() {
  final text = File('docs/store-listing.md').readAsStringSync();

  String section(String name) {
    final match = RegExp(
      '<!-- $name -->'
      r'\s*(.*?)\s*'
      '<!-- /$name -->',
      dotAll: true,
    ).firstMatch(text);
    expect(match, isNotNull, reason: 'missing <!-- $name --> block');
    return match!.group(1)!;
  }

  for (final lang in ['en', 'tr']) {
    test('$lang short description fits in 80 characters', () {
      final short = section('short:$lang');
      expect(short.runes.length, inInclusiveRange(10, 80), reason: short);
      expect(short.contains('\n'), isFalse);
    });

    test('$lang long description fits in 4000 characters', () {
      expect(section('long:$lang').runes.length, inInclusiveRange(200, 4000));
    });

    test('$lang closed-test invitation is present', () {
      expect(section('invite:$lang'), isNotEmpty);
    });
  }
}
