/// Reihenfolge der Treffer in der Bier-Schnellsuche.
///
/// Die Datenbank liefert Treffer alphabetisch und sucht mit
/// `like '%wort%'` über Name, Brauerei und Stil. Für das Nachschlagen
/// im Wirtshaus ist das die falsche Reihenfolge: Wer `go` eintippt,
/// meint fast immer ein Bier, das mit „Go…“ **anfängt** — nicht das
/// erstbeste alphabetisch, in dem irgendwo ein „go“ steckt.
///
/// Diese Datei kennt deshalb nur Zeichenketten, keine Datenbanktypen.
/// Damit bleibt sie in `core/` (unterste Schicht) und ist ohne
/// Datenbank prüfbar — dieselbe Trennung wie bei `checkin_facts.dart`.
library;

/// Rang eines Treffers für [suche]. **Kleiner ist besser**, gleiche
/// Ränge behalten die alphabetische Reihenfolge der Datenbank.
///
/// Die Stufen in Worten: Der Biername fängt mit dem Getippten an, dann
/// ein Wort darin, dann dasselbe für die Brauerei, dann irgendwo
/// enthalten, zuletzt nur der Stil. Ein leerer Suchbegriff gibt allen
/// denselben Rang — dann entscheidet weiter das Alphabet.
int trefferRang({
  required String name,
  required String brauerei,
  required String stil,
  required String suche,
}) {
  final wort = suche.trim().toLowerCase();
  if (wort.isEmpty) return 0;

  final n = name.toLowerCase();
  final b = brauerei.toLowerCase();
  final s = stil.toLowerCase();

  if (n.startsWith(wort)) return 0;
  if (_wortBeginntMit(n, wort)) return 1;
  if (b.startsWith(wort)) return 2;
  if (_wortBeginntMit(b, wort)) return 3;
  if (n.contains(wort)) return 4;
  if (b.contains(wort)) return 5;
  if (s.contains(wort)) return 6;

  // Kein Treffer in den drei Feldern — kann vorkommen, wenn die Abfrage
  // über mehr Spalten sucht als diese Bewertung kennt. Dann ganz nach
  // hinten, statt so zu tun, als sei es ein guter Treffer.
  return 7;
}

/// Beginnt irgendein Wort in [text] mit [wort]?
///
/// Getrennt wird an allem, was kein Buchstabe und keine Ziffer ist —
/// „Zwickl-Bier“, „Gösser/Spezial“ und „Stiegl 1492“ zerfallen damit
/// gleich, ohne dass die Trennzeichen einzeln aufgezählt werden müssen.
bool _wortBeginntMit(String text, String wort) {
  for (final teil in text.split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))) {
    if (teil.startsWith(wort)) return true;
  }
  return false;
}
