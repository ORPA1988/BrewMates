import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart' show timeAgo;
import '../data/online/online_service.dart' show RemoteNotification;
import '../data/providers.dart';

/// Wohin eine Benachrichtigung führt.
///
/// Liegt hier und nicht in der Hülle, weil zwei Stellen dasselbe Ziel
/// brauchen: das Live-Banner und die Glocke. Zwei Kopien liefen
/// auseinander, sobald eine dritte Art dazukommt.
///
/// `null` heißt: kein sinnvolles Ziel. Dann gibt es auch keinen Knopf —
/// ein „Ansehen", das nirgendwohin führt, ist schlimmer als keins.
void Function()? benachrichtigungsZiel(
  BuildContext context,
  RemoteNotification n,
) =>
    switch (n.type) {
      'friend_request' => () => context.go('/friends'),
      // Die Einladung wird in der Crew-Liste beantwortet, nicht in der
      // Crew selbst — die sieht man ja erst als Mitglied.
      'crew_invite' => () => context.push('/crews'),
      // Alle vier führen zur Session. `subjectId` ist die blanke
      // Server-UUID; dass die Detailansicht damit klarkommt, ist seit
      // 0.10.13 wahr — vorher fragte sie damit die lokale Datenbank und
      // meldete bei fremden Beacons „Session nicht gefunden".
      'beacon' || 'session_toast' || 'session_joined' || 'session_declined'
          when n.subjectId != null =>
        () => context.push('/session/${n.subjectId}'),
      _ => null,
    };

/// 🔔 Die Glocke in der Titelzeile der Startseite.
///
/// **Warum es sie gibt.** `notifications` füllt sich seit 0031, der Push
/// weckt seit 0039 das Gerät, und im Browser meldet sich seit 0.10.11 der
/// Tab — aber wer die Meldung verpasste, fand sie **nirgends** wieder.
/// `unreadNotificationsProvider` holte den Bestand seit jeher und keine
/// einzige Stelle zeigte ihn an. Ein Weckruf ohne Nachlese ist eine
/// halbe Funktion: Man weiß, dass etwas war, und nicht was.
///
/// **Auch Freundschaftsanfragen stehen darin**, obwohl sie schon eine
/// Karte auf der Startseite und eine Zahl am Profil-Tab haben. Die
/// Doppelung ist der kleinere Fehler: Eine Liste, die „nichts verpasst"
/// sagt, obwohl eine Anfrage kam, wäre schlicht falsch. Die Zahl am Tab
/// bleibt der Handlungsaufruf, die Glocke ist das Gedächtnis.
class Glocke extends ConsumerWidget {
  const Glocke({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offen = ref.watch(unreadNotificationsProvider).valueOrNull ??
        const <RemoteNotification>[];
    // Abgemeldet gibt es nichts zu holen — dann auch keine tote Glocke.
    if (!ref.watch(isSignedInProvider)) return const SizedBox.shrink();

    return IconButton(
      tooltip: offen.isEmpty
          ? 'Benachrichtigungen'
          : '${offen.length} neue Benachrichtigungen',
      icon: offen.isEmpty
          ? const Icon(Icons.notifications_none)
          : Badge.count(
              count: offen.length,
              child: const Icon(Icons.notifications),
            ),
      onPressed: () => zeigeGlocke(context),
    );
  }
}

/// Die Nachlese: was angekommen ist, seit man zuletzt hingesehen hat.
Future<void> zeigeGlocke(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _GlockenListe(),
    );

class _GlockenListe extends ConsumerWidget {
  const _GlockenListe();

  Future<void> _alleGelesen(WidgetRef ref, List<RemoteNotification> n) async {
    final online = await ref.read(onlineServiceProvider.future);
    await online?.notifications.markRead(n.map((e) => e.id));
    ref.invalidate(unreadNotificationsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final offen = ref.watch(unreadNotificationsProvider).valueOrNull ??
        const <RemoteNotification>[];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('🔔 Verpasst', style: theme.textTheme.titleMedium),
                ),
                if (offen.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      await _alleGelesen(ref, offen);
                      navigator.pop();
                    },
                    child: const Text('Alle gelesen'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (offen.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Nichts verpasst 🍺',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              )
            else
              // Höhe begrenzt, sonst schiebt eine lange Liste den Griff
              // aus dem Bild.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.6,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: offen.length,
                  itemBuilder: (_, i) {
                    final n = offen[i];
                    final ziel = benachrichtigungsZiel(context, n);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 16,
                        child: Text(n.actor?.avatarEmoji ?? '🔔',
                            style: const TextStyle(fontSize: 16)),
                      ),
                      title: Text(n.text),
                      subtitle: Text(timeAgo(n.createdAt)),
                      // Ohne Ziel kein Pfeil: Er verspräche einen Sprung,
                      // den es nicht gibt.
                      trailing:
                          ziel == null ? null : const Icon(Icons.chevron_right),
                      onTap: () async {
                        final navigator = Navigator.of(context);
                        // Angesehen ist gelesen — aber nur diese eine.
                        final online =
                            await ref.read(onlineServiceProvider.future);
                        await online?.notifications.markRead([n.id]);
                        ref.invalidate(unreadNotificationsProvider);
                        navigator.pop();
                        ziel?.call();
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
