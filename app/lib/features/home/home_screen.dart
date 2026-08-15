import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../widgets/badge_celebration.dart';
import '../../widgets/checkin_card.dart';
import '../../widgets/session_card.dart';
import '../../widgets/update_dialog.dart';
import '../../widgets/beacon_messages.dart';

/// Startbildschirm: die zwei Hero-Aktionen der App —
/// „🍺 Bier scannen" und „🍻 Zusammenkommen!" — plus ein kompakter
/// Blick auf aktive Sessions und die letzte Aktivität.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mySession = ref.watch(myActiveSessionProvider).valueOrNull;
    final sessions = ref.watch(activeSessionsProvider).valueOrNull ??
        const <SessionDetails>[];
    final feed =
        ref.watch(feedProvider).valueOrNull ?? const <CheckinDetails>[];
    // Persönliche Begrüßung, sobald das Online-Profil da ist —
    // offline/abgemeldet bleibt es beim App-Namen.
    final profile = ref.watch(myRemoteProfileProvider).valueOrNull;
    final title = profile == null
        ? 'BrewMates'
        : 'Servus, ${profile.displayName}! ${profile.avatarEmoji}';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
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
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () => context.push('/checkin'),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Ohne Scannen einchecken'),
            ),
          ),

          // ------------------------------------------------------------------
          // Schnellaktionen (Wettbewerbsanalyse): One-Tap-Check-in in unter
          // zwei Sekunden + „Bierlaune" signalisieren, ohne zu trinken.
          // ------------------------------------------------------------------
          ...() {
            final diary =
                ref.watch(myDiaryProvider).valueOrNull ?? const <CheckinDetails>[];
            final signedIn = ref.watch(onlineUserProvider).valueOrNull != null;
            // Eigene Bierlaune kommt seit 0024 über my_thirsty_until()
            // statt aus der Profilzeile (Spaltenrecht entzogen).
            final bierlauneBis = ref.watch(myThirstyUntilProvider).valueOrNull;
            final bierlaune =
                bierlauneBis != null && bierlauneBis.isAfter(DateTime.now());
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
                            ? '🍺 Bierlaune bis '
                                '${bierlauneBis.hour}:${bierlauneBis.minute.toString().padLeft(2, '0')}'
                            : '🍺 Bierlaune!'),
                        selected: bierlaune,
                        onSelected: (on) async {
                          final messenger = ScaffoldMessenger.of(context);
                          final ok = await ref
                              .read(actionsProvider)
                              .setBierlaune(on: on);
                          if (!ok) {
                            messenger.showSnackBar(const SnackBar(
                              content: Text('Bierlaune konnte nicht '
                                  'gespeichert werden — keine Verbindung? '
                                  'Deine Freunde sehen sie nicht.'),
                            ));
                          }
                        },
                      ),
                  ],
                ),
              ),
            ];
          }(),

          // Freunde mit Bierlaune — der sanfte Anstoß zum Zusammenkommen.
          ...() {
            final thirsty =
                ref.watch(thirstyFriendsProvider).valueOrNull ?? const [];
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
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final synced =
                      await ref.read(actionsProvider).endMySession();
                  if (synced == false) {
                    messenger.showSnackBar(beaconEndFailedSnackBar);
                  }
                },
                child: const Text('Beenden'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
