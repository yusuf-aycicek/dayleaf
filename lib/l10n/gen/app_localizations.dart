import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// The name of this language, written in this language. Shown in the language picker.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageNativeName;

  /// App name. Not translated.
  ///
  /// In en, this message translates to:
  /// **'dailywall'**
  String get appTitle;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get homeTitle;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// No description provided for @favoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favoritesTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @categoryEnglishWords.
  ///
  /// In en, this message translates to:
  /// **'English word'**
  String get categoryEnglishWords;

  /// No description provided for @categorySoftwareTips.
  ///
  /// In en, this message translates to:
  /// **'Software tip'**
  String get categorySoftwareTips;

  /// No description provided for @categoryMotivation.
  ///
  /// In en, this message translates to:
  /// **'Motivation'**
  String get categoryMotivation;

  /// No description provided for @categoryGeneralKnowledge.
  ///
  /// In en, this message translates to:
  /// **'General knowledge'**
  String get categoryGeneralKnowledge;

  /// No description provided for @categoryEnglishWordsDescription.
  ///
  /// In en, this message translates to:
  /// **'A new word with its meaning and an example'**
  String get categoryEnglishWordsDescription;

  /// No description provided for @categorySoftwareTipsDescription.
  ///
  /// In en, this message translates to:
  /// **'Practical tips for writing better code'**
  String get categorySoftwareTipsDescription;

  /// No description provided for @categoryMotivationDescription.
  ///
  /// In en, this message translates to:
  /// **'A short thought to start your day'**
  String get categoryMotivationDescription;

  /// No description provided for @categoryGeneralKnowledgeDescription.
  ///
  /// In en, this message translates to:
  /// **'A surprising, checked fact'**
  String get categoryGeneralKnowledgeDescription;

  /// No description provided for @levelA1.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get levelA1;

  /// No description provided for @levelA2.
  ///
  /// In en, this message translates to:
  /// **'Elementary'**
  String get levelA2;

  /// No description provided for @levelB1.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get levelB1;

  /// No description provided for @levelB2.
  ///
  /// In en, this message translates to:
  /// **'Upper intermediate'**
  String get levelB2;

  /// No description provided for @levelC1.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get levelC1;

  /// No description provided for @targetLock.
  ///
  /// In en, this message translates to:
  /// **'Lock screen'**
  String get targetLock;

  /// No description provided for @targetHome.
  ///
  /// In en, this message translates to:
  /// **'Home screen'**
  String get targetHome;

  /// No description provided for @targetBoth.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get targetBoth;

  /// No description provided for @templateMinimal.
  ///
  /// In en, this message translates to:
  /// **'Minimal'**
  String get templateMinimal;

  /// No description provided for @templateCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get templateCard;

  /// No description provided for @templateBold.
  ///
  /// In en, this message translates to:
  /// **'Bold type'**
  String get templateBold;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @selectAtLeastOne.
  ///
  /// In en, this message translates to:
  /// **'Select at least one'**
  String get selectAtLeastOne;

  /// No description provided for @onboardingLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get onboardingLanguageTitle;

  /// No description provided for @onboardingLanguageBody.
  ///
  /// In en, this message translates to:
  /// **'The app and your daily content will use this language.'**
  String get onboardingLanguageBody;

  /// No description provided for @onboardingInterestsTitle.
  ///
  /// In en, this message translates to:
  /// **'What would you like to see every day?'**
  String get onboardingInterestsTitle;

  /// No description provided for @onboardingInterestsBody.
  ///
  /// In en, this message translates to:
  /// **'Pick one or more. They take turns day by day.'**
  String get onboardingInterestsBody;

  /// No description provided for @onboardingLevelTitle.
  ///
  /// In en, this message translates to:
  /// **'Your English level'**
  String get onboardingLevelTitle;

  /// No description provided for @onboardingLevelBody.
  ///
  /// In en, this message translates to:
  /// **'Words are chosen for this level. You can change it later.'**
  String get onboardingLevelBody;

  /// No description provided for @onboardingTargetTitle.
  ///
  /// In en, this message translates to:
  /// **'Where should it appear?'**
  String get onboardingTargetTitle;

  /// No description provided for @onboardingTargetBody.
  ///
  /// In en, this message translates to:
  /// **'You can change this later in Settings.'**
  String get onboardingTargetBody;

  /// No description provided for @onboardingTemplateTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a style'**
  String get onboardingTemplateTitle;

  /// No description provided for @onboardingTemplateBody.
  ///
  /// In en, this message translates to:
  /// **'Backgrounds are generated on your phone and change every day.'**
  String get onboardingTemplateBody;

  /// No description provided for @onboardingApplyTitle.
  ///
  /// In en, this message translates to:
  /// **'All set'**
  String get onboardingApplyTitle;

  /// No description provided for @onboardingApplyBody.
  ///
  /// In en, this message translates to:
  /// **'dailywall creates today\'s wallpaper on your phone and changes it every day. Setting a wallpaper needs no extra permission, and nothing leaves your device.'**
  String get onboardingApplyBody;

  /// No description provided for @onboardingApplyButton.
  ///
  /// In en, this message translates to:
  /// **'Set my wallpaper'**
  String get onboardingApplyButton;

  /// No description provided for @applyNow.
  ///
  /// In en, this message translates to:
  /// **'Apply now'**
  String get applyNow;

  /// No description provided for @applied.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper updated'**
  String get applied;

  /// No description provided for @applyFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t set the wallpaper'**
  String get applyFailed;

  /// No description provided for @favorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get favorite;

  /// No description provided for @unfavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get unfavorite;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @iKnowThis.
  ///
  /// In en, this message translates to:
  /// **'I know this'**
  String get iKnowThis;

  /// No description provided for @showAgain.
  ///
  /// In en, this message translates to:
  /// **'Show again'**
  String get showAgain;

  /// No description provided for @knownMarked.
  ///
  /// In en, this message translates to:
  /// **'This word won\'t be shown again'**
  String get knownMarked;

  /// No description provided for @repeatMarked.
  ///
  /// In en, this message translates to:
  /// **'This word will come back in 2 days'**
  String get repeatMarked;

  /// No description provided for @reviewBadge.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get reviewBadge;

  /// No description provided for @noContent.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one interest in Settings.'**
  String get noContent;

  /// No description provided for @previewLabel.
  ///
  /// In en, this message translates to:
  /// **'Preview of today\'s wallpaper'**
  String get previewLabel;

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'Content from previous days will appear here.'**
  String get historyEmpty;

  /// No description provided for @favoritesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart on a wallpaper to keep it here.'**
  String get favoritesEmpty;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsInterests.
  ///
  /// In en, this message translates to:
  /// **'Interests'**
  String get settingsInterests;

  /// No description provided for @settingsLevel.
  ///
  /// In en, this message translates to:
  /// **'English level'**
  String get settingsLevel;

  /// No description provided for @settingsTarget.
  ///
  /// In en, this message translates to:
  /// **'Apply to'**
  String get settingsTarget;

  /// No description provided for @settingsTemplate.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get settingsTemplate;

  /// No description provided for @settingsDailyChange.
  ///
  /// In en, this message translates to:
  /// **'Change every day'**
  String get settingsDailyChange;

  /// No description provided for @settingsDailyChangeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A new wallpaper is set automatically each day.'**
  String get settingsDailyChangeSubtitle;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Daily wallpapers created on your device from your interests. Works fully offline.'**
  String get aboutDescription;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// No description provided for @aboutDeveloper.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get aboutDeveloper;

  /// No description provided for @aboutSourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code on GitHub'**
  String get aboutSourceCode;

  /// No description provided for @aboutPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get aboutPrivacy;

  /// No description provided for @aboutLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open source licenses'**
  String get aboutLicenses;

  /// No description provided for @logoLabel.
  ///
  /// In en, this message translates to:
  /// **'Yusuf Ayçiçek\'s logo'**
  String get logoLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
