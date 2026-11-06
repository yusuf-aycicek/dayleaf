// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'dailywall';

  @override
  String get homeTitle => 'Today';

  @override
  String get historyTitle => 'History';

  @override
  String get favoritesTitle => 'Favorites';

  @override
  String get settingsTitle => 'Settings';
}
