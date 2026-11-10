import 'dart:io';

import 'package:flutter/services.dart';

/// Font families and files declared in pubspec.yaml (the single source).
Map<String, List<String>> pubspecFonts() {
  final fonts = <String, List<String>>{};
  String? family;
  for (final line in File('pubspec.yaml').readAsLinesSync()) {
    final f = RegExp(r'^\s*- family:\s*(\S+)').firstMatch(line);
    if (f != null) {
      family = f.group(1);
      fonts[family!] = [];
      continue;
    }
    final a = RegExp(r'^\s*- asset:\s*(assets/fonts/\S+)').firstMatch(line);
    if (a != null && family != null) fonts[family]!.add(a.group(1)!);
  }
  return fonts;
}

/// `flutter test` does not load app fonts by itself; text would be measured
/// with a placeholder font. Load the bundled ones so layout tests measure
/// the real glyphs.
Future<void> loadAppFonts() async {
  for (final MapEntry(key: family, value: paths) in pubspecFonts().entries) {
    final loader = FontLoader(family);
    for (final path in paths) {
      final bytes = File(path).readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}
