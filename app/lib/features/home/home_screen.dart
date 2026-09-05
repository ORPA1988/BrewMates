import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/db/database.dart';
import '../../data/online/models.dart' show RemoteSession;
import '../../data/providers.dart';
import '../../widgets/badge_celebration.dart';
import '../../widgets/glocke.dart';
import '../../widgets/checkin_card.dart';
import '../../widgets/session_card.dart';
import '../../widgets/update_dialog.dart';
import '../../widgets/beacon_messages.dart';
import '../../widgets/friend_request_card.dart';

/// Startbildschirm: die zwei Hero-Aktionen der App —
/// „🍺 Bier scannen" und „🍻 Zusammenkommen!" — plus ein kompakter
/// Blick auf aktive Sessions und die letzte Aktivität.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// Bierlaune setzen — mit Laufzeit, ab jetzt gerechnet.
  ///
  /// Meldet ehrlich, wenn der Server sie nicht übernommen hat: Eine
  /// Bierlaune, die niemand sieht, ist keine.
  Future<void> _bierlauneSetzen(
    BuildContext context,
    WidgetRef ref,
    Duration dauer,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    ref.read(preferredBierlauneDurationProvider.notifier).state = dauer;
    final ok = await ref.read(actionsProvider).setBierlaune(fuer: dauer);
    if (!ok) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Bierlaune konnte nicht gespeichert werden — keine '
            'Verbindung? Deine Freunde sehen sie nicht.'),
      ));
    }
  }

  /// Der Zettel zur laufenden Bierlaune: verlängern oder beenden.
  Future<void> _bierlauneZettel(
    BuildContext context,
    WidgetRef ref,
    DateTime bis,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final gewaehlt = await showModalBottomSheet<Duration?>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        // Scrollbar, nicht nur `min`: Auf einem kleinen Gerät — oder quer
        // gehalten — ist die Liste höher als der Platz, und eine Spalte
        // schneidet dann einfach ab.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('🍺 Bierlaune läuft bis ${formatTime(bis)}',
                    style: Theme.of(sheetContext).textTheme.titleMedium),
                subtitle: const Text('Neue Laufzeit ab jetzt gerechnet'),
              ),
              for (final d in bierlauneDauerChoices)
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: Text('noch ${formatDuration(d)}'),
                  onTap: () => Navigator.pop(sheetContext, d),
                ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.close,
                    color: Theme.of(sheetContext).colorScheme.error),
                title: const Text('Bierlaune beenden'),
                // `Duration.zero` steht für „beenden" — `null` bedeutet
                // hier schon „Zettel weggewischt, nichts tun".
                onTap: () => Navigator.pop(sheetContext, Duration.zero),
              ),
            ],
          ),
        ),
      ),
    );
    if (gewaehlt == null) return;
    if (gewaehlt == Duration.zero) {
      final ok = await ref.read(actionsProvider).setBierlaune();
      if (!ok) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Beenden hat nicht geklappt — keine Verbindung? '
              'Deine Freunde sehen die Bierlaune noch.'),
        ));
      }
      return;
    }
    if (!context.mounted) return;
    await _bierlauneSetzen(context, ref, gewaehlt);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mySession = ref.watch(myActiveSessionProvider).valueOrNull;
    final sessions = ref.watch(activeSessionsProvider).valueOrNull ??
        const <SessionDetails>[];
    final feed =
        ref.watch(feedProvider).valueOrNull ?? const <CheckinDetails>[];
    final verabredungen =
        ref.watch(plannedSessionsProvider).valueOrNull ??
            const <RemoteSession>[];
    // Persönliche Begrüßung, sobald das Online-Profil da ist —
    // offline/abgemeldet bleibt es beim App-Namen.
    final profile = ref.watch(myRemoteProfileProvider).valueOrNull;
    final title = profile == null
        ? 'BrewMates'
        : 'Servus, ${profile.displayName}! ${profile.avatarEmoji}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        // Die Nachlese zu allem, was geweckt hat. Ohne sie weiß man nach
        // einem Push, DASS etwas war, aber nicht was.
        actions: const [Glocke()],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ------------------------------------------------------------------
          // Offene Freundschaftsanfragen
          //
          // Sie standen bisher nur im Freunde-Bildschirm — wer nicht
          // hinsah, liess jemanden wochenlang warten. Eine Anfrage ist
          // die einzige Stelle, an der ein anderer Mensch auf eine
          // Antwort wartet; sie gehoert dorthin, wo man ohnehin hinschaut.
          //
          // Sie bleibt stehen, bis geantwortet ist. „Spaeter" gab es bis
          // 0.10.12 und ist weg: Seit das Ablehnen zurueckgenommen werden
          // kann, kostet die Entscheidung nichts mehr — und eine Karte
          // wegzuwischen half nur dem, der sie wegwischt.
          // ------------------------------------------------------------------
          ...() {
            final offen = ref.watch(offeneAnfragenProvider);
            if (offen.isEmpty) return const <Widget>[];
            return [
              for (final a in offen)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: FriendRequestCard(request: a),
                ),
            ];
          }(),
          // ------------------------------------------------------------------
          // Update-Hinweis (automatischer Check gegen GitHub-Releases)
          // ------------------------------------------------------------------
          ...() {
            final update = ref.watch(updateInfoProvider).valueOrNull;
            if (update == null || ref.watch(updateDismissedProvider)) {
              return const <Widget>[];
            }
            return [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Card(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: ListTile(
                    leading: const Text('🔄', style: TextStyle(fontSize: 24)),
                    title: Text('Update ${update.version} verfügbar'),
                    subtitle: const Text('Antippen für Details & Download'),
                    trailing: IconButton(
                      tooltip: 'Später',
                      icon: const Icon(Icons.close),
                      onPressed: () => ref
                          .read(updateDismissedProvider.notifier)
                          .state = true,
                    ),
                    onTap: () async => showUpdateDialog(context, update),
                  ),
                ),
              ),
            ];
          }(),

          // ------------------------------------------------------------------
          // Hero-Aktionen
          // ------------------------------------------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _HeroCard(
              emoji: '🍺',
              title: 'Bier scannen',
              subtitle:
                  'Barcode scannen, bewerten, ins Tagebuch – in Sekunden.',
              onTap: () => context.push('/scan'),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: mySession == null
                ? _HeroCard(
                    emoji: '🍻',
                    title: 'Zusammenkommen!',
                    subtitle:
                        'Ein Tap: Freunde sehen, wo du bist – alle willkommen.',
                    onTap: () => context.push('/beacon'),
                  )
                : _ActiveBeaconCard(session: mySession),
          ),
          // Testphase: drei kleine Knöpfe direkt unter „Zusammenkommen".
          // Ein Fehler im Wirtshaus soll mit zwei Tipps gemeldet sein;
          // die Roadmap zeigt in Alltagssprache, was daraus wird. Der
          // Schalter liegt in app_config — abschaltbar ohne Release.
          if (ref.watch(feedbackEnabledProvider).valueOrNull ?? false)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/feedback?art=bug'),
                      icon: const Icon(Icons.bug_report_outlined, size: 18),
                      label: const Text('Fehler'),
                      style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/feedback?art=wish'),
                      icon: const Icon(Icons.lightbulb_outline, size: 18),
                      label: const Text('Wunsch'),
                      style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/roadmap'),
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Roadmap'),
                      style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          // Der Weg für Bier ohne Barcode — vom Fass, im Glas serviert.
          // Er stand als kleiner Textknopf zwischen zwei großen Karten
          // und wurde übersehen (Wunsch #139): Gerade im Wirtshaus, wo
          // am häufigsten eingecheckt wird, gibt es nichts zu scannen.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => context.push('/checkin'),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Ohne Barcode einchecken'),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
          ),

          // ------------------------------------------------------------------
          // Schnellaktionen (Wettbewerbsanalyse): One-Tap-Check-in in unter
          // zwei Sekunden + „Bierlaune" signalisieren, ohne zu trinken.
          // ------------------------------------------------------------------
          ...() {
            final diary = ref.watch(myDiaryProvider).valueOrNull ??
                const <CheckinDetails>[];
            final signedIn = ref.watch(onlineUserProvider).valueOrNull != null;
            // Eigene Bierlaune kommt seit 0024 über my_thirsty_until()
            // statt aus der Profilzeile (Spaltenrecht entzogen).
            final bierlauneBis = ref.watch(myThirstyUntilProvider).valueOrNull;
            // Ob sie noch gilt, entscheidet der 30-Sekunden-Takt und nicht
            // der Zeitpunkt des letzten Abrufs — sonst steht hier
            // „Bierlaune bis 20:02", wenn es längst 20:03 ist.
            final bierlaune = ref.watch(bierlauneAktivProvider);
            if (diary.isEmpty && !signedIn) return const <Widget>[];
            return [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    if (diary.isNotEmpty)
                      ActionChip(
                        avatar: const Text('⚡'),
                        label: Text(
                          'Nochmal: ${diary.first.beer.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () async {
                          final result = await ref
                              .read(actionsProvider)
                              .repeatLastCheckin();
                          if (!context.mounted || result == null) return;
                          final (name, earned) = result;
                          if (earned.isNotEmpty) {
                            await showCelebration(context, earned);
                            if (!context.mounted) return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Eingecheckt: $name 🍺 — Details '
                                  'kannst du im Tagebuch ergänzen.')));
                        },
                      ),
                    if (signedIn)
                      FilterChip(
                        label: Text(bierlaune
                            ? '🍺 Bierlaune bis ${formatTime(bierlauneBis!)}'
                            : '🍺 Bierlaune!'),
                        selected: bierlaune,
                        // Aus heißt: ein Tipp, fertig — mit der zuletzt
                        // gewählten Laufzeit. An heißt: der Zettel, auf
                        // dem man sie ändert oder beendet.
                        //
                        // Damit ist die Zeit einstellbar, ohne dass das
                        // Signalisieren einen Schritt mehr kostet. Und
                        // das versehentliche Beenden ist weg: Ein Tipp
                        // auf den aktiven Chip löschte die Bierlaune
                        // vorher sofort und ersatzlos.
                        onSelected: (_) => bierlaune
                            ? _bierlauneZettel(context, ref, bierlauneBis!)
                            : _bierlauneSetzen(
                                context,
                                ref,
                                ref.read(preferredBierlauneDurationProvider),
                              ),
                      ),
                  ],
                ),
              ),
            ];
          }(),

          // Freunde mit Bierlaune — der sanfte Anstoß zum Zusammenkommen.
          ...() {
            final thirsty = ref.watch(thirstyFriendsProvider);
            if (thirsty.isEmpty) return const <Widget>[];
            return [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Card(
                  color: theme.colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('🍺 Bierlaune bei deinen Freunden',
                            style: theme.textTheme.titleSmall),
                        const SizedBox(height: 4),
                        for (final f in thirsty)
                          Text('${f.avatarEmoji} ${f.displayName} hätte '
                              'jetzt Lust auf ein Bier'),
                      ],
                    ),
                  ),
                ),
              ),
            ];
          }(),

          // ------------------------------------------------------------------
          // Aktive Challenge (kompakt; Tap → alle Challenges)
          // ------------------------------------------------------------------
          ...() {
            final challenges =
                ref.watch(challengeProgressProvider).valueOrNull ?? const [];
            final open = [
              for (final c in challenges)
                if (!c.completed && c.def.isActiveAt(DateTime.now())) c,
            ];
            if (open.isEmpty) return const <Widget>[];
            final item = open.first;
            return [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push('/profile/challenges'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Text(item.def.emoji,
                              style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Challenge: ${item.def.title}',
                                    style: theme.textTheme.titleSmall),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                      value: item.fraction, minHeight: 6),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('${item.progress}/${item.def.target}',
                              style: theme.textTheme.labelLarge),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ];
          }(),

          // ------------------------------------------------------------------
          // Gerade unterwegs
          // ------------------------------------------------------------------
          if (sessions.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('Gerade unterwegs 🍻',
                  style: theme.textTheme.titleMedium),
            ),
            SizedBox(
              height: 150,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (final s in sessions) SessionCard(details: s),
                ],
              ),
            ),
          ],

          // ------------------------------------------------------------------
          // Demnächst
          //
          // Unter „Gerade unterwegs“, nicht darüber: Was jetzt läuft, ist
          // dringender als was am Freitag ansteht. Und auf der Karte
          // taucht hier nichts auf — eine Verabredung hat keinen Ort, an
          // dem jemand ist (docs/features/39).
          // ------------------------------------------------------------------
          if (verabredungen.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('Demnächst 📅',
                  style: theme.textTheme.titleMedium),
            ),
            for (final v in verabredungen) _Verabredung(session: v),
          ],

          // ------------------------------------------------------------------
          // Letzte Aktivität
          // ------------------------------------------------------------------
          if (feed.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Letzte Aktivität',
                        style: theme.textTheme.titleMedium),
                  ),
                  TextButton(
                    onPressed: () => context.go('/feed'),
                    child: const Text('Mehr im Feed'),
                  ),
                ],
              ),
            ),
            for (final details in feed.take(3)) CheckinCard(details: details),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 44)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ersetzt die Beacon-Hero-Karte, solange die eigene Session läuft.
class _ActiveBeaconCard extends ConsumerWidget {
  const _ActiveBeaconCard({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.tertiaryContainer,
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/session/${session.id}'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Text('📡', style: TextStyle(fontSize: 44)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dein Beacon läuft',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${session.venueName ?? 'Unterwegs'} · '
                      'endet in ${remaining(session.expiresAt)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => beaconBeendenMitRueckgaengig(context, ref),
                child: const Text('Beenden'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Eine Verabredung in „Demnächst“.
///
/// Bewusst schlichter als eine [SessionCard]: Dort steht, wer **jetzt**
/// wo ist — hier nur, dass etwas ansteht. Kein Ortspunkt, keine
/// Restlaufzeit, kein „ist unterwegs“.
class _Verabredung extends StatelessWidget {
  const _Verabredung({required this.session});

  final RemoteSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final termin = session.scheduledFor!;
    final wo = session.venueName;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Text(session.host.avatarEmoji,
            style: const TextStyle(fontSize: 26)),
        title: Text(wo == null
            ? session.host.displayName
            : '${session.host.displayName} · $wo'),
        subtitle: Text(
          '${formatDate(termin)}, ${formatTime(termin)} Uhr'
          '${session.message == null ? '' : '\n${session.message}'}',
          style: theme.textTheme.bodySmall,
        ),
        isThreeLine: session.message != null,
        onTap: () => context.push('/session/${session.id}'),
      ),
    );
  }
}
