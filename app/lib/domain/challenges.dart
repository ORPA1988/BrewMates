import 'dart:convert';

import '../core/checkin_facts.dart';

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
  final int Function(List<CheckinFacts> windowed) progressOf;

  /// Slug des Belohnungs-Badges in der lokalen UserBadges-Tabelle.
  String get badgeSlug => 'challenge-${id.substring(0, 8)}';

  bool isActiveAt(DateTime now) =>
      !now.isBefore(startsAt) && now.isBefore(endsAt);

  /// Baut die Definition aus den Rohwerten einer Challenge. Unbekannte
  /// Regeltypen (neuere Challenge als die App) → null, die Challenge wird
  /// ohne Fortschritt angezeigt bzw. übersprungen – niemals ein Crash.
  ///
  /// Nimmt bewusst Einzelwerte statt einer Drift-Zeile: Diese Datei kennt
  /// die Datenbank nicht. Den Adapter für die Cache-Zeile stellt
  /// `data/challenge_engine.dart`.
  static ChallengeDef? fromRule({
    required String id,
    required String title,
    required String description,
    required String emoji,
    required DateTime startsAt,
    required DateTime endsAt,
    required String ruleJson,
  }) {
    final Map<String, dynamic> rule;
    try {
      rule = json.decode(ruleJson) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
    final threshold = (rule['threshold'] as num?)?.toInt();
    final progressOf = _ruleProgress(rule);
    if (threshold == null || threshold < 1 || progressOf == null) return null;
    return ChallengeDef(
      id: id,
      title: title,
      description: description,
      emoji: emoji,
      startsAt: startsAt,
      endsAt: endsAt,
      target: threshold,
      progressOf: progressOf,
    );
  }

  /// Unterstützte Regeltypen (Start-Set). Auswertung immer über die auf
  /// das Zeitfenster gefilterten eigenen Check-ins.
  static int Function(List<CheckinFacts>)? _ruleProgress(
      Map<String, dynamic> rule) {
    switch (rule['type'] as String?) {
      case 'checkins_count':
        return (list) => list.length;
      case 'distinct_beers':
        return (list) => list.map((c) => c.beerId).toSet().length;
      case 'distinct_styles':
        return (list) => list.map((c) => c.beerStyle).toSet().length;
      case 'distinct_breweries':
        return (list) => list.map((c) => c.breweryId).toSet().length;
      case 'alcohol_free':
        return (list) => list.where((c) => c.isAlcoholFree).length;
      case 'style_specific':
        final style = (rule['style'] as String? ?? '').toLowerCase();
        if (style.isEmpty) return null;
        return (list) => list
            .where((c) => c.beerStyle.toLowerCase().contains(style))
            .map((c) => c.beerId)
            .toSet()
            .length;
      case 'venue_checkins':
        return (list) => list
            .map((c) => c.venueId ?? c.venueName)
            .whereType<String>()
            .where((v) => v.trim().isNotEmpty)
            .toSet()
            .length;
      default:
        return null; // unbekannter Typ – defensiv ignorieren
    }
  }

  /// Check-ins auf das Zeitfenster filtern.
  List<CheckinFacts> window(List<CheckinFacts> all) => [
        for (final c in all)
          if (!c.createdAt.isBefore(startsAt) &&
              c.createdAt.isBefore(endsAt))
            c,
      ];

  int progressFor(List<CheckinFacts> allMyCheckins) =>
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
