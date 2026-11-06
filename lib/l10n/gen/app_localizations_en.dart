// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languageNativeName => 'English';

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

  @override
  String get categoryEnglishWords => 'English word';

  @override
  String get categorySoftwareTips => 'Software tip';

  @override
  String get categoryMotivation => 'Motivation';

  @override
  String get categoryGeneralKnowledge => 'General knowledge';

  @override
  String get categoryEnglishWordsDescription =>
      'A new word with its meaning and an example';

  @override
  String get categorySoftwareTipsDescription =>
      'Practical tips for writing better code';

  @override
  String get categoryMotivationDescription =>
      'A short thought to start your day';

  @override
  String get categoryGeneralKnowledgeDescription =>
      'A surprising, checked fact';

  @override
  String get levelA1 => 'Beginner';

  @override
  String get levelA2 => 'Elementary';

  @override
  String get levelB1 => 'Intermediate';

  @override
  String get levelB2 => 'Upper intermediate';

  @override
  String get levelC1 => 'Advanced';

  @override
  String get targetLock => 'Lock screen';

  @override
  String get targetHome => 'Home screen';

  @override
  String get targetBoth => 'Both';

  @override
  String get templateMinimal => 'Minimal';

  @override
  String get templateCard => 'Card';

  @override
  String get templateBold => 'Bold type';

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String get selectAtLeastOne => 'Select at least one';

  @override
  String get onboardingLanguageTitle => 'Choose your language';

  @override
  String get onboardingLanguageBody =>
      'The app and your daily content will use this language.';

  @override
  String get onboardingInterestsTitle =>
      'What would you like to see every day?';

  @override
  String get onboardingInterestsBody =>
      'Pick one or more. They take turns day by day.';

  @override
  String get onboardingLevelTitle => 'Your English level';

  @override
  String get onboardingLevelBody =>
      'Words are chosen for this level. You can change it later.';

  @override
  String get onboardingTargetTitle => 'Where should it appear?';

  @override
  String get onboardingTargetBody => 'You can change this later in Settings.';

  @override
  String get onboardingTemplateTitle => 'Pick a style';

  @override
  String get onboardingTemplateBody =>
      'Backgrounds are generated on your phone and change every day.';

  @override
  String get onboardingApplyTitle => 'All set';

  @override
  String get onboardingApplyBody =>
      'dailywall creates today\'s wallpaper on your phone and changes it every day. Setting a wallpaper needs no extra permission, and nothing leaves your device.';

  @override
  String get onboardingApplyButton => 'Set my wallpaper';

  @override
  String get applyNow => 'Apply now';

  @override
  String get applied => 'Wallpaper updated';

  @override
  String get applyFailed => 'Couldn\'t set the wallpaper';

  @override
  String get favorite => 'Favorite';

  @override
  String get unfavorite => 'Remove from favorites';

  @override
  String get share => 'Share';

  @override
  String get iKnowThis => 'I know this';

  @override
  String get showAgain => 'Show again';

  @override
  String get knownMarked => 'This word won\'t be shown again';

  @override
  String get repeatMarked => 'This word will come back in 2 days';

  @override
  String get reviewBadge => 'Review';

  @override
  String get noContent => 'Choose at least one interest in Settings.';

  @override
  String get previewLabel => 'Preview of today\'s wallpaper';

  @override
  String get historyEmpty => 'Content from previous days will appear here.';

  @override
  String get favoritesEmpty => 'Tap the heart on a wallpaper to keep it here.';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsInterests => 'Interests';

  @override
  String get settingsLevel => 'English level';

  @override
  String get settingsTarget => 'Apply to';

  @override
  String get settingsTemplate => 'Style';

  @override
  String get settingsDailyChange => 'Change every day';

  @override
  String get settingsDailyChangeSubtitle =>
      'A new wallpaper is set automatically each day.';

  @override
  String get settingsAbout => 'About';

  @override
  String get done => 'Done';

  @override
  String get cancel => 'Cancel';

  @override
  String get aboutDescription =>
      'Daily wallpapers created on your device from your interests. Works fully offline.';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutDeveloper => 'Developer';

  @override
  String get aboutSourceCode => 'Source code on GitHub';

  @override
  String get aboutPrivacy => 'Privacy policy';

  @override
  String get aboutLicenses => 'Open source licenses';

  @override
  String get logoLabel => 'Yusuf Ayçiçek\'s logo';
}
