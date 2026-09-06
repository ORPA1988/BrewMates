/// Wie viele Check-ins in welcher Woche — die Zahlen hinter der Heatmap.
///
/// Getrennt vom Widget, weil das die Stelle ist, an der man sich verrechnen
/// kann: Wochengrenzen, Zeitzonen, die halb angebrochene laufende Woche.
/// Ein Test kann das prüfen, ein Bild nicht.
///
/// Dieselbe Wochendefinition wie `streak.dart`: Montag bis Sonntag, und
/// ein Check-in zählt in die Woche seines Ortsdatums.
library;

/// Eine Woche im Verlauf.
class Wochenwert {
  const Wochenwert(this.montag, this.anzahl);

  /// Der Montag dieser Woche, um 00:00 Ortszeit.
  final DateTime montag;

  /// Check-ins in dieser Woche. 0 ist ein gültiger Wert und wird als
  /// leeres Feld gezeichnet — genau die Lücken sind das Interessante.
  final int anzahl;
}

DateTime _montag(DateTime d) => DateTime(d.year, d.month, d.day)
    .subtract(Duration(days: d.weekday - DateTime.monday));

/// Die letzten [wochen] Wochen, älteste zuerst, die laufende zuletzt.
///
/// Immer genau [wochen] Einträge — auch für ein Konto, das erst zwei
/// Wochen alt ist. Sonst würde die Heatmap mit der Zeit wachsen und
/// jedes Mal anders aussehen; eine feste Fläche, die sich langsam
/// füllt, ist ehrlicher als eine, die sich verkleinert.
List<Wochenwert> wochenVerlauf(
  Iterable<DateTime> zeitpunkte,
  DateTime jetzt, {
  int wochen = 52,
}) {
  assert(wochen > 0);
  final letzterMontag = _montag(jetzt);
  final gezaehlt = <DateTime, int>{};
  for (final z in zeitpunkte) {
    final m = _montag(z);
    // Was nach der laufenden Woche datiert ist (falsch gestellte Uhr,
    // nachgetragener Check-in), zählt in die laufende Woche statt aus
    // dem Bild zu fallen.
    final schluessel = m.isAfter(letzterMontag) ? letzterMontag : m;
    gezaehlt[schluessel] = (gezaehlt[schluessel] ?? 0) + 1;
  }

  return [
    for (var i = wochen - 1; i >= 0; i--)
      () {
        // Über die Kalenderarithmetik statt über Duration(days: 7 * i):
        // An einer Zeitumstellung ist ein Tag 23 oder 25 Stunden lang,
        // und dann rutscht der „Montag" auf den Sonntagabend.
        final m = DateTime(letzterMontag.year, letzterMontag.month,
            letzterMontag.day - 7 * i);
        return Wochenwert(m, gezaehlt[m] ?? 0);
      }(),
  ];
}
