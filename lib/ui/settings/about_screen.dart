import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_config.dart';
import '../../l10n/gen/app_localizations.dart';
import '../widgets/ya_logo.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAbout)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppConfig.appName,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snap) => Text(
                    l10n.aboutVersion(
                      snap.data == null
                          ? '…'
                          : '${snap.data!.version} (${snap.data!.buildNumber})',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(l10n.aboutDescription, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const YaLogo(size: 40),
            title: const Text(AppConfig.developerName),
            subtitle: Text(l10n.aboutDeveloper),
          ),
          ListTile(
            leading: const Icon(Icons.code_rounded),
            title: Text(l10n.aboutSourceCode),
            subtitle: const Text('github.com/${AppConfig.githubUser}'),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: () => _open(AppConfig.repositoryUrl),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.aboutPrivacy),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: () => _open(AppConfig.privacyPolicyUrl),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l10n.aboutLicenses),
            onTap: () => showLicensePage(
              context: context,
              applicationName: AppConfig.appName,
              applicationIcon: const Padding(
                padding: EdgeInsets.all(8),
                child: YaLogo(size: 40),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
