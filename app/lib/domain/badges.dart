import '../data/db/database.dart';

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

  final List<CheckinDetails> myCheckins;
  final int mySessionCount;
  final int toastsGiven;

  /// Von mir angelegte Gasthäuser mit Kartenposition (aus dem Venue-Cache;
  /// [onlineUserId] ist die Supabase-UUID – offline bleibt der Zähler 0).
  final int venuesCreatedWithLocation;

  static Future<BadgeContext> load(AppDatabase db, String profileId,
      {String? onlineUserId}) async {
    var venuesCreated = 0;
    if (onlineUserId != null) {
      final venues = await db.watchVenuesWithLocation().first;
      venuesCreated =
          venues.where((v) => v.createdBy == onlineUserId).length;
    }
    return BadgeContext(
      myCheckins: await db.myCheckinsDetailed(profileId),
      mySessionCount: await db.countMySessions(profileId),
      toastsGiven: await db.countToastsGiven(profileId),
      venuesCreatedWithLocation: venuesCreated,
    );
  }
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
    progressOf: (c) => c.myCheckins.map((x) => x.beer.style).toSet().length,
  ),
  BadgeDef(
    slug: 'weltenbummler',
    name: 'Weltenbummler',
    description: 'Biere aus 5 verschiedenen Ländern probiert',
    emoji: '🌍',
    target: 5,
    progressOf: (c) =>
        c.myCheckins.map((x) => x.brewery.country).toSet().length,
  ),
  BadgeDef(
    slug: 'brauerei-tour',
    name: 'Brauerei-Tour',
    description: 'Biere von 10 verschiedenen Brauereien',
    emoji: '🏭',
    target: 10,
    progressOf: (c) => c.myCheckins.map((x) => x.brewery.id).toSet().length,
  ),
  BadgeDef(
    slug: 'local-hero',
    name: 'Local Hero',
    description: 'In 5 verschiedenen Venues eingecheckt',
    emoji: '📍',
    target: 5,
    progressOf: (c) => c.myCheckins
        .map((x) => x.checkin.venueName)
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
        c.myCheckins.where((x) => x.beer.isAlcoholFree).length,
  ),
  BadgeDef(
    slug: 'hopfenkopf',
    name: 'Hopfenkopf',
    description: '5 verschiedene IPAs probiert',
    emoji: '🌿',
    target: 5,
    progressOf: (c) => c.myCheckins
        .where((x) => x.beer.style.toUpperCase().contains('IPA'))
        .map((x) => x.beer.id)
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
        .where((x) => (x.checkin.note ?? '').trim().isNotEmpty)
        .length,
  ),
  BadgeDef(
    slug: 'sammler',
    name: 'Sammler',
    description: '25 verschiedene Biere probiert',
    emoji: '⭐',
    target: 25,
    progressOf: (c) => c.myCheckins.map((x) => x.beer.id).toSet().length,
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
        .map((x) => x.checkin.venueId)
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

class BadgeEngine {
  const BadgeEngine(this.db);

  final AppDatabase db;

  /// Wertet alle Abzeichen aus und vergibt neu erreichte.
  /// Gibt die NEU verdienten Abzeichen zurück (für die Gratulations-UI).
  Future<List<BadgeDef>> evaluate(String profileId,
      {String? onlineUserId}) async {
    final ctx =
        await BadgeContext.load(db, profileId, onlineUserId: onlineUserId);
    final earned = await db.earnedBadgeSlugs(profileId);
    final newlyEarned = <BadgeDef>[];
    for (final badge in allBadges) {
      if (earned.contains(badge.slug)) continue;
      if (badge.progressOf(ctx) >= badge.target) {
        await db.awardBadge(profileId, badge.slug, DateTime.now());
        newlyEarned.add(badge);
      }
    }
    return newlyEarned;
  }

  /// Fortschritt aller Abzeichen für die Galerie-Ansicht.
  Future<List<BadgeProgress>> progressList(String profileId,
      {String? onlineUserId}) async {
    final ctx =
        await BadgeContext.load(db, profileId, onlineUserId: onlineUserId);
    final earnedRows = await (db.select(db.userBadges)
          ..where((t) => t.profileId.equals(profileId)))
        .get();
    final earnedBySlug = {for (final b in earnedRows) b.badgeSlug: b.awardedAt};
    return [
      for (final badge in allBadges)
        BadgeProgress(
          def: badge,
          progress: badge.progressOf(ctx),
          awardedAt: earnedBySlug[badge.slug],
        ),
    ];
  }
}
