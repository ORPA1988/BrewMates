import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../data/providers.dart';
import '../profile_providers.dart';

/// Die vier Wege, für die man den Profil-Reiter überhaupt öffnet
/// (Funktion 47).
///
/// **Warum sie ganz oben stehen:** Bis 0.10.30 lagen Freunde, Tagebuch
/// und Statistik als gleichförmige Listeneinträge unter neun Zahlen, einer
/// Heatmap, der Vertrauensstufe und der Abzeichen-Vorschau. Wer wegen
/// einer offenen Freundschaftsanfrage kam, scrollte an allem vorbei —
/// und eine Anfrage ist die einzige Stelle der App, an der ein anderer
/// Mensch auf eine Antwort wartet.
///
/// **Warum jede Kachel eine Zweitzeile trägt:** Ein Knopf, der nur seinen
/// Namen sagt, ist ein Menüeintrag. „2 Anfragen offen" oder „zuletzt: vor
/// 3 Tagen" macht daraus eine Auskunft, für die man gar nicht erst
/// tippen muss.
class Schnellzugriff extends ConsumerWidget {
  const Schnellzugriff({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final angemeldet = ref.watch(isSignedInProvider);
    final challenge = ref.watch(laufendeChallengeProvider);
    final letzter = ref.watch(letzterCheckinProvider);
    final checkins =
        ref.watch(profileStatsProvider).valueOrNull?.totalCheckins;

    final freunde =
        angemeldet ? ref.watch(onlineFriendsProvider).valueOrNull?.length : null;
    final anfragen = angemeldet ? ref.watch(offeneAnfragenProvider).length : 0;

    final kacheln = [
      _Kachel(
        emoji: '🏆',
        titel: 'Challenges',
        zeile: challenge?.def.title ?? 'Gerade läuft keine',
        ziel: '/profile/challenges',
      ),
      _Kachel(
        emoji: '👥',
        titel: 'Freunde',
        // Die offene Anfrage verdrängt die Zahl, statt sich dahinter zu
        // stellen: Sie ist das, was zu tun ist.
        zeile: anfragen > 0
            ? (anfragen == 1 ? '1 Anfrage offen' : '$anfragen Anfragen offen')
            : switch (freunde) {
                null => 'Anmelden für echte Freunde',
                0 => 'Noch niemand',
                1 => '1 Freund',
                final n => '$n Freunde',
              },
        hervorgehoben: anfragen > 0,
        ziel: '/friends',
      ),
      _Kachel(
        emoji: '📖',
        titel: 'Tagebuch',
        zeile: letzter == null
            ? 'Noch kein Check-in'
            : 'zuletzt ${timeAgo(letzter)}',
        ziel: '/profile/diary',
      ),
      _Kachel(
        emoji: '📊',
        titel: 'Statistik',
        zeile: checkins == null
            ? 'Menge, Länder, Stile'
            : (checkins == 1 ? '1 Check-in' : '$checkins Check-ins'),
        ziel: '/profile/stats',
      ),
    ];

    // **Zwei Zeilen zu zwei Kacheln, nicht ein Raster.** Ein
    // `GridView.count` braucht ein festes Seitenverhältnis, und jede feste
    // Höhe ist eine Wette auf die Schriftgröße: Bei „2 Anfragen offen" in
    // zwei Zeilen lief die Kachel über. `IntrinsicHeight` dreht das um —
    // die Zeile ist so hoch wie ihre höhere Kachel, und beide wachsen mit
    // dem Text mit.
    //
    // Auch auf breiten Fenstern bleiben es zwei Spalten: Vier Knöpfe
    // nebeneinander sind eine Werkzeugleiste, keine Wegweiser.
    return Column(
      children: [
        for (var i = 0; i < kacheln.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: kacheln[i]),
                const SizedBox(width: 8),
                Expanded(child: kacheln[i + 1]),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Kachel extends StatelessWidget {
  const _Kachel({
    required this.emoji,
    required this.titel,
    required this.zeile,
    required this.ziel,
    this.hervorgehoben = false,
  });

  final String emoji;
  final String titel;
  final String zeile;
  final String ziel;

  /// Färbt die Kachel ein, wenn etwas auf eine Antwort wartet.
  final bool hervorgehoben;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: hervorgehoben ? scheme.primaryContainer : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(ziel),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      titel,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: hervorgehoben ? scheme.onPrimaryContainer : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                zeile,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: hervorgehoben
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
