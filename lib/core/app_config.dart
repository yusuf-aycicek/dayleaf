/// App-wide constants. Renaming the app on the Dart side happens here;
/// the Android package name and launcher label live in
/// `android/gradle.properties` (`dailywall.applicationId`, `dailywall.appLabel`).
abstract final class AppConfig {
  /// Display name, also used for the watermark on shared images.
  static const String appName = 'dailywall';

  static const String developerName = 'Yusuf Ayçiçek';
  static const String githubUser = 'yusuf-aycicek';
  static const String repositoryUrl =
      'https://github.com/yusuf-aycicek/dailywall';
  static const String privacyPolicyUrl =
      'https://yusuf-aycicek.github.io/dailywall/privacy-policy';
}
