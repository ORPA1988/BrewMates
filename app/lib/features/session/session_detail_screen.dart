import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/badges.dart' show BadgeDef;
import '../../core/format.dart';
import '../../data/db/database.dart';
import '../../data/online/online_service.dart'
    show RemoteParticipant, Teilnahme;
import '../../data/providers.dart';
import '../../widgets/badge_celebration.dart';
import '../../widgets/checkin_card.dart';
import '../../widgets/beacon_messages.dart';

/// „Der Abend": Live-Ansicht einer Session; beendete Sessions werden zum
/// Erinnerungs-Album (gleicher Screen, nur ohne Aktions-Buttons).
class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  Future<void> _endSession(BuildContext context, WidgetRef ref) async {
    // Erst die Meldung samt „Rückgängig", dann zurück: Die Snackbar hängt
    // am Messenger der Hülle und überlebt das Schließen dieser Seite.
    await beaconBeendenMitRueckgaengig(context, ref);
    if (!context.mounted) return;
    context.pop();
  }

  Future<void> _toast(BuildContext context, WidgetRef ref) async {
    final ok = await ref.read(actionsProvider).toastSession(sessionId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(ok ? toastSentSnackBar : reactionNotSentSnackBar);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Uhr mitbeobachten, damit Restzeit und Aktiv-Status frisch bleiben.
    ref.watch(clockProvider);
    final details = ref.watch(sessionProvider(sessionId));

    return details.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Fehler: $e')),
      ),
      data: (d) {
        if (d == null) {
          // Nicht „nicht gefunden“: Der Server unterscheidet bewusst nicht
          // zwischen „vorbei“ und „nicht für dich“ (RLS aus 0024) — sonst
          // wäre aus einer Fehlermeldung ablesbar, wer wo unterwegs ist.
          // Der Satz muss deshalb beides zugleich abdecken, und er darf
          // nicht so klingen, als sei die App kaputt.
          return Scaffold(
            appBar: AppBar(),
            body: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('📡', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(
                    'Dieser Beacon ist nicht mehr zu sehen.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Beacons enden nach höchstens drei Stunden. Danach zeigt '
                    'niemand mehr, wo er war — auch dir nicht.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          );
        }
        final active = d.isActiveAt(DateTime.now());
        return Scaffold(
          appBar: AppBar(title: Text(d.session.venueName ?? 'Session')),
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              _HeaderCard(details: d, active: active),
              if (active && !d.host.isMe) _Zusagekarte(details: d),
              _ParticipantsRow(details: d),
              if (active) _ActionRow(details: d, screen: this),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text('Der Abend',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              ..._timeline(context, ref),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _timeline(BuildContext context, WidgetRef ref) {
    final checkins = ref.watch(sessionCheckinsProvider(sessionId));
    return checkins.when(
      loading: () => const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (e, _) => [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Fehler: $e'),
        ),
      ],
      data: (list) {
        if (list.isEmpty) {
          return [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Noch keine Check-ins in dieser Session.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ];
        }
        return [
          for (final c in list) CheckinCard(details: c, showAuthor: true),
        ];
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.details, required this.active});

  final SessionDetails details;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = details.session;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(details.host.avatarEmoji,
                    style: const TextStyle(fontSize: 40)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(details.host.displayName,
                          style: theme.textTheme.titleMedium),
                      Text('📍 ${session.venueName ?? 'unterwegs'}',
                          style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                Chip(
                  label: Text(active
                      ? '🟢 noch ${remaining(session.expiresAt)}'
                      : 'Beendet'),
                ),
              ],
            ),
            if (session.message != null) ...[
              const SizedBox(height: 8),
              Text(
                session.message!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Gestartet ${timeAgo(session.startedAt)}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticipantsRow extends ConsumerWidget {
  const _ParticipantsRow({required this.details});

  final SessionDetails details;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Die Antworten kommen vom Server — und zwar bei **jeder** Session,
    // nicht nur der eigenen. Bis 0.10.13 wurden sie nur für die eigene
    // geholt; wer den Beacon eines Freundes öffnete, sah deshalb nie, wer
    // sonst noch kommt. Genau das ist aber die Frage, wegen der man
    // draufklickt. Sehen darf sie ohnehin nur, wer die Session sehen darf
    // — dafür sorgt `session_participants_select` (0001).
    final remote =
        ref.watch(remoteParticipantsProvider(details.session.id)).valueOrNull ??
            const <RemoteParticipant>[];
    final lokalIds = {for (final p in details.participants) p.id};
    final people = [details.host, ...details.participants];
    final dabei = [
      for (final r in remote)
        if (r.art == Teilnahme.dabei && !lokalIds.contains(r.profile.id)) r,
    ];
    final abgesagt = [
      for (final r in remote)
        if (r.art == Teilnahme.abgesagt) r,
    ];
    final prosts = [
      for (final r in remote)
        if (r.art == Teilnahme.prost) r,
    ];
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mit dabei', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in people)
                Chip(
                  avatar: Text(p.avatarEmoji),
                  label: Text(p.displayName),
                ),
              for (final r in dabei)
                Chip(
                  avatar: Text(r.profile.avatarEmoji),
                  label: Text(r.profile.displayName),
                ),
            ],
          ),
          // Absagen stehen daneben, nicht versteckt: „drei sind dabei“
          // heißt wenig, solange offen ist, ob die anderen noch überlegen
          // oder längst abgesagt haben. Wer weiß, dass Anna nicht kommt,
          // wartet nicht auf sie.
          if (abgesagt.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Kann heute nicht', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in abgesagt)
                  Chip(
                    avatar: Text(r.profile.avatarEmoji),
                    label: Text(r.profile.displayName),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
              ],
            ),
          ],
          if (prosts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '🍻 Zugeprostet: '
              '${prosts.map((r) => r.profile.displayName).join(', ')}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

/// „Kommst du vorbei?“ — die Frage, wegen der man auf einen Beacon klickt.
///
/// **Warum das eine Karte ist und kein Dialog.** Ein Dialog beim Öffnen
/// verlangt eine Antwort, bevor man weiß, worauf man antwortet: Wo ist er,
/// seit wann, wer ist schon da, wie lange läuft das noch. Die Frage gehört
/// deshalb an den Anfang des Bildschirms, nicht davor.
///
/// **Warum Absagen ein eigener Knopf ist und nicht Wegklicken.** Wer
/// schweigt, sagt nichts — der Gastgeber weiß dann nicht, ob noch jemand
/// kommt, und wartet womöglich. Eine Absage ist eine Information, kein
/// Verzicht auf eine.
///
/// Die eigene Antwort bleibt änderbar: Ein Abend ist keine Buchung.
class _Zusagekarte extends ConsumerStatefulWidget {
  const _Zusagekarte({required this.details});

  final SessionDetails details;

  @override
  ConsumerState<_Zusagekarte> createState() => _ZusagekarteState();
}

class _ZusagekarteState extends ConsumerState<_Zusagekarte> {
  bool _laeuft = false;

  Future<void> _antworten(Teilnahme? art) async {
    setState(() => _laeuft = true);
    final messenger = ScaffoldMessenger.of(context);
    final id = widget.details.session.id;
    final aktionen = ref.read(actionsProvider);
    var verdient = const <BadgeDef>[];
    final bool ok;
    if (art == null) {
      ok = await aktionen.antwortZuruecknehmen(id);
    } else {
      final ergebnis = await aktionen.antwortAufBeacon(id, art);
      ok = ergebnis.synced;
      verdient = ergebnis.earned;
    }
    if (!mounted) return;
    setState(() => _laeuft = false);

    // Regel A-8: Eine Zusage, die den Server nie erreicht hat, lässt
    // jemanden warten. Das ist der eine Fall, in dem stilles Scheitern
    // wirklich Schaden anrichtet.
    messenger.showSnackBar(SnackBar(
      content: Text(!ok
          ? 'Hat nicht geklappt — keine Verbindung? Deine Antwort ist nicht '
              'angekommen.'
          : switch (art) {
              Teilnahme.dabei => 'Zugesagt — sie wissen Bescheid 🍻',
              Teilnahme.abgesagt => 'Abgesagt — sie warten nicht auf dich.',
              _ => 'Antwort zurückgenommen.',
            }),
    ));

    if (verdient.isNotEmpty && mounted) {
      await showBadgeCelebration(context, verdient);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meineId = ref.watch(onlineUserProvider).valueOrNull?.id;
    final teilnehmer =
        ref.watch(remoteParticipantsProvider(widget.details.session.id))
                .valueOrNull ??
            const <RemoteParticipant>[];

    Teilnahme? meineAntwort;
    for (final t in teilnehmer) {
      if (t.profile.id == meineId && t.art != Teilnahme.prost) {
        meineAntwort = t.art;
      }
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      color: meineAntwort == null
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              switch (meineAntwort) {
                Teilnahme.dabei => 'Du kommst vorbei 🍻',
                Teilnahme.abgesagt => 'Du hast abgesagt',
                _ => 'Kommst du vorbei?',
              },
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              meineAntwort == null
                  ? '${widget.details.host.displayName} sieht deine Antwort '
                      'sofort — und alle, die den Beacon auch sehen.'
                  : 'Kannst du jederzeit ändern.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (meineAntwort != null)
                  TextButton(
                    onPressed: _laeuft ? null : () => _antworten(null),
                    child: const Text('Doch nicht'),
                  )
                else
                  TextButton(
                    onPressed: _laeuft
                        ? null
                        : () => _antworten(Teilnahme.abgesagt),
                    child: const Text('Ich hab keine Zeit'),
                  ),
                const SizedBox(width: 4),
                if (meineAntwort != Teilnahme.dabei)
                  FilledButton(
                    onPressed:
                        _laeuft ? null : () => _antworten(Teilnahme.dabei),
                    child: const Text('Ich komme vorbei'),
                  )
                else
                  OutlinedButton(
                    onPressed: _laeuft
                        ? null
                        : () => _antworten(Teilnahme.abgesagt),
                    child: const Text('Ich hab keine Zeit'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends ConsumerWidget {
  const _ActionRow({required this.details, required this.screen});

  final SessionDetails details;
  final SessionDetailScreen screen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMine = details.host.isMe;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: isMine
            ? [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => screen._endSession(context, ref),
                    child: const Text('Session beenden'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => context.push('/checkin'),
                    child: const Text('✅ Bier einchecken'),
                  ),
                ),
              ]
            // Zu- und Absage stehen oben in der Zusagekarte — sie sind die
            // Frage des Abends und gehören nicht in eine Knopfleiste unter
            // die Teilnehmer. Hier bleibt der Prost, der etwas anderes ist:
            // Man kann zuprosten UND absagen.
            : [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => screen._toast(context, ref),
                    child: const Text('Prost! 🍻'),
                  ),
                ),
              ],
      ),
    );
  }
}
