import 'package:flutter/material.dart';

import '../app/daily_wallpaper_service.dart' as service;
import '../data/content_models.dart';
import '../domain/user_settings.dart';
import '../l10n/gen/app_localizations.dart';

/// Localized names for domain values, kept in one place.
extension Labels on AppLocalizations {
  String category(String id) => service.categoryLabel(this, id);

  String categoryDescription(String id) => switch (id) {
    'english_words' => categoryEnglishWordsDescription,
    'software_tips' => categorySoftwareTipsDescription,
    'motivation' => categoryMotivationDescription,
    'general_knowledge' => categoryGeneralKnowledgeDescription,
    _ => '',
  };

  String level(CefrLevel level) => switch (level) {
    CefrLevel.a1 => levelA1,
    CefrLevel.a2 => levelA2,
    CefrLevel.b1 => levelB1,
    CefrLevel.b2 => levelB2,
    CefrLevel.c1 => levelC1,
  };

  String target(WallpaperTarget t) => switch (t) {
    WallpaperTarget.lock => targetLock,
    WallpaperTarget.home => targetHome,
    WallpaperTarget.both => targetBoth,
  };
}

IconData categoryIcon(String id) => switch (id) {
  'english_words' => Icons.translate_rounded,
  'software_tips' => Icons.code_rounded,
  'motivation' => Icons.wb_sunny_outlined,
  'general_knowledge' => Icons.lightbulb_outline_rounded,
  _ => Icons.category_outlined,
};

IconData targetIcon(WallpaperTarget t) => switch (t) {
  WallpaperTarget.lock => Icons.lock_outline_rounded,
  WallpaperTarget.home => Icons.home_outlined,
  WallpaperTarget.both => Icons.smartphone_rounded,
};

/// Language names are shown in their own language.
/// A language's own name ("Türkçe", "English"), read from its ARB file, so
/// adding a language needs no code change here.
String languageName(String code) {
  try {
    return lookupAppLocalizations(Locale(code)).languageNativeName;
  } on FlutterError {
    return code;
  }
}
