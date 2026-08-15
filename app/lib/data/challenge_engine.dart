/// Challenges auswerten und Belohnungs-Abzeichen vergeben — der Teil,
/// der die Datenbank kennt.
///
/// Die Regelauswertung steht in `domain/challenges.dart` und kommt ohne
/// Drift aus. Hier liegt der Adapter für die Cache-Zeile und das Schreiben.
library;

import '../domain/challenges.dart';
import 'checkin_facts_mapping.dart';
import 'db/database.dart';

/// Cache-Zeile → [ChallengeDef].
///
/// Gibt null zurück, wenn die Regel unbekannt oder unbrauchbar ist — eine
/// Challenge, die neuer ist als die App, wird übersprungen, nie zum
/// Absturz gebracht.
ChallengeDef? challengeDefFromCache(ChallengeCacheData row) =>
    ChallengeDef.fromRule(
      id: row.id,
      title: row.title,
      description: row.description,
      emoji: row.emoji,
      startsAt: row.startsAt,
      endsAt: row.endsAt,
      ruleJson: row.ruleJson,
    );

class ChallengeEngine {
  const ChallengeEngine(this.db);

  final AppDatabase db;

  /// Prüft alle gecachten Challenges gegen die eigenen Check-ins und
  /// vergibt neu abgeschlossene als lokale Badges (insertOrIgnore).
  /// Rückgabe: die NEU abgeschlossenen Challenges (für die Feier-UI).
  Future<List<ChallengeDef>> evaluate(String profileId,
      {DateTime? now}) async {
    final moment = now ?? DateTime.now();
    final cached = await db.allCachedChallenges();
    if (cached.isEmpty) return const [];
    final myCheckins = (await db.myCheckinsDetailed(profileId)).facts;
    final earned = await db.earnedBadgeSlugs(profileId);
    final newlyCompleted = <ChallengeDef>[];
    for (final row in cached) {
      final def = challengeDefFromCache(row);
      if (def == null || earned.contains(def.badgeSlug)) continue;
      // Abschluss zählt auch kurz nach Challenge-Ende (Check-ins im
      // Fenster bleiben gültig) – nur der Fortschritt ist fensterbasiert.
      if (moment.isBefore(def.startsAt)) continue;
      if (def.progressFor(myCheckins) >= def.target) {
        await db.awardBadge(profileId, def.badgeSlug, moment);
        newlyCompleted.add(def);
      }
    }
    return newlyCompleted;
  }

  /// Fortschritt aller AKTIVEN Challenges für die Anzeige.
  Future<List<ChallengeProgress>> progressList(String profileId,
      {DateTime? now}) async {
    final moment = now ?? DateTime.now();
    final cached = await db.allCachedChallenges();
    final myCheckins = (await db.myCheckinsDetailed(profileId)).facts;
    final earned = await db.earnedBadgeSlugs(profileId);
    return [
      for (final row in cached)
        if (challengeDefFromCache(row) case final def?)
          if (def.isActiveAt(moment) || earned.contains(def.badgeSlug))
            ChallengeProgress(
              def: def,
              progress: def.progressFor(myCheckins),
              completed: earned.contains(def.badgeSlug),
            ),
    ];
  }
}
