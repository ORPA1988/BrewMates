import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Adaptive Navigation: Tab-Bar auf Telefonen, Navigation-Rail ab 800 px
/// (Windows/Desktop/Tablet) – siehe docs/05-ui-screens.md.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _destinations = [
    (icon: Icons.home_outlined, selected: Icons.home, label: 'Feed'),
    (icon: Icons.map_outlined, selected: Icons.map, label: 'Karte'),
    (icon: Icons.search_outlined, selected: Icons.search, label: 'Entdecken'),
    (icon: Icons.person_outline, selected: Icons.person, label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 800;

    final fab = FloatingActionButton.extended(
      onPressed: () => context.push('/session/start'),
      icon: const Text('🍺', style: TextStyle(fontSize: 20)),
      label: const Text('Session'),
    );

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: shell.goBranch,
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: fab,
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selected),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: shell),
          ],
        ),
      );
    }

    return Scaffold(
      body: shell,
      floatingActionButton: fab,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: shell.goBranch,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selected),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
