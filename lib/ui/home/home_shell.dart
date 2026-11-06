import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../favorites/favorites_screen.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import 'today_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          TodayScreen(),
          HistoryScreen(),
          FavoritesScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.wallpaper_outlined),
            selectedIcon: const Icon(Icons.wallpaper_rounded),
            label: l10n.homeTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_rounded),
            label: l10n.historyTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.favorite_border_rounded),
            selectedIcon: const Icon(Icons.favorite_rounded),
            label: l10n.favoritesTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: l10n.settingsTitle,
          ),
        ],
      ),
    );
  }
}
