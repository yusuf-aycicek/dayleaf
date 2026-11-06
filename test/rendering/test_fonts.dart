import 'dart:io';

import 'package:flutter/services.dart';

/// `flutter test` does not load app fonts by itself; text would be measured
/// with a placeholder font. Load the bundled ones so layout tests measure
/// the real glyphs.
Future<void> loadAppFonts() async {
  const families = {
    'Manrope': 'assets/fonts/Manrope-Variable.ttf',
    'Lora': 'assets/fonts/Lora-Variable.ttf',
    'Anton': 'assets/fonts/Anton-Regular.ttf',
    'JetBrainsMono': 'assets/fonts/JetBrainsMono-Variable.ttf',
  };
  for (final MapEntry(key: family, value: path) in families.entries) {
    final bytes = File(path).readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
    await loader.load();
  }
}
