import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/providers.dart';

/// Adaptive Navigation: Tab-Bar auf Telefonen, Navigation-Rail ab 800 px
/// (Windows/Desktop/Tablet) – siehe docs/05-ui-screens.md.
/// Zeigt app-weit das Banner der eigenen aktiven Session (Standort-Indikator).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _destinations = [
    (icon: Icons.home_outlined, selected: Icons.home, label: 'Feed'),
    (icon: Icons.map_outlined, selected: Icons.map, label: 'Karte'),
    (icon: Icons.search_outlined, selected: Icons.search, label: 'Entdecken'),
    (icon: Icons.person_outline, selected: Icons.person, label: 'Profil'),
  ];

  void _openActionSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('🍺', style: TextStyle(fontSize: 28)),
              title: const Text('Session starten'),
              subtitle: const Text('Freunde wissen lassen, wo du bist'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push('/session/start');
              },
            ),
            ListTile(
              leading: const Text('✅', style: TextStyle(fontSize: 28)),
              title: const Text('Bier einchecken'),
              subtitle: const Text('Bewerten und ins Tagebuch aufnehmen'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push('/checkin');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.sizeOf(context).width >= 800;
    final mySession = ref.watch(myActiveSessionProvider).valueOrNull;

    final fab = FloatingActionButton.extended(
      onPressed: () => _openActionSheet(context),
      icon: const Text('🍺', style: TextStyle(fontSize: 20)),
      label: const Text('Los!'),
    );

    final body = Column(
      children: [
        if (mySession != null)
          Material(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: SafeArea(
              bottom: false,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.wifi_tethering),
                title: Text(
                  'Aktive Session'
                  '${mySession.venueName != null ? ' im ${mySession.venueName}' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle:
                    Text('Endet in ${remaining(mySession.expiresAt)}'),
                trailing: TextButton(
                  onPressed: () =>
                      ref.read(actionsProvider).endMySession(),
                  child: const Text('Beenden'),
                ),
                onTap: () => context.push('/session/${mySession.id}'),
              ),
            ),
          ),
        Expanded(child: shell),
      ],
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
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
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
