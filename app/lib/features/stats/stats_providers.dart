import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/checkin_facts.dart';
import '../../data/checkin_facts_mapping.dart';
import '../../data/providers.dart';
import '../../domain/statistics.dart';

/// Provider dieser Funktion — eigene Datei statt Anbau an die
/// Sammelstelle `data/providers.dart` (siehe docs/11).

/// Gewählter Zeitraum: einer der drei Vorgaben oder ein freier von–bis.
final statsPeriodProvider = StateProvider<StatsPeriod>(
  (ref) => const StatsPeriod.preset(StatsRange.year),
);

/// Gewählte Aufteilung — der Schlüssel aus `domain/statistics/dimensions.dart`.
///
/// Es wird **eine zur Zeit** gezeigt, per Chip gewählt. Vier
/// untereinander gingen noch; bei acht wäre der Bildschirm eine Rolle,
/// durch die niemand mehr scrollt.
final statsDimensionProvider =
    StateProvider<String>((ref) => dimensions.first.key);

/// Filter: Land der Brauerei (null = alle).
final statsCountryProvider = StateProvider<String?>((ref) => null);

/// Filter: Bierstil (null = alle).
final statsStyleProvider = StateProvider<String?>((ref) => null);

// Die Quelle — alle eigenen Check-ins ohne Fenster — steht seit 0.10.31
// in `data/providers/feed.dart` als `alleEigenenCheckinsProvider`. Sie
// stand hier, bis die Profil-Übersicht (Funktion 47) sie ebenfalls
// brauchte: Ein Feature, das den Provider eines anderen importiert, wäre
// genau der Cross-Import, den docs/11 ausschließt.

/// Die fertige Auswertung nach Zeitraum und Filtern.
final statsProvider = Provider<CheckinStats>((ref) {
  final all = ref.watch(alleEigenenCheckinsProvider).valueOrNull ?? const [];
  return computeStats(
    all.facts,
    now: ref.watch(clockProvider).valueOrNull ?? DateTime.now(),
    period: ref.watch(statsPeriodProvider),
    country: ref.watch(statsCountryProvider),
    style: ref.watch(statsStyleProvider),
  );
});

/// Die Check-ins, über die gerade gerechnet wird — für den Datenauszug.
///
/// Dieselbe Auswahl wie [statsProvider], nur ungruppiert: Was auf dem
/// Bildschirm als Balken steht, steht in der Datei als Zeilen. Eine
/// zweite Abfrage mit eigenen Filtern liefe früher oder später
/// auseinander.
final statsRowsProvider = Provider<List<CheckinFacts>>((ref) {
  final all = ref.watch(alleEigenenCheckinsProvider).valueOrNull ?? const [];
  return auswahl(
    all.facts,
    now: ref.watch(clockProvider).valueOrNull ?? DateTime.now(),
    period: ref.watch(statsPeriodProvider),
    country: ref.watch(statsCountryProvider),
    style: ref.watch(statsStyleProvider),
  );
});

/// Alle je getrunkenen Länder und Stile — für die Filterauswahl.
/// Absichtlich ungefiltert, sonst könnte man einen Filter nicht mehr
/// wechseln, sobald er greift.
final statsFilterOptionsProvider = Provider<({
  List<String> countries,
  List<String> styles,
})>((ref) {
  final all = ref.watch(alleEigenenCheckinsProvider).valueOrNull ?? const [];
  final countries = {for (final d in all) d.brewery.country}.toList()..sort();
  final styles = {for (final d in all) d.beer.style}.toList()..sort();
  return (countries: countries, styles: styles);
});


/// Der Vergleich mit allen anderen BrewMates (Wunsch #146).
///
/// Kommt vom Server (`community_stats`, Migration 0054) und ist bewusst
/// **anonym und aggregiert**: nie eine Zeile, nie eine Identität, und
/// Durchschnitte erst ab genug beitragenden Personen. Wie viele „genug"
/// sind, entscheidet die Datenbank — eine Schwelle, die die Oberfläche
/// zieht, ist keine.
///
/// `null` heißt: abgemeldet, offline oder der Aufruf ist gescheitert.
/// Der Vergleich ist ein Zusatz; ohne ihn bleibt die Statistik ganz.
final communityStatsProvider =
    FutureProvider<({int teilnehmer, double? checkins, double? biere})?>(
        (ref) async {
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null) return null;

  final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
  final period = ref.watch(statsPeriodProvider);
  // „Alles" hat keinen Anfang; für den Vergleich nehmen wir dann alles,
  // was es geben kann — die Datenbank rechnet ohnehin nur über Zeilen,
  // die da sind.
  final von = period.startAt(now) ?? DateTime(2000);
  final bis = period.endAt(now) ?? now.add(const Duration(days: 1));

  return online.stats.community(von: von, bis: bis);
});
