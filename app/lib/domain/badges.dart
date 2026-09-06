import '../core/checkin_facts.dart';
import '../core/serving_style.dart';
import 'streak.dart';

/// Rang eines Abzeichens. **Das Metall sagt den Rang — sonst nichts.**
///
/// Nicht das Jahr, nicht das Thema, nicht eine Menge. Genau eine Bedeutung
/// je Zeichen; drei Bedeutungen gleichzeitig wären keine.
///
/// [BadgeTier.platin] ist den Challenge-Rängen vorbehalten, wo es einen
/// echten Ersten gibt. Ein Dauerabzeichen erreicht höchstens Gold — sonst
/// wäre Platin nur ein weiteres „viel".
enum BadgeTier {
  bronze,
  silber,
  gold,
  platin;

  /// Verlaufsfarben des Metallrands, von der Lichtkante zur Schattenkante.
  /// Bronze ist bewusst das Kupfer der Palette (`BrewTheme.copper`) und
  /// damit kein Fremdkörper, sondern dessen helle und dunkle Kante.
  List<int> get farbverlauf => switch (this) {
        BadgeTier.bronze => [0xFFE9B489, 0xFFB4632C, 0xFF7A3F17],
        BadgeTier.silber => [0xFFF2F5F8, 0xFFC2C9D2, 0xFF8C95A1],
        BadgeTier.gold => [0xFFFFE1A3, 0xFFE8A33D, 0xFF9C6410],
        BadgeTier.platin => [0xFFFFFFFF, 0xFFDCE4EC, 0xFFA9B4C2],
      };

  String get anzeige => switch (this) {
        BadgeTier.bronze => 'Bronze',
        BadgeTier.silber => 'Silber',
        BadgeTier.gold => 'Gold',
        BadgeTier.platin => 'Platin',
      };
}

/// Abzeichen-Katalog. Grundsatz (docs/01-produktvision.md): belohnt werden
/// Vielfalt, Orte und Gemeinsamkeit – niemals Konsummenge.
class BadgeDef {
  const BadgeDef({
    required this.slug,
    required this.name,
    required this.description,
    required this.emoji,
    required this.target,
    required this.progressOf,
    this.tier = BadgeTier.bronze,
  });

  final String slug;
  final String name;
  final String description;
  final String emoji;
  final int target;
  final int Function(BadgeContext ctx) progressOf;

  /// Rang. Vorgabe Bronze: Ein Abzeichen ohne ausdrücklichen Rang ist die
  /// erste Stufe seiner Reihe.
  final BadgeTier tier;
}

/// Einmal pro Auswertung geladener Kontext, damit nicht jedes Abzeichen
/// eigene Datenbankabfragen braucht.
class BadgeContext {
  const BadgeContext({
    required this.myCheckins,
    required this.mySessionCount,
    required this.toastsGiven,
    this.venuesCreatedWithLocation = 0,
  });

  final List<CheckinFacts> myCheckins;
  final int mySessionCount;
  final int toastsGiven;

  /// Von mir angelegte Gasthäuser mit Kartenposition (aus dem Venue-Cache;
  /// [onlineUserId] ist die Supabase-UUID – offline bleibt der Zähler 0).
  final int venuesCreatedWithLocation;
}

final List<BadgeDef> allBadges = [
  BadgeDef(
    slug: 'erster-schluck',
    name: 'Erster Schluck',
    description: 'Dein erstes Bier eingecheckt',
    emoji: '🍺',
    target: 1,
    progressOf: (c) => c.myCheckins.length,
  ),
  BadgeDef(
    slug: 'session-starter',
    name: 'Session-Starter',
    description: 'Deine erste Session gestartet',
    emoji: '🎉',
    target: 1,
    progressOf: (c) => c.mySessionCount,
  ),
  BadgeDef(
    slug: 'stil-entdecker',
    name: 'Stil-Entdecker',
    description: '5 verschiedene Bierstile probiert',
    emoji: '🧭',
    target: 5,
    progressOf: (c) => c.myCheckins.map((x) => x.beerStyle).toSet().length,
  ),
  // Erreichbare Zwischenstufen (Wettbewerbsanalyse: Level statt
  // Fernziele — und Vielfalt statt Menge).
  BadgeDef(
    slug: 'stil-entdecker-2',
    tier: BadgeTier.silber,
    name: 'Stil-Kenner',
    description: '10 verschiedene Bierstile probiert',
    emoji: '🧭',
    target: 10,
    progressOf: (c) => c.myCheckins.map((x) => x.beerStyle).toSet().length,
  ),
  BadgeDef(
    slug: 'stil-entdecker-3',
    tier: BadgeTier.gold,
    name: 'Stil-Professor',
    description: '20 verschiedene Bierstile probiert',
    emoji: '🎓',
    target: 20,
    progressOf: (c) => c.myCheckins.map((x) => x.beerStyle).toSet().length,
  ),
  BadgeDef(
    slug: 'weltenbummler',
    name: 'Weltenbummler',
    description: 'Biere aus 5 verschiedenen Ländern probiert',
    emoji: '🌍',
    target: 5,
    progressOf: (c) =>
        c.myCheckins.map((x) => x.breweryCountry).toSet().length,
  ),
  BadgeDef(
    slug: 'weltenbummler-2',
    tier: BadgeTier.silber,
    name: 'Globetrotter',
    description: 'Biere aus 10 verschiedenen Ländern probiert',
    emoji: '🛫',
    target: 10,
    progressOf: (c) =>
        c.myCheckins.map((x) => x.breweryCountry).toSet().length,
  ),
  BadgeDef(
    slug: 'brauerei-tour',
    name: 'Brauerei-Tour',
    description: 'Biere von 10 verschiedenen Brauereien',
    emoji: '🏭',
    target: 10,
    progressOf: (c) => c.myCheckins.map((x) => x.breweryId).toSet().length,
  ),
  BadgeDef(
    slug: 'local-hero',
    name: 'Local Hero',
    description: 'In 5 verschiedenen Venues eingecheckt',
    emoji: '📍',
    target: 5,
    progressOf: (c) => c.myCheckins
        .map((x) => x.venueName)
        .whereType<String>()
        .toSet()
        .length,
  ),
  BadgeDef(
    slug: 'stammtisch',
    name: 'Stammtisch',
    description: '10 Sessions gestartet oder mitgemacht',
    emoji: '🍻',
    target: 10,
    progressOf: (c) => c.mySessionCount,
  ),
  BadgeDef(
    slug: 'prost-meister',
    name: 'Prost-Meister',
    description: '25 Toasts an Freunde vergeben',
    emoji: '🥂',
    target: 25,
    progressOf: (c) => c.toastsGiven,
  ),
  BadgeDef(
    slug: 'nuechtern-dabei',
    name: 'Nüchtern dabei',
    description: '5 alkoholfreie Biere eingecheckt – zählt voll!',
    emoji: '💧',
    target: 5,
    progressOf: (c) =>
        c.myCheckins.where((x) => x.isAlcoholFree).length,
  ),
  BadgeDef(
    slug: 'hopfenkopf',
    name: 'Hopfenkopf',
    description: '5 verschiedene IPAs probiert',
    emoji: '🌿',
    target: 5,
    progressOf: (c) => c.myCheckins
        .where((x) => x.beerStyle.toUpperCase().contains('IPA'))
        .map((x) => x.beerId)
        .toSet()
        .length,
  ),
  BadgeDef(
    slug: 'kritiker',
    name: 'Kritiker',
    description: '10 Check-ins mit Verkostungsnotiz',
    emoji: '✍️',
    target: 10,
    progressOf: (c) => c.myCheckins
        .where((x) => (x.note ?? '').trim().isNotEmpty)
        .length,
  ),
  BadgeDef(
    slug: 'sammler',
    name: 'Sammler',
    description: '25 verschiedene Biere probiert',
    emoji: '⭐',
    target: 25,
    progressOf: (c) => c.myCheckins.map((x) => x.beerId).toSet().length,
  ),
  BadgeDef(
    slug: 'sammler-2',
    tier: BadgeTier.silber,
    name: 'Kurator',
    description: '50 verschiedene Biere probiert',
    emoji: '🌟',
    target: 50,
    progressOf: (c) => c.myCheckins.map((x) => x.beerId).toSet().length,
  ),
  BadgeDef(
    slug: 'brauerei-tour-2',
    tier: BadgeTier.silber,
    name: 'Brauerei-Pilger',
    description: 'Biere von 25 verschiedenen Brauereien',
    emoji: '⛰',
    target: 25,
    progressOf: (c) => c.myCheckins.map((x) => x.breweryId).toSet().length,
  ),
  BadgeDef(
    slug: 'local-hero-2',
    tier: BadgeTier.silber,
    name: 'Wirtshaus-Legende',
    description: 'In 15 verschiedenen Venues eingecheckt',
    emoji: '🏆',
    target: 15,
    progressOf: (c) => c.myCheckins
        .map((x) => x.venueName)
        .whereType<String>()
        .toSet()
        .length,
  ),
  BadgeDef(
    slug: 'nuechtern-dabei-2',
    tier: BadgeTier.silber,
    name: 'Klarer Kopf',
    description: '15 alkoholfreie Biere eingecheckt – Respekt!',
    emoji: '🧊',
    target: 15,
    progressOf: (c) =>
        c.myCheckins.where((x) => x.isAlcoholFree).length,
  ),
  BadgeDef(
    slug: 'wochenserie',
    name: 'Wochenserie',
    description: '4 Wochen in Folge mindestens ein Check-in',
    emoji: '🔥',
    target: 4,
    progressOf: (c) => weeklyStreak(
        c.myCheckins.map((x) => x.createdAt), DateTime.now()),
  ),
  BadgeDef(
    slug: 'kartograph-2',
    tier: BadgeTier.silber,
    name: 'Landvermesser',
    description: '10 Gasthäuser mit Kartenposition angelegt',
    emoji: '📐',
    target: 10,
    progressOf: (c) => c.venuesCreatedWithLocation,
  ),
  // Datenpflege: die gemeinsame Gasthaus-DB lebt von Beiträgen.
  BadgeDef(
    slug: 'kartograph',
    name: 'Kartograph',
    description: '3 Gasthäuser mit Kartenposition angelegt',
    emoji: '🗺',
    target: 3,
    progressOf: (c) => c.venuesCreatedWithLocation,
  ),
  BadgeDef(
    slug: 'wirt-fluesterer',
    name: 'Wirt-Flüsterer',
    description: 'In 5 Gasthäusern aus der gemeinsamen DB eingecheckt',
    emoji: '🤝',
    target: 5,
    progressOf: (c) => c.myCheckins
        .map((x) => x.venueId)
        .whereType<String>()
        .toSet()
        .length,
  ),

  // --------------------------------------------------------------------
  // Erweiterung 0.10.28 — 23 auf 55 Abzeichen.
  //
  // Alles darunter rechnet aus Feldern, die `CheckinFacts` schon trägt:
  // keine Migration, keine neue Abfrage, kein neues Feld. Und keines
  // belohnt Menge — gezählt werden Vielfalt, Orte, Uhrzeiten, Sorgfalt
  // und ausdrücklich Alkoholfreiheit.
  // --------------------------------------------------------------------

  // --- Zeit und Rhythmus ------------------------------------------------
  BadgeDef(
    slug: 'fruehschoppen',
    name: 'Frühschoppen',
    description: '5-mal vor 12 Uhr eingecheckt',
    emoji: '🌅',
    target: 5,
    progressOf: (c) => c.myCheckins.where((x) => x.createdAt.hour < 12).length,
  ),
  BadgeDef(
    slug: 'nachtschwaermer',
    name: 'Nachtschwärmer',
    description: '5-mal nach 23 Uhr eingecheckt',
    emoji: '🌙',
    target: 5,
    progressOf: (c) => c.myCheckins.where((x) => x.createdAt.hour >= 23).length,
  ),
  BadgeDef(
    slug: 'sonntagsruhe',
    name: 'Sonntagsruhe',
    description: '5-mal an einem Sonntag eingecheckt',
    emoji: '🛋️',
    target: 5,
    progressOf: (c) => c.myCheckins
        .where((x) => x.createdAt.weekday == DateTime.sunday)
        .length,
  ),
  BadgeDef(
    slug: 'wochenserie-2',
    tier: BadgeTier.silber,
    name: 'Durchhalter',
    description: '12 Wochen in Folge mindestens ein Check-in',
    emoji: '📅',
    target: 12,
    progressOf: (c) =>
        weeklyStreak(c.myCheckins.map((x) => x.createdAt), DateTime.now()),
  ),
  BadgeDef(
    slug: 'wochenserie-3',
    tier: BadgeTier.gold,
    name: 'Halbes Jahr',
    description: '26 Wochen in Folge mindestens ein Check-in',
    emoji: '🗓️',
    target: 26,
    progressOf: (c) =>
        weeklyStreak(c.myCheckins.map((x) => x.createdAt), DateTime.now()),
  ),
  BadgeDef(
    slug: 'jahreszeiten',
    tier: BadgeTier.silber,
    name: 'Vier Jahreszeiten',
    description: 'In Frühling, Sommer, Herbst und Winter eingecheckt',
    emoji: '🍂',
    target: 4,
    progressOf: (c) =>
        c.myCheckins.map((x) => (x.createdAt.month % 12) ~/ 3).toSet().length,
  ),
  BadgeDef(
    slug: 'monatssammler',
    tier: BadgeTier.gold,
    name: 'Zwölf Monate',
    description: 'In allen zwölf Monaten einmal eingecheckt',
    emoji: '📆',
    target: 12,
    progressOf: (c) =>
        c.myCheckins.map((x) => x.createdAt.month).toSet().length,
  ),

  // --- Stil und Geschmack ----------------------------------------------
  BadgeDef(
    slug: 'weissbier-freund',
    name: 'Weißbier-Freund',
    description: '5 verschiedene Weizen- oder Weißbiere',
    emoji: '🌾',
    target: 5,
    progressOf: (c) => _mitStil(c, const ['weiß', 'weiss', 'weizen']),
  ),
  BadgeDef(
    slug: 'pils-purist',
    name: 'Pils-Purist',
    description: '5 verschiedene Pils probiert',
    emoji: '🫧',
    target: 5,
    progressOf: (c) => _mitStil(c, const ['pils']),
  ),
  BadgeDef(
    slug: 'dunkles-herz',
    name: 'Dunkles Herz',
    description: '5 verschiedene dunkle Biere probiert',
    emoji: '🌑',
    target: 5,
    progressOf: (c) =>
        _mitStil(c, const ['dunkl', 'schwarz', 'stout', 'porter']),
  ),
  BadgeDef(
    slug: 'bock-jaeger',
    tier: BadgeTier.silber,
    name: 'Bockjäger',
    description: '5 verschiedene Bockbiere probiert',
    emoji: '🐐',
    target: 5,
    progressOf: (c) => _mitStil(c, const ['bock']),
  ),
  BadgeDef(
    slug: 'maerzen-freund',
    name: 'Märzen-Freund',
    description: '5 verschiedene Märzen probiert',
    emoji: '🎪',
    target: 5,
    progressOf: (c) => _mitStil(c, const ['märzen', 'maerzen']),
  ),
  BadgeDef(
    slug: 'leichtfuss',
    name: 'Leichtfuß',
    description: '5 verschiedene Biere unter 4,0 %',
    emoji: '🪶',
    target: 5,
    progressOf: (c) => c.myCheckins
        .where((x) => x.abv != null && x.abv! > 0 && x.abv! < 4.0)
        .map((x) => x.beerId)
        .toSet()
        .length,
  ),
  BadgeDef(
    slug: 'schwergewicht',
    tier: BadgeTier.silber,
    name: 'Schwergewicht',
    description: '5 verschiedene Biere über 7,5 %',
    emoji: '🪨',
    target: 5,
    progressOf: (c) => c.myCheckins
        .where((x) => x.abv != null && x.abv! > 7.5)
        .map((x) => x.beerId)
        .toSet()
        .length,
  ),
  BadgeDef(
    slug: 'stil-entdecker-4',
    tier: BadgeTier.gold,
    name: 'Stil-Archivar',
    description: '30 verschiedene Bierstile probiert',
    emoji: '🏛️',
    target: 30,
    progressOf: (c) => c.myCheckins.map((x) => x.beerStyle).toSet().length,
  ),

  // --- Herkunft ---------------------------------------------------------
  BadgeDef(
    slug: 'heimatliebe',
    name: 'Heimatliebe',
    description: '10 verschiedene Biere aus Österreich',
    emoji: '🇦🇹',
    target: 10,
    progressOf: (c) => _ausLand(c, 'österreich'),
  ),
  BadgeDef(
    slug: 'nachbarschaft',
    name: 'Nachbarschaft',
    description: '10 verschiedene Biere aus Deutschland',
    emoji: '🇩🇪',
    target: 10,
    progressOf: (c) => _ausLand(c, 'deutschland'),
  ),
  BadgeDef(
    slug: 'eidgenosse',
    name: 'Eidgenosse',
    description: '5 verschiedene Biere aus der Schweiz',
    emoji: '🇨🇭',
    target: 5,
    progressOf: (c) => _ausLand(c, 'schweiz'),
  ),
  BadgeDef(
    slug: 'staedtereise',
    tier: BadgeTier.silber,
    name: 'Städtereise',
    description: 'Brauereien aus 10 verschiedenen Orten',
    emoji: '🗺️',
    target: 10,
    progressOf: (c) => c.myCheckins
        .map((x) => x.breweryCity)
        .whereType<String>()
        .where((x) => x.trim().isNotEmpty)
        .toSet()
        .length,
  ),
  BadgeDef(
    slug: 'brauerei-tour-3',
    tier: BadgeTier.gold,
    name: 'Brauerei-Chronist',
    description: 'Biere von 50 verschiedenen Brauereien',
    emoji: '🏰',
    target: 50,
    progressOf: (c) => c.myCheckins.map((x) => x.breweryId).toSet().length,
  ),

  // --- Sammeln und Orte -------------------------------------------------
  BadgeDef(
    slug: 'sammler-3',
    tier: BadgeTier.gold,
    name: 'Archivar',
    description: '100 verschiedene Biere probiert',
    emoji: '🗄️',
    target: 100,
    progressOf: (c) => c.myCheckins.map((x) => x.beerId).toSet().length,
  ),
  BadgeDef(
    slug: 'local-hero-3',
    tier: BadgeTier.gold,
    name: 'Ortskundig',
    description: 'In 30 verschiedenen Gasthäusern eingecheckt',
    emoji: '🏘️',
    target: 30,
    progressOf: (c) => c.myCheckins
        .map((x) => x.venueName)
        .whereType<String>()
        .toSet()
        .length,
  ),
  BadgeDef(
    slug: 'stammlokal',
    tier: BadgeTier.silber,
    name: 'Stammlokal',
    description: '10-mal im selben Gasthaus eingecheckt',
    emoji: '🪑',
    target: 10,
    progressOf: (c) {
      final proOrt = <String, int>{};
      for (final x in c.myCheckins) {
        final ort = x.venueName;
        if (ort == null || ort.trim().isEmpty) continue;
        proOrt[ort] = (proOrt[ort] ?? 0) + 1;
      }
      return proOrt.values.fold(0, (a, b) => a > b ? a : b);
    },
  ),

  // --- Gebinde ----------------------------------------------------------
  BadgeDef(
    slug: 'vom-fass',
    name: 'Vom Fass',
    description: '10-mal frisch Gezapftes eingecheckt',
    emoji: '🛢️',
    target: 10,
    progressOf: (c) =>
        c.myCheckins.where((x) => x.serving == ServingStyle.draft).length,
  ),
  BadgeDef(
    slug: 'flaschenpost',
    name: 'Flaschenpost',
    description: '25-mal aus der Flasche eingecheckt',
    emoji: '🍾',
    target: 25,
    progressOf: (c) =>
        c.myCheckins.where((x) => x.serving == ServingStyle.bottle).length,
  ),
  BadgeDef(
    slug: 'kleines-glas',
    name: 'Kleines Glas',
    description: '10-mal höchstens 0,33 l eingecheckt',
    emoji: '🥃',
    target: 10,
    progressOf: (c) => c.myCheckins
        .where(
            (x) => x.volumeMl != null && x.volumeMl! > 0 && x.volumeMl! <= 330)
        .length,
  ),

  // --- Sorgfalt ---------------------------------------------------------
  BadgeDef(
    slug: 'bewerter',
    name: 'Bewerter',
    description: '25 Check-ins mit Bewertung',
    emoji: '⭐',
    target: 25,
    progressOf: (c) => c.myCheckins.where((x) => x.rating != null).length,
  ),
  BadgeDef(
    slug: 'bewerter-2',
    tier: BadgeTier.silber,
    name: 'Verlässlicher Bewerter',
    description: '100 Check-ins mit Bewertung',
    emoji: '🌟',
    target: 100,
    progressOf: (c) => c.myCheckins.where((x) => x.rating != null).length,
  ),
  BadgeDef(
    slug: 'kritiker-2',
    tier: BadgeTier.silber,
    name: 'Chronist',
    description: '50 Check-ins mit Verkostungsnotiz',
    emoji: '✍️',
    target: 50,
    progressOf: (c) =>
        c.myCheckins.where((x) => (x.note ?? '').trim().isNotEmpty).length,
  ),
  BadgeDef(
    slug: 'ehrlich-geblieben',
    name: 'Ehrlich geblieben',
    description: '5-mal höchstens 2 Sterne vergeben',
    emoji: '🫤',
    target: 5,
    progressOf: (c) =>
        c.myCheckins.where((x) => x.rating != null && x.rating! <= 2.0).length,
  ),
  BadgeDef(
    slug: 'begeistert',
    name: 'Begeistert',
    description: '10-mal 4,5 Sterne oder mehr vergeben',
    emoji: '😍',
    target: 10,
    progressOf: (c) =>
        c.myCheckins.where((x) => x.rating != null && x.rating! >= 4.5).length,
  ),

  // --- Alkoholfrei ------------------------------------------------------
  BadgeDef(
    slug: 'nuechtern-dabei-3',
    tier: BadgeTier.gold,
    name: 'Standhaft',
    description: '30 alkoholfreie Biere eingecheckt — zählt voll!',
    emoji: '🫖',
    target: 30,
    progressOf: (c) => c.myCheckins.where((x) => x.isAlcoholFree).length,
  ),
];

/// Zählt **verschiedene Biere**, deren Stil einen der Teilbegriffe enthält.
///
/// Verschiedene, nicht alle: Sonst fiele „5 Pils" mit fünfmal demselben
/// Pils — das wäre wieder eine Menge und keine Vielfalt.
int _mitStil(BadgeContext c, List<String> teile) => c.myCheckins
    .where((x) {
      final stil = x.beerStyle.toLowerCase();
      return teile.any(stil.contains);
    })
    .map((x) => x.beerId)
    .toSet()
    .length;

/// Zählt verschiedene Biere aus einem Land. Kleingeschrieben verglichen,
/// weil die Community-Daten „Österreich" schreiben und nutzererstellte
/// Zeilen alles Mögliche.
int _ausLand(BadgeContext c, String land) => c.myCheckins
    .where((x) => x.breweryCountry.toLowerCase().trim() == land)
    .map((x) => x.beerId)
    .toSet()
    .length;

class BadgeProgress {
  const BadgeProgress({
    required this.def,
    required this.progress,
    this.awardedAt,
  });

  final BadgeDef def;
  final int progress;
  final DateTime? awardedAt;

  bool get earned => awardedAt != null;
  double get fraction => (progress / def.target).clamp(0.0, 1.0);
}
