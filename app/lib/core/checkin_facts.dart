/// Ein Check-in, reduziert auf die Tatsachen, aus denen Logik etwas
/// ableitet.
///
/// Drei Bereiche werten eigene Check-ins aus — Statistiken, Abzeichen,
/// Challenges. Alle drei brauchen dieselben Angaben, und keiner von ihnen
/// darf die Datenbank kennen: `domain/` ist reine Logik
/// (`.claude/architecture.md`). Also **ein** Eingabetyp statt drei
/// parallele.
///
/// Warum in `core/` und nicht in `domain/`: Die Übersetzung aus einer
/// Drift-Zeile liegt in `data/`, und `data/` soll nicht an `domain/`
/// hängen — sonst zeigen die Pfeile in beide Richtungen. `core/` ist die
/// Schicht, die beide lesen dürfen. Hier stehen deshalb die geteilten
/// Wertetypen (siehe auch `serving_style.dart`), nicht die Logik.
///
/// Nichts hier ist nullable, was nicht wirklich fehlen kann: Ein
/// Check-in hat immer eine Zeit, ein Bier und eine Brauerei. Ort, Notiz,
/// Menge, Gebinde und Bewertung sind optional, weil der Mensch sie
/// weglassen darf.
library;

import 'serving_style.dart';

class CheckinFacts {
  const CheckinFacts({
    required this.createdAt,
    required this.beerId,
    required this.beerName,
    required this.beerStyle,
    required this.isAlcoholFree,
    required this.breweryId,
    required this.breweryName,
    required this.breweryCountry,
    this.abv,
    this.breweryCity,
    this.sessionId,
    this.venueId,
    this.venueName,
    this.note,
    this.volumeMl,
    this.serving,
    this.rating,
  });

  final DateTime createdAt;

  final String beerId;

  /// Der Name, wie ihn ein Mensch liest. Für die Auswertung selbst
  /// unnötig — sie gruppiert nach [beerId] —, aber der Datenauszug
  /// (Funktion 20, Punkt 7) wäre ohne ihn eine Liste von UUIDs.
  final String beerName;

  final String beerStyle;
  final bool isAlcoholFree;

  final String breweryId;
  final String breweryName;
  final String breweryCountry;

  /// Alkoholgehalt des Biers in Volumenprozent, wenn die Datenbank ihn
  /// kennt. Bei nutzererstellten Bieren fehlt er oft.
  ///
  /// Die Auswertung **zeigt** ihn heute nicht: Reinalkohol ist die einzige
  /// Zahl in diesem Bereich, die einen Menschen unangenehm treffen kann,
  /// und ob sie erscheint, ist eine Produktentscheidung (Regel K,
  /// docs/features/20, Punkt 6). Das Feld steht hier, damit die
  /// Entscheidung nicht an fehlenden Daten scheitert.
  final double? abv;

  /// Stadt der Brauerei. In der lokalen Tabelle nie `null`, aber häufig
  /// leer — für die Aufteilung „Region" zählt Leer wie Fehlend.
  final String? breweryCity;

  /// Beacon/Session, zu der dieser Check-in gehört. `null` heißt: allein
  /// getrunken, nicht in einer Runde.
  final String? sessionId;

  /// Gasthaus aus der gemeinsamen Datenbank, wenn eines gewählt wurde.
  final String? venueId;

  /// Angezeigter Name des Orts — auch bei Freitext ohne [venueId] gesetzt.
  final String? venueName;

  final String? note;

  /// Gemessene Menge in ml; `null` heißt „nicht erfasst" und wird für die
  /// Literauswertung nach Gebinde geschätzt.
  final int? volumeMl;

  final ServingStyle? serving;

  final double? rating;
}
