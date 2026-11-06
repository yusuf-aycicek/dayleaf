import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/daily_wallpaper_service.dart';
import '../../app/providers.dart';
import '../../data/content_models.dart';
import '../../domain/user_settings.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../platform/background_tasks.dart';
import '../labels.dart';
import '../onboarding/onboarding_screen.dart' show toggleCategory;
import '../widgets/choice_tiles.dart';
import '../widgets/template_preview.dart';
import 'about_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider).value;
    if (settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    void update(UserSettings Function(UserSettings) change) =>
        ref.read(settingsProvider.notifier).change(change);
    final language =
        settings.languageCode ?? Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: Text(l10n.settingsLanguage),
            subtitle: Text(languageName(language)),
            onTap: () => _pick<String>(
              context,
              title: l10n.settingsLanguage,
              options: appLanguages,
              label: (c) => languageName(c),
              selected: language,
              onSelected: (c) => update((s) => s.copyWith(languageCode: c)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.interests_outlined),
            title: Text(l10n.settingsInterests),
            subtitle: Text(settings.categoryIds.map(l10n.category).join(', ')),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              isScrollControlled: true,
              builder: (_) => const _InterestsSheet(),
            ),
          ),
          if (settings.wantsEnglish)
            ListTile(
              leading: const Icon(Icons.school_outlined),
              title: Text(l10n.settingsLevel),
              subtitle: Text(
                '${settings.englishLevel.code} · ${l10n.level(settings.englishLevel)}',
              ),
              onTap: () => _pick<CefrLevel>(
                context,
                title: l10n.settingsLevel,
                options: CefrLevel.values,
                label: (l) => '${l.code} · ${l10n.level(l)}',
                selected: settings.englishLevel,
                onSelected: (l) => update((s) => s.copyWith(englishLevel: l)),
              ),
            ),
          ListTile(
            leading: Icon(targetIcon(settings.target)),
            title: Text(l10n.settingsTarget),
            subtitle: Text(l10n.target(settings.target)),
            onTap: () => _pick<WallpaperTarget>(
              context,
              title: l10n.settingsTarget,
              options: WallpaperTarget.values,
              label: l10n.target,
              selected: settings.target,
              onSelected: (t) => update((s) => s.copyWith(target: t)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.style_outlined),
            title: Text(l10n.settingsTemplate),
            subtitle: Text(l10n.template(settings.templateId)),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              isScrollControlled: true,
              builder: (sheet) => SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final s = ref.watch(settingsProvider).value ?? settings;
                      return TemplatePicker(
                        selected: s.templateId,
                        settings: s,
                        onSelected: (id) {
                          update((x) => x.copyWith(templateId: id));
                          Navigator.pop(sheet);
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.autorenew_rounded),
            title: Text(l10n.settingsDailyChange),
            subtitle: Text(l10n.settingsDailyChangeSubtitle),
            value: settings.dailyChangeEnabled,
            onChanged: (v) => update((s) => s.copyWith(dailyChangeEnabled: v)),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: Text(l10n.settingsAbout),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
            ),
          ),
          if (kDebugMode) const _DebugSection(),
        ],
      ),
    );
  }

  static Future<void> _pick<T>(
    BuildContext context, {
    required String title,
    required List<T> options,
    required String Function(T) label,
    required T selected,
    required ValueChanged<T> onSelected,
  }) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(title, style: Theme.of(sheet).textTheme.titleLarge),
            ),
            for (final o in options)
              ChoiceTile(
                title: label(o),
                selected: o == selected,
                onTap: () {
                  onSelected(o);
                  Navigator.pop(sheet);
                },
              ),
          ],
        ),
      ),
    ),
  );
}

class _InterestsSheet extends ConsumerWidget {
  const _InterestsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(settingsProvider).value ?? const UserSettings();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                l10n.settingsInterests,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final c in ContentCatalog.categories)
              ChoiceTile(
                title: l10n.category(c.id),
                subtitle: l10n.categoryDescription(c.id),
                icon: categoryIcon(c.id),
                multi: true,
                selected: s.categoryIds.contains(c.id),
                onTap: () {
                  final next = toggleCategory(s.categoryIds, c.id);
                  // At least one interest must stay selected.
                  if (next.isEmpty) return;
                  ref
                      .read(settingsProvider.notifier)
                      .change((x) => x.copyWith(categoryIds: next));
                },
              ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.done),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Debug builds only: test the daily change without waiting for it.
class _DebugSection extends ConsumerStatefulWidget {
  const _DebugSection();

  @override
  ConsumerState<_DebugSection> createState() => _DebugSectionState();
}

class _DebugSectionState extends ConsumerState<_DebugSection> {
  List<String> _log = const [];
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final store = ref.read(serviceProvider).store;
    final log = await store.loadBackgroundLog();
    final offset = await store.loadDebugDayOffset();
    if (!mounted) return;
    setState(() {
      _log = log;
      _offset = offset;
    });
  }

  Future<void> _shiftDays(int days) async {
    final service = ref.read(serviceProvider);
    await service.store.saveDebugDayOffset(days);
    final r = await service.ensureToday(trigger: ApplyTrigger.user);
    ref
      ..invalidate(todayProvider)
      ..invalidate(progressProvider);
    _snack('day offset $days: ${r.outcome.name}');
    await _refresh();
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const ListTile(title: Text('Developer (debug build only)')),
        ListTile(
          leading: const Icon(Icons.play_circle_outline_rounded),
          title: const Text('Run the background task now'),
          subtitle: const Text(
            'One-off WorkManager job, same code as the daily one',
          ),
          onTap: () async {
            await BackgroundTasks.runOnceNow();
            _snack('Enqueued. Check the log below in a few seconds.');
          },
        ),
        ListTile(
          leading: const Icon(Icons.fast_forward_rounded),
          title: Text('Pretend it is tomorrow (offset: $_offset)'),
          onTap: () => _shiftDays(_offset + 1),
        ),
        ListTile(
          leading: const Icon(Icons.restore_rounded),
          title: const Text('Reset day offset'),
          onTap: () => _shiftDays(0),
        ),
        ListTile(
          leading: const Icon(Icons.refresh_rounded),
          title: const Text('Background log'),
          subtitle: Text(
            _log.isEmpty ? 'No background runs yet' : _log.take(8).join('\n'),
          ),
          onTap: _refresh,
        ),
      ],
    );
  }
}
