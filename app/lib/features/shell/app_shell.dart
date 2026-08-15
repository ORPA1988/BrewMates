import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/providers.dart';

/// Adaptive Navigation: Tab-Bar auf Telefonen, Navigation-Rail ab 800 px
/// (Windows/Desktop/Tablet). Die Hero-Aktionen (Scan, Beacon) leben auf dem
/// Home-Tab; app-weit sichtbar bleibt das Banner der eigenen aktiven Session
/// (Standort-Indikator).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _destinations = [
    (icon: Icons.home_outlined, selected: Icons.home, label: 'Home'),
    (
      icon: Icons.dynamic_feed_outlined,
      selected: Icons.dynamic_feed,
      label: 'Feed'
    ),
    (icon: Icons.map_outlined, selected: Icons.map, label: 'Karte'),
    (icon: Icons.search_outlined, selected: Icons.search, label: 'Entdecken'),
    (icon: Icons.person_outline, selected: Icons.person, label: 'Profil'),
  ];

  /// Laufende Session verlängern — gerechnet ab jetzt, nicht ab dem
  /// bisherigen Ende. Die gewählte Dauer wird als Vorgabe für den
  /// nächsten Beacon gemerkt.
  Future<void> _extendSession(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final chosen = await showModalBottomSheet<Duration>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Beacon verlängern',
                  style: Theme.of(sheetContext).textTheme.titleMedium),
              subtitle: const Text('Ab jetzt gerechnet'),
            ),
            for (final d in sessionDurationChoices)
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text('noch ${formatDuration(d)}'),
                onTap: () => Navigator.pop(sheetContext, d),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    ref.read(preferredSessionDurationProvider.notifier).state = chosen;
    final until = await ref.read(actionsProvider).extendMySession(chosen);
    if (until == null) return;
    messenger.showSnackBar(
      SnackBar(content: Text('Beacon läuft noch ${remaining(until)} 🍻')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.sizeOf(context).width >= 800;
    final mySession = ref.watch(myActiveSessionProvider).valueOrNull;
    // Hält den automatischen Konto-Abgleich am Leben: offline entstandene
    // Check-ins werden nachgereicht, sobald Verbindung und Konto da sind.
    ref.watch(checkinAutoSyncProvider);
    // Ebenso den Gasthaus-Cache (gemeinsame Venue-DB aus Supabase)…
    ref.watch(venueSyncProvider);
    // …und die Warteschlange gelöschter Check-ins.
    ref.watch(checkinDeleteSyncProvider);
    // …und den Cloud-Restore (Check-ins/Erfolge/Wunschliste nach
    // Neuinstallation oder Gerätewechsel zurückholen).
    ref.watch(cloudRestoreProvider);

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
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => _extendSession(context, ref),
                      child: const Text('Verlängern'),
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.read(actionsProvider).endMySession(),
                      child: const Text('Beenden'),
                    ),
                  ],
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
