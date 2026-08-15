import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/checkin_facts_mapping.dart';
import '../../data/providers.dart';
import '../../domain/statistics.dart';

/// Provider dieser Funktion — eigene Datei statt Anbau an die
/// Sammelstelle `data/providers.dart` (siehe docs/11).

/// Gewählter Zeitraum.
final statsRangeProvider =
    StateProvider<StatsRange>((ref) => StatsRange.year);

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
    range: ref.watch(statsRangeProvider),
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
