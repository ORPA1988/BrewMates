import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
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

/// Alle eigenen Check-ins — bewusst **ohne** Fenster: Eine Auswertung
/// über die letzten 30 Einträge wäre keine Auswertung.
///
/// Bei einigen tausend Check-ins gehört die Summenbildung nach SQL. Der
/// Schnitt ist dafür vorbereitet: `computeStats` bekommt nur eine Liste,
/// die Quelle lässt sich austauschen, ohne die Darstellung anzufassen.
final _allMyCheckinsProvider = StreamProvider<List<CheckinDetails>>((ref) {
  final me = ref.watch(meProvider).valueOrNull;
  if (me == null) return Stream.value(const []);
  return ref.watch(databaseProvider).watchFeed(onlyProfileId: me.id);
});

/// Die fertige Auswertung nach Zeitraum und Filtern.
final statsProvider = Provider<CheckinStats>((ref) {
  final all = ref.watch(_allMyCheckinsProvider).valueOrNull ?? const [];
  return computeStats(
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
  final all = ref.watch(_allMyCheckinsProvider).valueOrNull ?? const [];
  final countries = {for (final d in all) d.brewery.country}.toList()..sort();
  final styles = {for (final d in all) d.beer.style}.toList()..sort();
  return (countries: countries, styles: styles);
});
