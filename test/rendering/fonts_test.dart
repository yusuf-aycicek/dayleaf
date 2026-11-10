import 'dart:io';
import 'dart:typed_data';

import 'package:dailywall/rendering/style/fonts.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fonts.dart';

/// Code points a font maps to glyphs (cmap formats 4 and 12).
Set<int> cmapCodePoints(Uint8List bytes) {
  final d = ByteData.sublistView(bytes);
  final tables = d.getUint16(4);
  int? cmap;
  for (var i = 0; i < tables; i++) {
    final rec = 12 + i * 16;
    if (String.fromCharCodes(bytes.sublist(rec, rec + 4)) == 'cmap') {
      cmap = d.getUint32(rec + 8);
    }
  }
  final out = <int>{};
  if (cmap == null) return out;
  final n = d.getUint16(cmap + 2);
  for (var i = 0; i < n; i++) {
    final sub = cmap + d.getUint32(cmap + 4 + i * 8 + 4);
    switch (d.getUint16(sub)) {
      case 4:
        final segs = d.getUint16(sub + 6) ~/ 2;
        final ends = sub + 14, starts = ends + segs * 2 + 2;
        final deltas = starts + segs * 2, offsets = deltas + segs * 2;
        for (var s = 0; s < segs; s++) {
          final end = d.getUint16(ends + s * 2);
          final start = d.getUint16(starts + s * 2);
          final delta = d.getInt16(deltas + s * 2);
          final ro = d.getUint16(offsets + s * 2);
          for (var c = start; c <= end && c != 0xFFFF; c++) {
            var glyph = 0;
            if (ro == 0) {
              glyph = (c + delta) & 0xFFFF;
            } else {
              final at = offsets + s * 2 + ro + (c - start) * 2;
              glyph = d.getUint16(at);
              if (glyph != 0) glyph = (glyph + delta) & 0xFFFF;
            }
            if (glyph != 0) out.add(c);
          }
        }
      case 12:
        final groups = d.getUint32(sub + 12);
        for (var g = 0; g < groups; g++) {
          final at = sub + 16 + g * 12;
          final start = d.getUint32(at), end = d.getUint32(at + 4);
          for (var c = start; c <= end && c < 0x30000; c++) {
            out.add(c);
          }
        }
    }
  }
  return out;
}

void main() {
  final fonts = pubspecFonts();

  test('every bundled family is declared in pubspec.yaml with a license', () {
    expect(fonts.keys.toSet(), BundledFonts.families);
    for (final (_, file) in BundledFonts.licenses) {
      expect(File('assets/fonts/$file').existsSync(), isTrue, reason: file);
    }
    expect(BundledFonts.licenses, hasLength(BundledFonts.families.length));
  });

  const turkish = 'ÇçĞğİıÖöŞşÜü';
  const punctuation = '·’“”–—';
  for (final MapEntry(key: family, value: paths) in fonts.entries) {
    for (final path in paths) {
      test('$family ($path) has Turkish letters and the punctuation used', () {
        final cps = cmapCodePoints(File(path).readAsBytesSync());
        final missing = [
          for (final r in '$turkish$punctuation'.runes)
            if (!cps.contains(r)) String.fromCharCode(r),
        ];
        expect(missing, isEmpty, reason: '$path lacks ${missing.join()}');
      });
    }
  }

  test('the fallback font covers every pronunciation in the content', () {
    final ipa = {
      for (final m in RegExp(r'"ipa": "([^"]*)"').allMatches(
        File('assets/content/english_words.json').readAsStringSync(),
      ))
        ...m.group(1)!.runes,
    };
    expect(ipa, isNotEmpty);
    for (final path in fonts[BundledFonts.gentium]!) {
      final cps = cmapCodePoints(File(path).readAsBytesSync());
      final missing = [
        for (final r in ipa)
          if (!cps.contains(r)) String.fromCharCode(r),
      ];
      expect(missing, isEmpty, reason: '$path lacks ${missing.join()}');
    }
  });
}
