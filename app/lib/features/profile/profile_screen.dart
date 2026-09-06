import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/database.dart';
import '../../core/config.dart';
import '../../data/providers.dart';
import '../../domain/account_level.dart';
import '../../domain/badges.dart';
import '../../domain/streak.dart';
import '../../domain/wochen_verlauf.dart';
import '../../widgets/badge_celebration.dart';
import '../../widgets/wochen_heatmap.dart';
import 'widgets/schnellzugriff.dart';
import 'widgets/zahlen_kachel.dart';

const List<String> _avatarEmojis = [
  '🍺',
  '🍻',
  '🥨',
  '🧔',
  '👩',
  '🍀',
  '🔥',
  '🌊',
  '🦊',
  '🐻',
];

/// Profil: Kopf, Schnellzugriff, Zahlen, Jahr, Abzeichen, Stufe, Mehr.
///
/// **Die Reihenfolge ist die Aussage dieses Bildschirms** (Funktion 47).
/// Bis 0.10.30 stand oben, was gut aussah — neun Zahlen ohne Funktion —
/// und unten in einer Reihe gleichförmiger Listeneinträge das, wofür man
/// den Reiter öffnet: Freunde, Tagebuch, Statistik, Challenges. Jetzt
/// führen vier Kacheln direkt unter dem Kopf dorthin, und die Zahlen
/// darunter erzählen beim Antippen, woraus sie bestehen.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  /// Erklär-Dialog: Punktformel und was jede Stufe darf.
  Future<void> _showLevelInfo(BuildContext context, int level) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: const Text('Vertrauensstufen'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Punkte sammelst du durch Datenpflege:\n'
                  '• 1 Punkt pro Check-in\n'
                  '• 5 Punkte pro angelegtem Bier oder Gasthaus\n'
                  '• 2 Punkte pro gepflegter Änderung',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                for (final l in [1, 2, 3, 4, 5]) ...[
                  Text(
                    '${levelEmoji(l)} ${levelName(l)}'
                    '${l == 2 ? ' (ab $stammgastPoints P.)' : ''}'
                    '${l == 3 ? ' (ab $bierkennerPoints P.)' : ''}'
                    '${l == level ? '  ← du' : ''}',
                    style: theme.textTheme.titleSmall,
                  ),
                  for (final perk in levelPerks(l))
                    Text('   • $perk', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Alles klar 🍻'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditDialog(
      BuildContext context, WidgetRef ref, Profile me) async {
    final nameController = TextEditingController(text: me.displayName);
    final bioController = TextEditingController(text: me.bio ?? '');
    var selectedEmoji = me.avatarEmoji;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Profil bearbeiten'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bioController,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final emoji in _avatarEmojis)
                      ChoiceChip(
                        label: Text(emoji),
                        selected: selectedEmoji == emoji,
                        onSelected: (_) =>
                            setState(() => selectedEmoji = emoji),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final ok = await ref.read(actionsProvider).updateProfile(
                      displayName: nameController.text.trim(),
                      avatarEmoji: selectedEmoji,
                      bio: bioController.text.trim(),
                    );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                messenger.showSnackBar(SnackBar(
                  content: Text(ok
                      ? 'Profil gespeichert ✓'
                      : 'Gespeichert – aber der Server hat es nicht '
                          'übernommen (keine Verbindung?). Freunde sehen '
                          'noch den alten Namen.'),
                ));
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    bioController.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final me = ref.watch(meProvider).valueOrNull;
    final stats = ref.watch(profileStatsProvider).valueOrNull;
    final badgeProgress = ref.watch(badgeProgressProvider).valueOrNull;
    final wishlistCount = ref.watch(wishlistProvider).valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ------------------------------------------------------------------
          // Kopf
          // ------------------------------------------------------------------
          if (me == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Row(
              children: [
                CircleAvatar(
                  radius: 44,
                  child: Text(me.avatarEmoji,
                      style: const TextStyle(fontSize: 40)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(me.displayName,
                          style: theme.textTheme.headlineSmall),
                      Text(
                        '@${me.username}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      if ((me.bio ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(me.bio!, style: theme.textTheme.bodyMedium),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async => _showEditDialog(context, ref, me),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Profil bearbeiten',
                ),
              ],
            ),
          const SizedBox(height: 16),

          // ------------------------------------------------------------------
          // Schnellzugriff — die vier Wege, für die man herkommt (F. 47)
          // ------------------------------------------------------------------
          const Schnellzugriff(),
          const SizedBox(height: 20),

          // ------------------------------------------------------------------
          // Deine Zahlen — jede Kachel erklärt sich beim Antippen (F. 47)
          // ------------------------------------------------------------------
          // Einmal geholt, zweimal gebraucht: für die Serie und für das
          // Bild darunter. Zwei `watch` auf denselben Provider wären
          // kein Fehler, aber eine Einladung, sie auseinanderlaufen zu
          // lassen.
          ...() {
            final termine = [
              for (final d in ref.watch(myDiaryProvider).valueOrNull ??
                  const <CheckinDetails>[])
                d.checkin.createdAt,
            ];
            final jetzt = DateTime.now();
            return [
              Text('Deine Zahlen', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount:
                    MediaQuery.sizeOf(context).width >= 800 ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.9,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  for (final k in _zahlenKacheln(stats, termine, jetzt))
                    ZahlenKachel(
                      label: k.label,
                      value: k.value,
                      info: k.info,
                    ),
                ],
              ),

              // Dasselbe Jahr, das die Serie zusammenfasst — als Fläche
              // (#166). Die Zahl sagt, wie es gerade läuft; das Bild
              // sagt, wie das Jahr war.
              if (termine.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Dein Jahr', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                WochenHeatmap(wochen: wochenVerlauf(termine, jetzt)),
              ],
            ];
          }(),
          const SizedBox(height: 16),

          // ------------------------------------------------------------------
          // Vertrauensstufe (Datenpflege-Levelsystem; nur angemeldet)
          // ------------------------------------------------------------------
          ...() {
            final info = ref.watch(accountLevelProvider).valueOrNull;
            if (info == null) return const <Widget>[];
            // Wartende Level-Up-Feier zeigen (einmalig).
            final pendingLevelUp = ref.watch(levelUpProvider);
            if (pendingLevelUp != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final item = ref.read(levelUpProvider);
                if (item == null) return;
                ref.read(levelUpProvider.notifier).state = null;
                showCelebration(context, [item]);
              });
            }
            final hint = nextLevelHint(
                AccountLevelInfo(level: info.level, points: info.points));
            return [
              Card(
                child: ListTile(
                  leading: Text(levelEmoji(info.level),
                      style: const TextStyle(fontSize: 24)),
                  title: Text(
                      'Vertrauensstufe: ${levelName(info.level)} · '
                      '${info.points} Punkte'),
                  subtitle: hint == null ? null : Text(hint),
                  trailing: const Icon(Icons.info_outline),
                  onTap: () async => _showLevelInfo(context, info.level),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading:
                      const Text('🏅', style: TextStyle(fontSize: 24)),
                  title: const Text('Datenpflege-Bestenliste'),
                  subtitle: const Text('Wer pflegt die Community-DB am '
                      'fleißigsten?'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/profile/leaderboard'),
                ),
              ),
              const SizedBox(height: 8),
            ];
          }(),

          // ------------------------------------------------------------------
          // Challenges-Einstieg
          // ------------------------------------------------------------------
          Card(
            child: ListTile(
              leading: const Text('🏆', style: TextStyle(fontSize: 24)),
              title: const Text('Challenges'),
              subtitle:
                  const Text('Herausforderungen mit Belohnungs-Abzeichen'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/profile/challenges'),
            ),
          ),
          const SizedBox(height: 8),

          // ------------------------------------------------------------------
          // Abzeichen-Vorschau
          // ------------------------------------------------------------------
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push('/profile/badges'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Abzeichen',
                              style: theme.textTheme.titleMedium),
                        ),
                        TextButton(
                          onPressed: () => context.push('/profile/badges'),
                          child: const Text('Alle ansehen'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _BadgePreviewRow(
                      earned: [
                        for (final p in badgeProgress ?? <BadgeProgress>[])
                          if (p.earned) p.def,
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ------------------------------------------------------------------
          // Mehr — was selten gebraucht wird, steht beieinander am Ende
          // ------------------------------------------------------------------
          // Freunde, Tagebuch, Statistik und Challenges standen bis
          // 0.10.30 hier unten in derselben Reihe. Sie sind jetzt im
          // Schnellzugriff oben; was bleibt, öffnet man selten.
          Text('Mehr', style: theme.textTheme.titleSmall),
          Builder(builder: (context) {
            final profile = ref.watch(isSignedInProvider)
                ? ref.watch(myRemoteProfileProvider).valueOrNull
                : null;
            return ListTile(
              leading: const Text('🔐', style: TextStyle(fontSize: 24)),
              title: const Text('Konto'),
              subtitle: Text(profile != null
                  ? '@${profile.username} · online'
                  : 'Anmelden für echte Freunde (Beta)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/account'),
            );
          }),
          ListTile(
            leading: const Text('⭐', style: TextStyle(fontSize: 24)),
            title: const Text('Wunschliste'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (wishlistCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$wishlistCount',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: scheme.onPrimaryContainer),
                    ),
                  ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => context.push('/profile/wishlist'),
          ),
          ListTile(
            leading: const Text('🎁', style: TextStyle(fontSize: 24)),
            title: const Text('Dein Bierjahr'),
            subtitle: const Text('Rückblick auf einer Seite, zum Weitergeben'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/profile/rueckblick'),
          ),
          const SizedBox(height: 16),

          // ------------------------------------------------------------------
          // Über
          // ------------------------------------------------------------------
          Text('Über', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'BrewMates ${AppConfig.appVersion}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          Text(
            // Vorher stand hier „Alle Daten bleiben lokal" — falsch, seit
            // Check-ins, Fotos, Erfolge und Wunschliste zum Konto
            // synchronisiert werden. Eine falsche Datenschutz-Aussage ist
            // ein Vertrauensbruch, sobald sie auffällt.
            '🔒 Ohne Konto bleibt alles auf deinem Gerät. Mit Konto sehen '
            'nur bestätigte Freunde deine Check-ins – nie Fremde.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          Text(
            'Karte: © OpenStreetMap',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Eine Zahl auf dem Profil, mit allem, was ihr Blatt braucht.
typedef _Zahl = ({String label, int? value, ZahlenKachelInfo info});

/// Der Katalog der neun Zahlen (Funktion 47).
///
/// **Warum das eine Liste ist und keine neun Widgets:** Dieselbe
/// Überlegung wie bei `domain/statistics/dimensions.dart` — eine zehnte
/// Zahl ist ein Eintrag hier, kein Eingriff in den Bildschirm. Und die
/// Erklärungen stehen beieinander, wo man sie miteinander vergleichen
/// kann, statt verstreut zwischen Layoutcode.
///
/// Vier der neun haben keine Aufteilung, aus der sich Balken bilden
/// ließen. Sie bekommen trotzdem ein Blatt: Was die Zahl bedeutet, ist
/// auch eine Auskunft — und ein Raster, in dem manche Kacheln reagieren
/// und manche nicht, sieht aus wie ein Fehler.
List<_Zahl> _zahlenKacheln(
  ProfileStats? stats,
  List<DateTime> termine,
  DateTime jetzt,
) =>
    [
      (
        label: 'Biere',
        value: stats?.uniqueBeers,
        info: const ZahlenKachelInfo(
          titel: 'Deine Biere',
          erklaerung: 'So viele verschiedene Biere stehen in deinem '
              'Tagebuch. Zweimal dasselbe zählt einmal.',
          dimension: 'beer',
          ziel: '/profile/diary',
          zielName: 'Zum Tagebuch',
        ),
      ),
      (
        label: 'Stile',
        value: stats?.uniqueStyles,
        info: const ZahlenKachelInfo(
          titel: 'Deine Bierstile',
          erklaerung: 'Wie breit du unterwegs bist — von Märzen bis '
              'Gose.',
          dimension: 'style',
          ziel: '/profile/stats',
          zielName: 'Zur vollen Statistik',
        ),
      ),
      (
        label: 'Brauereien',
        value: stats?.uniqueBreweries,
        info: const ZahlenKachelInfo(
          titel: 'Deine Brauereien',
          erklaerung: 'Von wie vielen Betrieben du schon etwas '
              'getrunken hast.',
          dimension: 'brewery',
          ziel: '/profile/stats',
          zielName: 'Zur vollen Statistik',
        ),
      ),
      (
        label: 'Länder',
        value: stats?.uniqueCountries,
        info: const ZahlenKachelInfo(
          titel: 'Deine Länder',
          erklaerung: 'Nach dem Sitz der Brauerei, nicht nach dem Ort, '
              'an dem du das Bier getrunken hast.',
          dimension: 'country',
          ziel: '/profile/stats',
          zielName: 'Zur vollen Statistik',
        ),
      ),
      (
        label: 'Venues',
        value: stats?.uniqueVenues,
        info: const ZahlenKachelInfo(
          titel: 'Deine Orte',
          erklaerung: 'Gasthäuser und Lokale, die du bei einem Check-in '
              'angegeben hast. Ohne Ortsangabe zählt ein Check-in hier '
              'nicht mit — er ist deshalb nicht verloren.',
          dimension: 'venue',
        ),
      ),
      (
        label: 'Check-ins',
        value: stats?.totalCheckins,
        info: const ZahlenKachelInfo(
          titel: 'Deine Check-ins',
          erklaerung: 'Jeder Eintrag zählt, auch wenn es dasselbe Bier '
              'zum zehnten Mal war. Hier nach Wochentagen.',
          dimension: 'weekday',
          ziel: '/profile/diary',
          zielName: 'Zum Tagebuch',
        ),
      ),
      (
        label: 'Sessions',
        value: stats?.totalSessions,
        info: const ZahlenKachelInfo(
          titel: 'Deine Runden',
          erklaerung: 'Wie oft du bei einer gemeinsamen Runde dabei '
              'warst — als Gastgeber oder als Gast.',
        ),
      ),
      (
        label: 'Abzeichen',
        value: stats?.badgeCount,
        info: const ZahlenKachelInfo(
          titel: 'Deine Abzeichen',
          erklaerung: 'Verdient aus 55 möglichen, in vier Rängen.',
          ziel: '/profile/badges',
          zielName: 'Alle Abzeichen ansehen',
        ),
      ),
      (
        // 🔥 Wochen-Serie „mit Augenmaß": Wochen, nicht Tage — ein
        // Kalender mit 365 Feldern wäre ein täglicher Trinkanreiz.
        label: '🔥 Wochen-Serie',
        value: weeklyStreak(termine, jetzt),
        info: const ZahlenKachelInfo(
          titel: 'Deine Wochen-Serie',
          erklaerung: 'So viele Wochen in Folge hast du mindestens '
              'einen Check-in gemacht. Absichtlich Wochen und nicht '
              'Tage — eine Tagesserie wäre ein täglicher Anreiz zu '
              'trinken.',
        ),
      ),
    ];

class _BadgePreviewRow extends StatelessWidget {
  const _BadgePreviewRow({required this.earned});

  final List<BadgeDef> earned;

  static const int _maxShown = 8;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (earned.isEmpty) {
      return Text(
        'Noch keine Abzeichen – dein erster Check-in wartet!',
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: scheme.onSurfaceVariant),
      );
    }

    final shown = earned.take(_maxShown).toList();
    final overflow = earned.length - shown.length;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final badge in shown)
          CircleAvatar(
            radius: 18,
            backgroundColor: scheme.primaryContainer,
            child: Text(badge.emoji, style: const TextStyle(fontSize: 18)),
          ),
        if (overflow > 0)
          CircleAvatar(
            radius: 18,
            backgroundColor: scheme.surfaceContainerHighest,
            child: Text(
              '+$overflow',
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}
