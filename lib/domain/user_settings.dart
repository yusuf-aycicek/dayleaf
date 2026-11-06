import '../data/content_models.dart';

/// Where the generated wallpaper is applied.
enum WallpaperTarget {
  lock,
  home,
  both;

  static WallpaperTarget parse(Object? name) =>
      values.firstWhere((t) => t.name == name, orElse: () => both);
}

/// Everything the user picks in onboarding and settings.
class UserSettings {
  const UserSettings({
    this.languageCode,
    this.categoryIds = const [],
    this.englishLevel = CefrLevel.b1,
    this.target = WallpaperTarget.both,
    this.templateId = 'minimal',
    this.dailyChangeEnabled = true,
    this.onboardingComplete = false,
  });

  /// Interface and content language; null means "follow the system".
  final String? languageCode;

  /// Selected categories. Rotation follows [ContentCatalog.categories] order.
  final List<String> categoryIds;
  final CefrLevel englishLevel;
  final WallpaperTarget target;
  final String templateId;
  final bool dailyChangeEnabled;
  final bool onboardingComplete;

  bool get wantsEnglish => categoryIds.contains(ContentCatalog.englishWords.id);

  UserSettings copyWith({
    String? languageCode,
    List<String>? categoryIds,
    CefrLevel? englishLevel,
    WallpaperTarget? target,
    String? templateId,
    bool? dailyChangeEnabled,
    bool? onboardingComplete,
  }) => UserSettings(
    languageCode: languageCode ?? this.languageCode,
    categoryIds: categoryIds ?? this.categoryIds,
    englishLevel: englishLevel ?? this.englishLevel,
    target: target ?? this.target,
    templateId: templateId ?? this.templateId,
    dailyChangeEnabled: dailyChangeEnabled ?? this.dailyChangeEnabled,
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
  );

  Map<String, Object?> toJson() => {
    'languageCode': languageCode,
    'categoryIds': categoryIds,
    'englishLevel': englishLevel.code,
    'target': target.name,
    'templateId': templateId,
    'dailyChangeEnabled': dailyChangeEnabled,
    'onboardingComplete': onboardingComplete,
  };

  factory UserSettings.fromJson(Map<String, Object?> json) => UserSettings(
    languageCode: json['languageCode'] as String?,
    categoryIds: [
      for (final id in (json['categoryIds'] as List<Object?>? ?? const []))
        if (id is String && ContentCatalog.byId(id) != null) id,
    ],
    englishLevel: CefrLevel.tryParse(json['englishLevel']) ?? CefrLevel.b1,
    target: WallpaperTarget.parse(json['target']),
    templateId: json['templateId'] as String? ?? 'minimal',
    dailyChangeEnabled: json['dailyChangeEnabled'] as bool? ?? true,
    onboardingComplete: json['onboardingComplete'] as bool? ?? false,
  );
}
