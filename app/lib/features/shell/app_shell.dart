import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/online/online_service.dart' show RemoteNotification;
import '../../data/providers.dart';
import '../../widgets/beacon_messages.dart';
import '../../widgets/glocke.dart';

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
    final result = await ref.read(actionsProvider).extendMySession(chosen);
    if (result == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(result.synced
            ? 'Beacon läuft noch ${remaining(result.until)} 🍻'
            : 'Verlängert bis ${remaining(result.until)} — aber ohne '
                'Verbindung. Deine Freunde sehen noch das alte Ende.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.sizeOf(context).width >= 800;
    final mySession = ref.watch(myActiveSessionProvider).valueOrNull;
    // Hält den automatischen Konto-Abgleich am Leben: offline entstandene
    // Check-ins werden nachgereicht, sobald Verbindung und Konto da sind.
    ref.watch(checkinAutoSyncProvider);
    // Schließt Beacons, die der Server noch als laufend führt, obwohl
    // lokal keiner mehr läuft — die Reparatur für ein Beenden ohne
    // Verbindung. Ohne sie zeigte die Karte den Aufenthaltsort weiter.
    ref.watch(sessionReconcileProvider);
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
                          beaconBeendenMitRueckgaengig(context, ref),
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

    // Offene Freundschaftsanfragen als Zahl am Profil-Tab.
    //
    // Sie standen bisher nur auf der Startseite. Wer die App auf einem
    // anderen Tab offen hatte — oder sie nur kurz oeffnete, um etwas
    // einzuchecken —, sah nie, dass jemand auf eine Antwort wartet.
    // Ein Mensch, der wartet, gehoert an eine Stelle, die man von ueberall
    // sieht.
    final offeneAnfragen = ref.watch(offeneAnfragenProvider).length;

    // Live-Banner: Kommt eine Benachrichtigung an, waehrend die App offen
    // ist, sagt sie es — auf jedem Tab. Der Provider entwertet nebenbei
    // die Listen, sodass Karte und Zahl am Profil-Tab schon stimmen, wenn
    // der Mensch hintippt.
    // Wohin „Ansehen" führt, steht in `widgets/glocke.dart` — dieselbe
    // Zuordnung braucht die Nachlese, und zwei Kopien liefen
    // auseinander, sobald eine dritte Art dazukommt.
    void Function()? zielVon(RemoteNotification n) =>
        benachrichtigungsZiel(context, n);

    void zeigeBanner(String text, void Function()? ziel) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(text),
        action: ziel == null
            ? null
            : SnackBarAction(label: 'Ansehen', onPressed: ziel),
      ));
    }

    final fenster = ref.watch(browserfensterProvider);

    ref.listen<AsyncValue<RemoteNotification>>(incomingNotificationsProvider,
        (_, next) {
      final n = next.valueOrNull;
      if (n == null) return;

      // Liegt die App vorn, reicht das Banner — so war es immer, und
      // außerhalb des Browsers meldet `sichtbar` ohnehin immer true.
      if (fenster.sichtbar) {
        zeigeBanner(n.text, zielVon(n));
        return;
      }

      // Der Tab liegt hinten. Zwei Wege, und der zweite ist der
      // wichtigere: Auf dem iPhone gibt es außerhalb einer installierten
      // Web-App gar keine Systemmeldungen. Ohne das Merken wäre die
      // Meldung dann schlicht weg.
      if (fenster.erlaubnis == 'granted') {
        fenster.zeige(text: n.text, tag: n.type, beiKlick: zielVon(n));
      } else {
        ref.read(verpassteMeldungenProvider.notifier).merken(n);
      }
    });

    // Zurück im Fenster: nachreichen, was währenddessen ankam.
    ref.listen<AsyncValue<bool>>(seiteSichtbarProvider, (_, next) {
      if (next.valueOrNull != true) return;
      final verpasst = ref.read(verpassteMeldungenProvider.notifier).abholen();
      if (verpasst.isEmpty) return;
      zeigeBanner(
        verpasst.length == 1
            ? verpasst.single.text
            : '${verpasst.length} neue Meldungen, während du weg warst',
        // Bei mehreren führt „Ansehen" zur jüngsten — sie ist die, die
        // gerade noch etwas ändert.
        zielVon(verpasst.last),
      );
    });

    Widget symbol(IconData icon) => offeneAnfragen == 0
        ? Icon(icon)
        : Badge.count(count: offeneAnfragen, child: Icon(icon));

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
                    icon: d.label == 'Profil' ? symbol(d.icon) : Icon(d.icon),
                    selectedIcon: d.label == 'Profil'
                        ? symbol(d.selected)
                        : Icon(d.selected),
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
              icon: d.label == 'Profil' ? symbol(d.icon) : Icon(d.icon),
              selectedIcon:
                  d.label == 'Profil' ? symbol(d.selected) : Icon(d.selected),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
