/// Abzeichen auswerten und vergeben — der Teil, der die Datenbank kennt.
///
/// Der Katalog und die Fortschrittsregeln stehen in `domain/badges.dart`
/// und kommen ohne Drift aus. Hier liegt nur, was laden und schreiben
/// muss: Kontext holen, verdiente Abzeichen vergleichen, neue eintragen.
library;

import '../domain/badges.dart';
import 'checkin_facts_mapping.dart';
import 'db/database.dart';

/// Lädt den [BadgeContext] in einem Rutsch.
///
/// Einmal pro Auswertung, nicht je Abzeichen — sonst setzt jedes der
/// gut zwanzig Abzeichen eigene Abfragen ab.
Future<BadgeContext> loadBadgeContext(AppDatabase db, String profileId,
    {String? onlineUserId}) async {
  var venuesCreated = 0;
  if (onlineUserId != null) {
    final venues = await db.watchVenuesWithLocation().first;
    venuesCreated = venues.where((v) => v.createdBy == onlineUserId).length;
  }
  return BadgeContext(
    myCheckins: (await db.myCheckinsDetailed(profileId)).facts,
    mySessionCount: await db.countMySessions(profileId),
    toastsGiven: await db.countToastsGiven(profileId),
    venuesCreatedWithLocation: venuesCreated,
  );
}

class BadgeEngine {
  const BadgeEngine(this.db);

  final AppDatabase db;

  /// Wertet alle Abzeichen aus und vergibt neu erreichte.
  /// Gibt die NEU verdienten Abzeichen zurück (für die Gratulations-UI).
  Future<List<BadgeDef>> evaluate(String profileId,
      {String? onlineUserId}) async {
    final ctx =
        await loadBadgeContext(db, profileId, onlineUserId: onlineUserId);
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
        await loadBadgeContext(db, profileId, onlineUserId: onlineUserId);
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
