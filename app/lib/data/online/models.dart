/// Die Datentypen, die der Server liefert.
///
/// Bewusst getrennt von `online_service.dart`: Das sind reine Wertetypen
/// ohne Supabase- und ohne Drift-Bezug — sie beschreiben nur die Form der
/// Antwort. Zusammen mit den rund 1.800 Zeilen Zugriffslogik in einer
/// Datei musste bisher jede kleine Änderung an einem Feld die ganze Datei
/// laden (Backlog B-3).
///
/// `online_service.dart` reicht diese Datei weiter (`export`), damit kein
/// bestehender Importeur angefasst werden muss.
library;

/// Freundeskreis (0024). Die Reihenfolge trägt die Vergleiche —
/// `bekannter < freund < buddy`, genau wie im Aufzählungstyp der
/// Datenbank.
enum FriendTier { bekannter, freund, buddy }

extension FriendTierLabel on FriendTier {
  String get label => switch (this) {
        FriendTier.bekannter => 'Bekannte',
        FriendTier.freund => 'Freunde',
        FriendTier.buddy => 'Best Buddys',
      };

  String get emoji => switch (this) {
        FriendTier.bekannter => '👋',
        FriendTier.freund => '🍺',
        FriendTier.buddy => '🍻',
      };

  /// Beschreibung für die Auswahl — sagt, was der andere dadurch sieht.
  String get description => switch (this) {
        FriendTier.bekannter =>
          'Sieht deine Check-ins, aber nicht wo du gerade bist.',
        FriendTier.freund =>
          'Sieht deine Check-ins, deine Beacons und deine Bierlaune.',
        FriendTier.buddy =>
          'Wie Freunde — und du erreichst sie mit „nur Best Buddys".',
      };

  String get name_ => switch (this) {
        FriendTier.bekannter => 'bekannter',
        FriendTier.freund => 'freund',
        FriendTier.buddy => 'buddy',
      };
}

/// Datenbank-Name → Kreis. Unbekanntes fällt auf `freund` zurück, den
/// Vorgabewert der Migration — niemand verliert versehentlich Sichtbarkeit.
FriendTier friendTierFromName(String? name) => switch (name) {
      'bekannter' => FriendTier.bekannter,
      'buddy' => FriendTier.buddy,
      _ => FriendTier.freund,
    };

/// Profil eines echten Nutzers aus Supabase.
class RemoteProfile {
  const RemoteProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarEmoji,
    this.accountNo,
    this.thirstyUntil,
    this.tier = FriendTier.freund,
  });

  factory RemoteProfile.fromRow(
    Map<String, dynamic> row, {
    FriendTier tier = FriendTier.freund,
  }) =>
      RemoteProfile(
        id: row['id'] as String,
        username: row['username'] as String,
        displayName: (row['display_name'] as String?) ?? row['username'] as String,
        avatarEmoji: (row['avatar_emoji'] as String?) ?? '🍺',
        accountNo: (row['account_no'] as num?)?.toInt(),
        // thirsty_until wird nicht mehr direkt mitselektiert — es kommt
        // über thirstyFriends() bzw. myThirstyUntil(). Das Spaltenrecht
        // entzieht 0025, sobald keine Clients vor 0.10 mehr zugreifen;
        // bis dahin liefert der Server die Spalte noch, wir fragen sie
        // hier nur nicht mehr an. Der Null-Zweig deckt beide Stände ab.
        thirstyUntil: row['thirsty_until'] == null
            ? null
            : DateTime.parse(row['thirsty_until'] as String).toLocal(),
        tier: tier,
      );

  final String id;
  final String username;
  final String displayName;
  final String avatarEmoji;

  /// Mein Kreis für diese Person (einseitig und privat — der andere
  /// erfährt ihn nie).
  final FriendTier tier;

  /// 🍺 Bierlaune (0018): bis wann Lust auf ein Bier signalisiert wird.
  final DateTime? thirstyUntil;

  bool get hasBierlaune =>
      thirstyUntil != null && thirstyUntil!.isAfter(DateTime.now());

  /// Unveränderliche, kurze Kontonummer (für Anzeige/Support). Die
  /// technische Konto-ID ist die UUID [id]; Anmeldeverfahren (E-Mail,
  /// Google …) hängen daran und sind änderbar.
  final int? accountNo;

  /// Platzhalter-Name aus der automatischen Kontoanlage (z. B. nach
  /// Google-Login) – Nutzer sollte sich umbenennen.
  bool get hasPlaceholderUsername => username.startsWith('mate_');
}

/// Eingehende Freundschaftsanfrage.
class FriendRequest {
  const FriendRequest({required this.friendshipId, required this.from});

  final String friendshipId;
  final RemoteProfile from;
}

/// Eine Anfrage, die man selbst gestellt hat und die noch offen ist.
///
/// Bis 0.10.4 gab es die nicht: Wer jemanden angefragt hatte, sah davon
/// nichts mehr — nicht in der Suche, nicht in der Freundesliste. Ein
/// zweiter Versuch lief dann in „Anfrage laeuft schon", ohne dass je
/// erkennbar war, dass man sie selbst gestellt hatte.
class OutgoingRequest {
  const OutgoingRequest({required this.friendshipId, required this.to});

  final String friendshipId;
  final RemoteProfile to;
}

/// Eine Zeile der Glocke (`notifications`, seit 0031 per Trigger befuellt).
class RemoteNotification {
  const RemoteNotification({
    required this.id,
    required this.type,
    required this.createdAt,
    this.actor,
    this.subjectType,
    this.subjectId,
  });

  factory RemoteNotification.fromRow(Map<String, dynamic> row,
      {RemoteProfile? actor}) {
    final eingebettet = row['actor'];
    return RemoteNotification(
      id: row['id'] as String,
      type: row['type'] as String,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      actor: actor ??
          (eingebettet is Map<String, dynamic>
              ? RemoteProfile.fromRow(eingebettet)
              : null),
      subjectType: row['subject_type'] as String?,
      subjectId: row['subject_id'] as String?,
    );
  }

  final String id;

  /// `friend_request`, `friend_accepted`, spaeter `beacon` u. a.
  final String type;
  final DateTime createdAt;
  final RemoteProfile? actor;
  final String? subjectType;
  final String? subjectId;

  /// Der Satz fuer Banner und Liste. Bewusst hier und nicht im Widget:
  /// Jede Stelle, die eine Benachrichtigung zeigt, soll dasselbe sagen.
  String get text {
    final wer = actor?.displayName ?? 'Jemand';
    switch (type) {
      case 'friend_request':
        return '$wer moechte dein BrewMate sein';
      case 'friend_accepted':
        return '$wer hat deine Anfrage angenommen 🍻';
      case 'beacon':
        return '$wer ist auf ein Bier unterwegs';
      default:
        return wer;
    }
  }
}

/// Aktive Session eines Freundes.
class RemoteSession {
  const RemoteSession({
    required this.id,
    required this.host,
    this.venueName,
    this.message,
    this.latitude,
    this.longitude,
    required this.startedAt,
    required this.expiresAt,
  });

  final String id;
  final RemoteProfile host;
  final String? venueName;
  final String? message;
  final double? latitude;
  final double? longitude;
  final DateTime startedAt;
  final DateTime expiresAt;
}

/// Community-Bier aus der Supabase-Datenbank (per Barcode gefunden).
class RemoteBeer {
  const RemoteBeer({
    required this.name,
    required this.style,
    this.breweryName,
    this.breweryCountry,
    this.breweryCity,
    this.abv,
    this.isAlcoholFree = false,
    this.description,
    this.labelUrl,
    this.barcode,
  });

  final String name;
  final String style;
  final String? breweryName;
  final String? breweryCountry;
  final String? breweryCity;
  final double? abv;
  final bool isAlcoholFree;
  final String? description;
  final String? labelUrl;
  final String? barcode;
}

/// Check-in eines Freundes (denormalisiert, ohne lokale Bier-FK).
class RemoteCheckin {
  const RemoteCheckin({
    required this.id,
    required this.author,
    required this.beerName,
    this.breweryName,
    this.beerStyle,
    this.isAlcoholFree = false,
    this.rating,
    this.note,
    this.venueName,
    this.sessionId,
    this.photoUrl,
    required this.createdAt,
  });

  final String id;
  final RemoteProfile author;
  final String beerName;
  final String? breweryName;
  final String? beerStyle;
  final bool isAlcoholFree;
  final double? rating;
  final String? note;
  final String? venueName;
  final String? sessionId;
  final String? photoUrl;
  final DateTime createdAt;
}

/// 👥 Crew (Gruppe) aus Supabase — Beitritt per Einladungscode (UUID).
class RemoteCrew {
  const RemoteCrew({
    required this.id,
    required this.name,
    required this.emoji,
    required this.ownerId,
    required this.memberCount,
  });

  final String id;
  final String name;
  final String emoji;
  final String ownerId;
  final int memberCount;
}

/// Alle Supabase-Zugriffe der App. Grundsätze:
/// - Die App bleibt ohne Konto voll funktionsfähig (local-first).
/// - Netzfehler werden geschluckt, wo der lokale Zustand die Wahrheit ist
///   (Spiegel-Schreibvorgänge), und als Meldung zurückgegeben, wo der
///   Nutzer eine Antwort erwartet (Login, Anfragen).
