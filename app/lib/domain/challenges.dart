import 'dart:convert';

import '../data/db/database.dart';

/// Challenges: von Admins in Supabase angelegte Herausforderungen mit
/// Zeitfenster und Belohnungs-Badge. Der Fortschritt wird – wie bei den
/// Abzeichen – clientseitig aus den EIGENEN Check-ins berechnet, gefiltert
/// auf das Challenge-Zeitfenster.
class ChallengeDef {
  const ChallengeDef({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.startsAt,
    required this.endsAt,
    required this.target,
    required this.progressOf,
  });

  final String id;
  final String title;
  final String description;
  final String emoji;
  final DateTime startsAt;
  final DateTime endsAt;
  final int target;

  /// Fortschritt über die bereits aufs Zeitfenster gefilterten Check-ins.
  final int Function(List<CheckinDetails> windowed) progressOf;

  /// Slug des Belohnungs-Badges in der lokalen UserBadges-Tabelle.
  String get badgeSlug => 'challenge-${id.substring(0, 8)}';

  bool isActiveAt(DateTime now) =>
      !now.isBefore(startsAt) && now.isBefore(endsAt);

  /// Baut die Definition aus einer Cache-Zeile. Unbekannte Regeltypen
  /// (neuere Challenge als die App) → null, die Challenge wird ohne
  /// Fortschritt angezeigt bzw. übersprungen – niemals ein Crash.
  static ChallengeDef? fromCache(ChallengeCacheData row) {
    final Map<String, dynamic> rule;
    try {
      rule = json.decode(row.ruleJson) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
    final threshold = (rule['threshold'] as num?)?.toInt();
    final progressOf = _ruleProgress(rule);
    if (threshold == null || threshold < 1 || progressOf == null) return null;
    return ChallengeDef(
      id: row.id,
      title: row.title,
      description: row.description,
      emoji: row.emoji,
      startsAt: row.startsAt,
      endsAt: row.endsAt,
      target: threshold,
      progressOf: progressOf,
    );
  }

  /// Unterstützte Regeltypen (Start-Set). Auswertung immer über die auf
  /// das Zeitfenster gefilterten eigenen Check-ins.
  static int Function(List<CheckinDetails>)? _ruleProgress(
      Map<String, dynamic> rule) {
    switch (rule['type'] as String?) {
      case 'checkins_count':
        return (list) => list.length;
      case 'distinct_beers':
        return (list) => list.map((c) => c.beer.id).toSet().length;
      case 'distinct_styles':
        return (list) => list.map((c) => c.beer.style).toSet().length;
      case 'distinct_breweries':
        return (list) => list.map((c) => c.brewery.id).toSet().length;
      case 'alcohol_free':
        return (list) => list.where((c) => c.beer.isAlcoholFree).length;
      case 'style_specific':
        final style = (rule['style'] as String? ?? '').toLowerCase();
        if (style.isEmpty) return null;
        return (list) => list
            .where((c) => c.beer.style.toLowerCase().contains(style))
            .map((c) => c.beer.id)
            .toSet()
            .length;
      case 'venue_checkins':
        return (list) => list
            .map((c) => c.checkin.venueId ?? c.checkin.venueName)
            .whereType<String>()
            .where((v) => v.trim().isNotEmpty)
            .toSet()
            .length;
      default:
        return null; // unbekannter Typ – defensiv ignorieren
    }
  }

  /// Check-ins auf das Zeitfenster filtern.
  List<CheckinDetails> window(List<CheckinDetails> all) => [
        for (final c in all)
          if (!c.checkin.createdAt.isBefore(startsAt) &&
              c.checkin.createdAt.isBefore(endsAt))
            c,
      ];

  int progressFor(List<CheckinDetails> allMyCheckins) =>
      progressOf(window(allMyCheckins));
}

/// Fortschritt einer Challenge für die Anzeige.
class ChallengeProgress {
  const ChallengeProgress({
    required this.def,
    required this.progress,
    required this.completed,
  });

  final ChallengeDef def;
  final int progress;
  final bool completed;

  double get fraction => (progress / def.target).clamp(0.0, 1.0);
}

/// Wertet Challenges aus und vergibt Belohnungs-Badges – analog BadgeEngine.
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
    final myCheckins = await db.myCheckinsDetailed(profileId);
    final earned = await db.earnedBadgeSlugs(profileId);
    final newlyCompleted = <ChallengeDef>[];
    for (final row in cached) {
      final def = ChallengeDef.fromCache(row);
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
    final myCheckins = await db.myCheckinsDetailed(profileId);
    final earned = await db.earnedBadgeSlugs(profileId);
    return [
      for (final row in cached)
        if (ChallengeDef.fromCache(row) case final def?)
          if (def.isActiveAt(moment) || earned.contains(def.badgeSlug))
            ChallengeProgress(
              def: def,
              progress: def.progressFor(myCheckins),
              completed: earned.contains(def.badgeSlug),
            ),
    ];
  }
}
