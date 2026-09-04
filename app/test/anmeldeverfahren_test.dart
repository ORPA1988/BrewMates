import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/core/anmeldeverfahren.dart';

/// Die Liste der Anmeldewege kommt vom Server (Migration 0046).
///
/// Damit ist sie etwas, das eine ausgelieferte App **nicht kennt**, wenn
/// sie gebaut wird — und genau deshalb muss die Auswertung jeden Unsinn
/// überleben, den eine spätere Konfiguration enthalten könnte, ohne den
/// Anmeldebildschirm mitzureißen.
void main() {
  test('Eine gewöhnliche Liste wird in der Reihenfolge des Servers gelesen',
      () {
    expect(anmeldeverfahrenAus('google,apple'),
        [Anmeldeverfahren.google, Anmeldeverfahren.apple]);
    expect(anmeldeverfahrenAus('apple,google'),
        [Anmeldeverfahren.apple, Anmeldeverfahren.google]);
  });

  test('Leerzeichen und Großschreibung sind kein Grund zu scheitern', () {
    expect(anmeldeverfahrenAus(' Google , APPLE '),
        [Anmeldeverfahren.google, Anmeldeverfahren.apple]);
  });

  test('Ein unbekannter Anbieter wird übergangen, nicht verschluckt', () {
    // Der Server darf einen Anbieter nennen, den diese Fassung nicht
    // kennt. Eine alte Installation zeigt ihn dann eben nicht — sie darf
    // aber nicht deshalb die übrigen Knöpfe verlieren.
    expect(anmeldeverfahrenAus('google,tiktok,apple'),
        [Anmeldeverfahren.google, Anmeldeverfahren.apple]);
  });

  test('Doppelte Einträge ergeben nicht zwei gleiche Knöpfe', () {
    expect(anmeldeverfahrenAus('google,google'), [Anmeldeverfahren.google]);
  });

  test('Nichts, leer und Müll ergeben eine leere Liste', () {
    // Leer heißt hier wirklich leer. Was daraus wird — nämlich Google —
    // entscheidet die Aufrufstelle, nicht die Auswertung: Die eine sagt,
    // was dasteht, die andere, was zu tun ist.
    expect(anmeldeverfahrenAus(null), isEmpty);
    expect(anmeldeverfahrenAus(''), isEmpty);
    expect(anmeldeverfahrenAus(' , , '), isEmpty);
  });

  test('Microsoft heißt bei Supabase azure', () {
    // Der Mensch sagt „Microsoft", die Schnittstelle sagt „azure". Wer
    // das verwechselt, baut einen Knopf, den der Server nicht kennt.
    expect(anmeldeverfahrenAus('azure'), [Anmeldeverfahren.microsoft]);
    expect(Anmeldeverfahren.microsoft.knopfText, 'Mit Microsoft anmelden');
    expect(anmeldeverfahrenAus('microsoft'), isEmpty);
  });
}
