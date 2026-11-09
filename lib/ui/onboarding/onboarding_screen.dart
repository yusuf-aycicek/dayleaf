import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/daily_wallpaper_service.dart';
import '../../app/providers.dart';
import '../../core/app_config.dart';
import '../../data/content_models.dart';
import '../../domain/user_settings.dart';
import '../../l10n/gen/app_localizations.dart';
import '../labels.dart';
import '../widgets/choice_tiles.dart';
import '../widgets/template_preview.dart';
import '../widgets/ya_logo.dart';

enum _Step { language, interests, level, target, template, apply }

/// First run: language → interests → (English level) → where → style →
/// apply. Choices are saved as they are made, so the language switches
/// immediately and nothing is lost if the app is closed midway.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _index = 0;
  bool _applying = false;

  List<_Step> _steps(UserSettings s) => [
    _Step.language,
    _Step.interests,
    if (s.wantsEnglish) _Step.level,
    _Step.target,
    _Step.template,
    _Step.apply,
  ];

  void _update(UserSettings Function(UserSettings) change) =>
      ref.read(settingsProvider.notifier).change(change);

  Future<void> _finish() async {
    setState(() => _applying = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // Completing onboarding makes the root replace this screen, so nothing
    // below may use `ref` or `context` after the first await.
    final settings = ref.read(settingsProvider.notifier);
    final service = ref.read(serviceProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    await settings.change((s) => s.copyWith(onboardingComplete: true));
    final result = await service.ensureToday(
      trigger: ApplyTrigger.user,
      force: true,
    );
    container.invalidate(progressProvider);
    // The root swaps this screen for the home screen once onboarding is
    // complete, so this widget may be gone; the messenger is not.
    if (mounted) setState(() => _applying = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.outcome == ApplyOutcome.applied
              ? l10n.applied
              : l10n.applyFailed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider).value ?? const UserSettings();
    final steps = _steps(settings);
    final index = _index.clamp(0, steps.length - 1);
    final step = steps[index];
    final canContinue =
        step != _Step.interests || settings.categoryIds.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(value: (index + 1) / steps.length),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey(step),
                  child: _buildStep(context, step, settings),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  if (index > 0)
                    TextButton(
                      onPressed: _applying
                          ? null
                          : () => setState(() => _index = index - 1),
                      child: Text(l10n.back),
                    ),
                  const SizedBox(width: 8),
                  // Takes the remaining width, so a long label wraps
                  // instead of overflowing at a large font size.
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: step == _Step.apply
                          ? FilledButton.icon(
                              onPressed: _applying ? null : _finish,
                              icon: _applying
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.wallpaper_rounded),
                              label: Text(l10n.onboardingApplyButton),
                            )
                          : FilledButton(
                              onPressed: canContinue
                                  ? () => setState(() => _index = index + 1)
                                  : null,
                              child: Text(
                                canContinue ? l10n.next : l10n.selectAtLeastOne,
                                textAlign: TextAlign.center,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, _Step step, UserSettings s) {
    final l10n = AppLocalizations.of(context);
    final language =
        s.languageCode ?? Localizations.localeOf(context).languageCode;
    switch (step) {
      case _Step.language:
        return _StepPage(
          title: l10n.onboardingLanguageTitle,
          body: l10n.onboardingLanguageBody,
          footer: const _Signature(),
          children: [
            for (final code in appLanguages)
              ChoiceTile(
                title: languageName(code),
                selected: language == code,
                onTap: () => _update((x) => x.copyWith(languageCode: code)),
              ),
          ],
        );
      case _Step.interests:
        return _StepPage(
          title: l10n.onboardingInterestsTitle,
          body: l10n.onboardingInterestsBody,
          children: [
            for (final c in ContentCatalog.categories)
              ChoiceTile(
                title: l10n.category(c.id),
                subtitle: l10n.categoryDescription(c.id),
                icon: categoryIcon(c.id),
                multi: true,
                selected: s.categoryIds.contains(c.id),
                onTap: () => _update(
                  (x) => x.copyWith(
                    categoryIds: toggleCategory(x.categoryIds, c.id),
                  ),
                ),
              ),
          ],
        );
      case _Step.level:
        return _StepPage(
          title: l10n.onboardingLevelTitle,
          body: l10n.onboardingLevelBody,
          children: [
            for (final level in CefrLevel.values)
              ChoiceTile(
                title: '${level.code} · ${l10n.level(level)}',
                selected: s.englishLevel == level,
                onTap: () => _update((x) => x.copyWith(englishLevel: level)),
              ),
          ],
        );
      case _Step.target:
        return _StepPage(
          title: l10n.onboardingTargetTitle,
          body: l10n.onboardingTargetBody,
          children: [
            for (final t in WallpaperTarget.values)
              ChoiceTile(
                title: l10n.target(t),
                icon: targetIcon(t),
                selected: s.target == t,
                onTap: () => _update((x) => x.copyWith(target: t)),
              ),
          ],
        );
      case _Step.template:
        return _StepPage(
          title: l10n.onboardingTemplateTitle,
          body: l10n.onboardingTemplateBody,
          children: [
            TemplatePicker(
              selected: s.templateId,
              settings: s,
              onSelected: (id) => _update((x) => x.copyWith(templateId: id)),
            ),
          ],
        );
      case _Step.apply:
        return _StepPage(
          title: l10n.onboardingApplyTitle,
          body: l10n.onboardingApplyBody,
          children: const [
            Padding(
              padding: EdgeInsets.only(top: 24),
              child: Icon(Icons.offline_bolt_outlined, size: 56),
            ),
          ],
        );
    }
  }
}

/// Adds or removes [id], keeping catalog order.
List<String> toggleCategory(List<String> ids, String id) {
  final set = {...ids};
  if (!set.remove(id)) set.add(id);
  return [
    for (final c in ContentCatalog.categories)
      if (set.contains(c.id)) c.id,
  ];
}

class _StepPage extends StatelessWidget {
  const _StepPage({
    required this.title,
    required this.body,
    required this.children,
    this.footer,
  });

  final String title;
  final String body;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
          sliver: SliverList.list(
            children: [
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
        if (footer != null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Align(alignment: Alignment.bottomCenter, child: footer),
          ),
      ],
    );
  }
}

/// The small personal signature on the first onboarding page.
class _Signature extends StatelessWidget {
  const _Signature();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const YaLogo(size: 28),
          const SizedBox(width: 10),
          Text(
            AppConfig.developerName,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
