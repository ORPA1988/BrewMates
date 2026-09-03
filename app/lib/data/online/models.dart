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
      case 'session_toast':
        return '$wer hat dir zugeprostet 🍻';
      case 'session_joined':
        return '$wer ist bei deinem Beacon dabei 🍻';
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

  /// Eine Zeile aus `checkins` samt eingebettetem Autor.
  ///
  /// Lag als private Methode in `CheckinsApi`, bis der Crew-Feed
  /// dieselbe Zuordnung brauchte. Zwei Kopien einer Spaltenzuordnung
  /// laufen auseinander, sobald eine Spalte dazukommt — und dann fehlt
  /// sie an genau einer Stelle, die niemand prüft.
  factory RemoteCheckin.fromRow(Map<String, dynamic> r) => RemoteCheckin(
        id: r['id'] as String,
        author: RemoteProfile.fromRow(r['author'] as Map<String, dynamic>),
        beerName: (r['beer_name'] as String?) ?? 'Unbekanntes Bier',
        breweryName: r['brewery_name'] as String?,
        beerStyle: r['beer_style'] as String?,
        isAlcoholFree: (r['is_alcohol_free'] as bool?) ?? false,
        rating: (r['rating'] as num?)?.toDouble(),
        note: r['note'] as String?,
        venueName: r['venue_name'] as String?,
        sessionId: r['session_id'] as String?,
        photoUrl: r['photo_url'] as String?,
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
      );

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

/// 👥 Crew (Gruppe) aus Supabase.
class RemoteCrew {
  const RemoteCrew({
    required this.id,
    required this.name,
    required this.emoji,
    required this.ownerId,
    required this.memberCount,
    this.joinCode,
  });

  final String id;
  final String name;
  final String emoji;
  final String ownerId;
  final int memberCount;

  /// Sechsstelliger Einladungscode zum Vorlesen (0041).
  ///
  /// Nullbar, weil ältere App-Fassungen ihn nicht mitlesen und eine
  /// Crew ohne Code kein Fehler ist — nur einer, der sich nicht
  /// diktieren lässt.
  final String? joinCode;
}

/// Alle Supabase-Zugriffe der App. Grundsätze:
/// - Die App bleibt ohne Konto voll funktionsfähig (local-first).
/// - Netzfehler werden geschluckt, wo der lokale Zustand die Wahrheit ist
///   (Spiegel-Schreibvorgänge), und als Meldung zurückgegeben, wo der
///   Nutzer eine Antwort erwartet (Login, Anfragen).

/// Wer bei einer Session mitmacht — vom Server, nicht aus der lokalen DB.
class RemoteParticipant {
  const RemoteParticipant({required this.profile, required this.joined});
  final RemoteProfile profile;
  /// true = „Bin dabei", false = nur zugeprostet.
  final bool joined;
}

enum FeedbackKind { bug, wish }

enum FeedbackStatus { open, planned, done, declined }

/// Eine eigene Meldung mit Status — Nachvollziehbarkeit fuer den Tester.
class FeedbackItem {
  const FeedbackItem({
    required this.id,
    required this.kind,
    required this.body,
    required this.status,
    required this.createdAt,
    this.reply,
    this.roadmapTitle,
    this.githubIssue,
  });

  factory FeedbackItem.fromRow(Map<String, dynamic> r) {
    final rm = r['roadmap'];
    return FeedbackItem(
      id: r['id'] as String,
      kind: r['kind'] == 'wish' ? FeedbackKind.wish : FeedbackKind.bug,
      body: r['body'] as String,
      status: FeedbackStatus.values.firstWhere(
          (s) => s.name == r['status'],
          orElse: () => FeedbackStatus.open),
      createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
      reply: r['reply'] as String?,
      roadmapTitle: rm is Map ? rm['title'] as String? : null,
      githubIssue: r['github_issue'] as int?,
    );
  }

  final String id;
  final FeedbackKind kind;
  final String body;
  final FeedbackStatus status;
  final DateTime createdAt;
  final String? reply;
  final String? roadmapTitle;

  /// Nummer des anonymen GitHub-Issues — dort läuft die Verwaltung.
  /// null, solange die Edge Function es noch nicht angelegt hat.
  final int? githubIssue;

  String get statusLabel => switch (status) {
        FeedbackStatus.open => 'Eingegangen',
        FeedbackStatus.planned => 'Geplant',
        FeedbackStatus.done => 'Erledigt',
        FeedbackStatus.declined => 'Nicht geplant',
      };
}

enum RoadmapStatus { planned, inProgress, done }

/// Ein Roadmap-Punkt in Alltagssprache.
class RoadmapItem {
  const RoadmapItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.status,
    this.githubIssue,
  });

  factory RoadmapItem.fromRow(Map<String, dynamic> r) => RoadmapItem(
        id: r['id'] as String,
        title: r['title'] as String,
        summary: r['summary'] as String,
        status: switch (r['status']) {
          'in_progress' => RoadmapStatus.inProgress,
          'done' => RoadmapStatus.done,
          _ => RoadmapStatus.planned,
        },
        githubIssue: r['github_issue'] as int?,
      );

  final String id;
  final String title;
  final String summary;
  final RoadmapStatus status;

  /// GitHub-Issue, aus dem der Punkt gespiegelt wird (Details, Diskussion).
  final int? githubIssue;

  String get statusEmoji => switch (status) {
        RoadmapStatus.inProgress => '🔧',
        RoadmapStatus.planned => '🗓️',
        RoadmapStatus.done => '✅',
      };
}

/// Eine Meldung aus Sicht der Moderation (Migration 0040, RPC
/// `moderation_reports`).
///
/// Die Namen stehen mit drin, weil `profiles_select` sie nicht hergibt:
/// Ein privates Profil bleibt auch für Moderatoren unsichtbar, und das
/// soll so bleiben. Die RPC gibt genau die Namen heraus, die an einer
/// Meldung hängen — nicht mehr.
class ModerationReport {
  const ModerationReport({
    required this.id,
    required this.subjectType,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.reporterId,
    required this.reporterName,
    required this.reportedId,
    required this.reportedName,
    this.subjectId,
    this.note,
    this.handledAt,
    this.handledByName,
  });

  factory ModerationReport.fromRow(Map<String, dynamic> r) => ModerationReport(
        id: r['id'] as String,
        subjectType: (r['subject_type'] as String?) ?? 'profile',
        subjectId: r['subject_id'] as String?,
        reason: (r['reason'] as String?) ?? '',
        status: (r['status'] as String?) ?? 'open',
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        reporterId: r['reporter_id'] as String,
        reporterName: (r['reporter_name'] as String?) ?? 'Jemand',
        reportedId: r['reported_id'] as String,
        reportedName: (r['reported_name'] as String?) ?? 'Jemand',
        note: r['note'] as String?,
        handledAt: r['handled_at'] == null
            ? null
            : DateTime.parse(r['handled_at'] as String).toLocal(),
        handledByName: r['handled_by_name'] as String?,
      );

  final String id;

  /// `profile`, `checkin`, `comment` oder `session`.
  final String subjectType;
  final String? subjectId;
  final String reason;

  /// `open`, `resolved` oder `dismissed`.
  final String status;
  final DateTime createdAt;
  final String reporterId;
  final String reporterName;
  final String reportedId;
  final String reportedName;

  /// Befund des Moderators — nur für Moderatoren sichtbar.
  final String? note;
  final DateTime? handledAt;
  final String? handledByName;

  bool get isOpen => status == 'open';

  String get statusLabel => switch (status) {
        'resolved' => 'Erledigt',
        'dismissed' => 'Verworfen',
        _ => 'Offen',
      };

  String get subjectLabel => switch (subjectType) {
        'checkin' => 'Check-in',
        'comment' => 'Kommentar',
        'session' => 'Runde',
        _ => 'Profil',
      };
}
