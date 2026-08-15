import '../core/checkin_facts.dart';
import 'streak.dart';

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
  });

  final String slug;
  final String name;
  final String description;
  final String emoji;
  final int target;
  final int Function(BadgeContext ctx) progressOf;
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
    name: 'Stil-Kenner',
    description: '10 verschiedene Bierstile probiert',
    emoji: '🧭',
    target: 10,
    progressOf: (c) => c.myCheckins.map((x) => x.beerStyle).toSet().length,
  ),
  BadgeDef(
    slug: 'stil-entdecker-3',
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
    name: 'Kurator',
    description: '50 verschiedene Biere probiert',
    emoji: '🌟',
    target: 50,
    progressOf: (c) => c.myCheckins.map((x) => x.beerId).toSet().length,
  ),
  BadgeDef(
    slug: 'brauerei-tour-2',
    name: 'Brauerei-Pilger',
    description: 'Biere von 25 verschiedenen Brauereien',
    emoji: '⛰',
    target: 25,
    progressOf: (c) => c.myCheckins.map((x) => x.breweryId).toSet().length,
  ),
  BadgeDef(
    slug: 'local-hero-2',
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
];

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
