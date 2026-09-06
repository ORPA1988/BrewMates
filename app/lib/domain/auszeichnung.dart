import 'badges.dart' show BadgeTier;

/// Die vier Wege, eine Challenge zu gewinnen (Migration 0063).
///
/// **Zwei Achsen, die sich nie überschneiden dürfen:** Das *Metall* sagt
/// den Rang, das *Band* sagt das Jahr. Genau eine Bedeutung je Zeichen —
/// drei Bedeutungen gleichzeitig wären keine.
enum Auszeichnungsart {
  /// Als Erster fertig. Genau eine Person je Challenge.
  blitzschluck,

  /// Die Crew mit den meisten Abschlüssen; jedes Mitglied bekommt sie.
  besteCrew,

  /// Als Letzter fertig geworden — aber fertig geworden.
  schlusslicht,

  /// Abgeschlossen, egal auf welchem Platz.
  dabei;

  /// Der Wert, wie ihn der Server im Enum `challenge_award_kind` führt.
  String get serverWert => switch (this) {
        Auszeichnungsart.blitzschluck => 'blitzschluck',
        Auszeichnungsart.besteCrew => 'beste_crew',
        Auszeichnungsart.schlusslicht => 'schlusslicht',
        Auszeichnungsart.dabei => 'dabei',
      };

  /// `null` für einen unbekannten Wert — eine Auszeichnung, die neuer ist
  /// als die App, wird übersprungen statt zum Absturz gebracht. Dieselbe
  /// Entscheidung wie bei den Challenge-Regeln (`ChallengeDef.fromRule`).
  static Auszeichnungsart? vomServer(String? wert) => switch (wert) {
        'blitzschluck' => Auszeichnungsart.blitzschluck,
        'beste_crew' => Auszeichnungsart.besteCrew,
        'schlusslicht' => Auszeichnungsart.schlusslicht,
        'dabei' => Auszeichnungsart.dabei,
        _ => null,
      };

  String get anzeige => switch (this) {
        Auszeichnungsart.blitzschluck => 'Blitzschluck',
        Auszeichnungsart.besteCrew => 'Beste Crew',
        Auszeichnungsart.schlusslicht => 'Schlusslicht',
        Auszeichnungsart.dabei => 'Dabei gewesen',
      };

  String get erklaerung => switch (this) {
        Auszeichnungsart.blitzschluck => 'Als Erster fertig',
        Auszeichnungsart.besteCrew => 'Crew mit den meisten Abschlüssen',
        Auszeichnungsart.schlusslicht => 'Als Letzter fertig geworden',
        Auszeichnungsart.dabei => 'Abgeschlossen',
      };

  /// Der Rang bestimmt das Metall — und nur er.
  BadgeTier get tier => switch (this) {
        Auszeichnungsart.blitzschluck => BadgeTier.platin,
        Auszeichnungsart.besteCrew => BadgeTier.gold,
        Auszeichnungsart.schlusslicht => BadgeTier.silber,
        Auszeichnungsart.dabei => BadgeTier.bronze,
      };
}

/// Bandfarben einer Trophäe, von links nach rechts.
///
/// **Das Band trägt das Jahr.** Die Weihnachtstrophäe 2026 und die von
/// 2027 haben dieselbe Form, denselben Sockel und dasselbe Motiv — anders
/// sind nur Band und Jahreszahl. Damit ist jedes Jahr eindeutig, ohne dass
/// jemand jedes Jahr etwas neu gestalten müsste.
///
/// Die Farbe **rechnet sich aus dem Jahr**, sie steht in keiner Datei: Eine
/// neue Trophäe kostet deshalb keinen Entwurf. Sechs Bänder, danach
/// wiederholt sich die Reihe — wer 2032 neben 2026 legt, sieht dasselbe
/// Band, aber eine andere Zahl im Sockel.
List<int> bandFarben(int jahr) {
  const baender = <List<int>>[
    [0xFF1F5B3A, 0xFF2F7A4E], // Tanne
    [0xFF7A1E28, 0xFFA32C39], // Glut
    [0xFF23345E, 0xFF3A5590], // Nacht
    [0xFF4A5A22, 0xFF6C8232], // Moos
    [0xFF4A2352, 0xFF6E3A78], // Pflaume
    [0xFF7A3F17, 0xFFA4571F], // Rost
  ];
  // Ab 2026 gerechnet, damit die erste Trophäe der App das Tannenband
  // trägt. Der doppelte Modulo fängt Jahre davor ab — Dart liefert für
  // negative Zahlen einen negativen Rest.
  final i = ((jahr - 2026) % baender.length + baender.length) %
      baender.length;
  return baender[i];
}
