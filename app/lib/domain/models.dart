/// Kern-Modelle – Spiegel des Postgres-Schemas (docs/04-datenmodell.md).
library;

enum SessionVisibility { friends, crew, private }

enum SessionStatus { active, ended }

enum ServingStyle { draft, bottle, can, growler }

class Profile {
  const Profile({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio,
  });

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
}

class Brewery {
  const Brewery({
    required this.id,
    required this.name,
    this.country,
    this.city,
  });

  final String id;
  final String name;
  final String? country;
  final String? city;
}

class Beer {
  const Beer({
    required this.id,
    required this.name,
    required this.style,
    required this.brewery,
    this.abv,
    this.ibu,
    this.isAlcoholFree = false,
  });

  final String id;
  final String name;
  final String style;
  final Brewery brewery;
  final double? abv;
  final int? ibu;
  final bool isAlcoholFree;
}

class Session {
  const Session({
    required this.id,
    required this.host,
    required this.visibility,
    required this.status,
    required this.startedAt,
    required this.expiresAt,
    this.venueName,
    this.message,
    this.latitude,
    this.longitude,
  });

  final String id;
  final Profile host;
  final SessionVisibility visibility;
  final SessionStatus status;
  final DateTime startedAt;
  final DateTime expiresAt;
  final String? venueName;
  final String? message;
  final double? latitude;
  final double? longitude;

  bool get isActive =>
      status == SessionStatus.active && expiresAt.isAfter(DateTime.now());
}

class CheckIn {
  const CheckIn({
    required this.id,
    required this.author,
    required this.beer,
    required this.createdAt,
    this.rating,
    this.note,
    this.photoUrl,
    this.sessionId,
    this.venueName,
    this.flavorTags = const [],
    this.servingStyle,
  });

  final String id;
  final Profile author;
  final Beer beer;
  final DateTime createdAt;
  final double? rating;
  final String? note;
  final String? photoUrl;
  final String? sessionId;
  final String? venueName;
  final List<String> flavorTags;
  final ServingStyle? servingStyle;
}
