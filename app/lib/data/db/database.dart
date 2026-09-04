import 'package:drift/drift.dart';

import '../../core/serving_style.dart';
import '../seed.dart';
import 'connection/connection.dart';

// Weitergereicht, damit die vielen bestehenden Importeure von
// `database.dart` unverändert bleiben. Das Enum selbst liegt in `core/`,
// weil auch `domain/` es braucht und dort nichts aus `data/` importieren
// darf (siehe .claude/architecture.md).
export '../../core/serving_style.dart';

part 'database.g.dart';

// ============================================================================
// Enums (Spiegel des Supabase-Schemas, docs/04-datenmodell.md)
// ============================================================================

enum SessionVisibility { friends, crew, private }

enum SessionStatus { active, ended }

// ServingStyle steht in core/serving_style.dart (oben re-exportiert).

/// Antworten auf einen Beacon. `declined` kam mit 0047 dazu — als
/// `textEnum` gespeichert, deshalb verschiebt ein neuer Wert nichts.
enum ParticipantKind { joined, toast, declined }

// ============================================================================
// Tabellen
// ============================================================================

class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get username => text().unique()();
  TextColumn get displayName => text()();
  TextColumn get avatarEmoji => text().withDefault(const Constant('🍺'))();
  TextColumn get bio => text().nullable()();
  TextColumn get favoriteStyles => text().withDefault(const Constant(''))();
  BoolColumn get isMe => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Breweries extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get country => text()();
  TextColumn get city => text()();

  // Detailinfos aus der Community-Datenbank (breweries-at.json), alle optional.
  TextColumn get address => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  IntColumn get founded => integer().nullable()();
  TextColumn get website => text().nullable()();
  TextColumn get ownership => text().nullable()();
  IntColumn get employees => integer().nullable()();
  IntColumn get annualOutputHl => integer().nullable()();
  IntColumn get revenueEur => integer().nullable()();
  TextColumn get notes => text().nullable()();

  /// Hintergrundgeschichte der Brauerei (siehe [Beers.story]).
  TextColumn get story => text().nullable()();
  TextColumn get dataStatus => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Beers extends Table {
  TextColumn get id => text()();
  TextColumn get breweryId => text().references(Breweries, #id)();
  TextColumn get name => text()();
  TextColumn get style => text()();
  RealColumn get abv => real().nullable()();
  IntColumn get ibu => integer().nullable()();
  TextColumn get description => text().nullable()();
  BoolColumn get isAlcoholFree => boolean().withDefault(const Constant(false))();
  BoolColumn get isUserSubmitted =>
      boolean().withDefault(const Constant(false))();

  /// Kundenerfahrungen/Verkostungsnotizen aus der Community-Datenbank.
  TextColumn get descriptionCommunity => text().nullable()();

  /// Redaktionelle Community-Bewertung (0–5) aus der Datenbank, kein Messwert.
  RealColumn get communityRating => real().nullable()();

  /// Kommagetrennte EAN-Barcodes (8 oder 13 Ziffern), z. B. "90034107".
  TextColumn get barcodes => text().withDefault(const Constant(''))();

  /// Etikett-/Produktfoto als URL — nur verlinkt, nie gespeichert.
  ///
  /// Zwei Herkünfte: Open Food Facts (CC-BY-SA) und seit 2026-08-15 auch
  /// Produktfotos von den Brauerei-Webseiten selbst.
  TextColumn get imageUrl => text().nullable()();

  /// Seite, von der das Bild stammt.
  ///
  /// Pflicht, sobald das Bild NICHT von Open Food Facts kommt: Ein fremdes
  /// Produktfoto ohne Herkunftsangabe zu zeigen, ist der Unterschied
  /// zwischen Zitieren und Nehmen. Die App weist die Quelle beim Bier aus.
  TextColumn get imageSource => text().nullable()();

  /// Nutzungshinweis der Brauerei, falls einer ausgewiesen ist
  /// (z. B. „© Frastanzer nennen"). Wo keiner steht, bleibt das Feld leer
  /// — dann gilt die Angabe in [imageSource].
  TextColumn get imageLicense => text().nullable()();

  /// Hintergrundgeschichte: zwei bis fünf Sätze, wie ein Mensch sie
  /// erzählen würde. Kein Werbetext, kein Wikipedia-Auszug — und lieber
  /// leer als erfunden.
  TextColumn get story => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Gebindegröße je Barcode.
///
/// Eine EAN bezeichnet **nicht das Bier, sondern die Handelseinheit**:
/// 0,33-Flasche, 0,5-Dose und Sixpack tragen je eigene Nummern. Genau
/// darin unterscheiden sich die mehreren Barcodes eines Biers — also
/// gehört die Größe an den Code und nicht ans Bier.
///
/// Bewusst eine eigene, schlanke Tabelle statt einer weiteren Spalte in
/// [Beers]: `beers.barcodes` wird vom Community-Abgleich **wholesale
/// überschrieben**. Eine Größe, die dort mitgeschrieben würde, wäre beim
/// nächsten Abgleich weg. Hier steht sie daneben und überlebt.
///
/// Unbekannte Codes fehlen einfach — dann schätzt die Auswertung wie
/// bisher nach Gebinde.
class BarcodeVolumes extends Table {
  TextColumn get ean => text()();

  /// Füllmenge in Millilitern (500 = halber Liter).
  IntColumn get volumeMl => integer()();

  @override
  Set<Column> get primaryKey => {ean};
}

/// Gemeinsame Gasthaus-Datenbank (online-first, Supabase = Wahrheit;
/// diese Tabelle ist der lokale Cache für Karte, Picker und Offline-Anzeige).
class Venues extends Table {
  TextColumn get id => text()(); // Supabase-UUID
  TextColumn get name => text()();
  TextColumn get category => text().withDefault(const Constant('gasthaus'))();
  TextColumn get address => text().nullable()();
  TextColumn get city => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get openingHours => text().nullable()();

  /// Strukturierte Öffnungszeiten (JSON-Liste `{"d":1–7,"von":…,"bis":…}`;
  /// null = nur Freitext). Grundlage für „Jetzt geöffnet".
  TextColumn get openingHoursJson => text().nullable()();
  RealColumn get priceHalfL => real().nullable()();
  RealColumn get priceThirdL => real().nullable()();
  BoolColumn get verified => boolean().withDefault(const Constant(false))();
  TextColumn get createdBy => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Sessions extends Table {
  TextColumn get id => text()();
  TextColumn get hostId => text().references(Profiles, #id)();
  TextColumn get venueId => text().nullable()();
  TextColumn get venueName => text().nullable()();
  TextColumn get message => text().nullable()();
  TextColumn get visibility => textEnum<SessionVisibility>()();
  TextColumn get status => textEnum<SessionStatus>()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  DateTimeColumn get expiresAt => dateTime()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SessionParticipants extends Table {
  TextColumn get sessionId => text().references(Sessions, #id)();
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get kind => textEnum<ParticipantKind>()();

  @override
  Set<Column> get primaryKey => {sessionId, profileId, kind};
}

class Checkins extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get beerId => text().references(Beers, #id)();
  TextColumn get sessionId => text().nullable()();
  TextColumn get venueId => text().nullable()();
  TextColumn get venueName => text().nullable()();
  RealColumn get rating => real().nullable()();
  TextColumn get note => text().nullable()();

  /// Kommagetrennt, z. B. "hopfig,fruchtig".
  TextColumn get flavorTags => text().withDefault(const Constant(''))();
  TextColumn get servingStyle => textEnum<ServingStyle>().nullable()();

  /// Foto des Check-ins (öffentliche URL im beer-photos-Bucket).
  TextColumn get photoUrl => text().nullable()();

  /// Füllmenge in Millilitern. Ohne sie gibt es keine Literangabe — und
  /// genau danach fragt man als erstes, wenn man ein Jahr zurückblickt.
  /// Alte Check-ins haben keine; die Auswertung schätzt dort nach Gebinde
  /// und weist das aus.
  IntColumn get volumeMl => integer().nullable()();

  /// Lokal geändert und noch nicht zum Server übertragen.
  ///
  /// Der Abgleich lud bisher nur hoch, was der Server **noch nicht kennt**
  /// — eine Korrektur an einem bereits hochgeladenen Check-in wäre nie
  /// angekommen. Bewusst ein Flag statt einer eigenen Warteschlangen-
  /// Tabelle (anders als `venue_edit_queue`): Hier ist die Zeile selbst
  /// die Wahrheit und der Upsert idempotent — die letzte Fassung gewinnt.
  /// Eine Tabelle daneben wäre doppelte Buchführung.
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Toasts extends Table {
  TextColumn get checkinId => text().references(Checkins, #id)();
  TextColumn get profileId => text().references(Profiles, #id)();

  @override
  Set<Column> get primaryKey => {checkinId, profileId};
}

class Comments extends Table {
  TextColumn get id => text()();
  TextColumn get checkinId => text().references(Checkins, #id)();
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class UserBadges extends Table {
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get badgeSlug => text()();
  DateTimeColumn get awardedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {profileId, badgeSlug};
}

/// Warteschlange für offline erfasste Gasthaus-Änderungen: wird beim
/// nächsten Venue-Sync FIFO abgespielt (venueId null = Neuanlage; bei
/// Neuanlagen verweist payload auf eine lokale `local-…`-Cache-Zeile).
class VenueEditQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get venueId => text().nullable()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Offline-Warteschlange für gelöschte eigene Check-ins.
///
/// Die lokale Zeile verschwindet sofort (das Löschen soll sich sofort
/// anfühlen); der Server erfährt es beim nächsten Sync. `photoUrl` wird
/// mitgeführt, weil die Check-in-Zeile zu diesem Zeitpunkt schon weg ist,
/// das Bild im Bucket aber noch aufgeräumt werden muss.
class CheckinDeleteQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get checkinId => text()();
  TextColumn get photoUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Offline-Cache der Challenges (Supabase = Wahrheit). Bleibt auch nach
/// Challenge-Ende erhalten, damit die Abzeichen-Galerie Titel/Emoji
/// verdienter Challenge-Badges anzeigen kann.
class ChallengeCache extends Table {
  TextColumn get id => text()(); // Supabase-UUID
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get emoji => text().withDefault(const Constant('🏆'))();
  TextColumn get ruleJson => text()();
  DateTimeColumn get startsAt => dateTime()();
  DateTimeColumn get endsAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class WishlistItems extends Table {
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get beerId => text().references(Beers, #id)();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {profileId, beerId};
}

// ============================================================================
// Join-Modelle
// ============================================================================

class CheckinDetails {
  const CheckinDetails({
    required this.checkin,
    required this.beer,
    required this.brewery,
    required this.author,
  });

  final Checkin checkin;
  final Beer beer;
  final Brewery brewery;
  final Profile author;
}

class SessionDetails {
  const SessionDetails({
    required this.session,
    required this.host,
    required this.participants,
  });

  final Session session;
  final Profile host;
  final List<Profile> participants;

  bool isActiveAt(DateTime now) =>
      session.status == SessionStatus.active &&
      session.expiresAt.isAfter(now);
}

class BeerWithBrewery {
  const BeerWithBrewery({required this.beer, required this.brewery});

  final Beer beer;
  final Brewery brewery;
}

class BeerStats {
  const BeerStats({required this.checkinCount, this.avgRating});

  final int checkinCount;
  final double? avgRating;
}

class ProfileStats {
  const ProfileStats({
    required this.uniqueBeers,
    required this.uniqueStyles,
    required this.uniqueBreweries,
    required this.uniqueCountries,
    required this.uniqueVenues,
    required this.totalCheckins,
    required this.totalSessions,
    required this.badgeCount,
  });

  final int uniqueBeers;
  final int uniqueStyles;
  final int uniqueBreweries;
  final int uniqueCountries;
  final int uniqueVenues;
  final int totalCheckins;
  final int totalSessions;
  final int badgeCount;
}

// ============================================================================
// Datenbank
// ============================================================================

@DriftDatabase(tables: [
  Profiles,
  Breweries,
  Beers,
  Venues,
  BarcodeVolumes,
  Sessions,
  SessionParticipants,
  Checkins,
  Toasts,
  Comments,
  UserBadges,
  WishlistItems,
  ChallengeCache,
  VenueEditQueue,
  CheckinDeleteQueue,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.open() : super(openConnection());

  AppDatabase.memory() : super(openInMemory());

  @override
  int get schemaVersion => 15;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await seedDatabase(this);
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v2: Community-Datenbank-Felder (Österreich-Fokus).
            await m.addColumn(breweries, breweries.address);
            await m.addColumn(breweries, breweries.latitude);
            await m.addColumn(breweries, breweries.longitude);
            await m.addColumn(breweries, breweries.founded);
            await m.addColumn(breweries, breweries.website);
            await m.addColumn(breweries, breweries.ownership);
            await m.addColumn(breweries, breweries.employees);
            await m.addColumn(breweries, breweries.annualOutputHl);
            await m.addColumn(breweries, breweries.revenueEur);
            await m.addColumn(breweries, breweries.notes);
            await m.addColumn(breweries, breweries.dataStatus);
            await m.addColumn(beers, beers.descriptionCommunity);
            await m.addColumn(beers, beers.communityRating);
          }
          if (from < 3) {
            // v3: Barcodes für den Scanner.
            await m.addColumn(beers, beers.barcodes);
          }
          if (from < 4) {
            // v4: Etikett-Bilder (Open Food Facts) für die Community-DB.
            await m.addColumn(beers, beers.imageUrl);
          }
          if (from < 5) {
            // v5: Demo-Daten entfernen – die Beta läuft mit echten Nutzern
            // und der Community-DB. Eigene Inhalte bleiben unangetastet;
            // Demo-Biere, an denen eigene Check-ins oder Wunschlisten-
            // Einträge hängen, bleiben deshalb bewusst stehen.
            const demoProfiles = ['anna', 'ben', 'clara'];
            await (delete(toasts)
                  ..where((t) => t.profileId.isIn(demoProfiles)))
                .go();
            await (delete(comments)
                  ..where((t) => t.profileId.isIn(demoProfiles)))
                .go();
            await (delete(checkins)
                  ..where((t) => t.profileId.isIn(demoProfiles)))
                .go();
            final demoSessions = await (selectOnly(sessions)
                  ..addColumns([sessions.id])
                  ..where(sessions.hostId.isIn(demoProfiles)))
                .map((r) => r.read(sessions.id)!)
                .get();
            await (delete(sessionParticipants)
                  ..where((t) =>
                      t.profileId.isIn(demoProfiles) |
                      t.sessionId.isIn(demoSessions)))
                .go();
            await (delete(sessions)
                  ..where((t) => t.hostId.isIn(demoProfiles)))
                .go();
            await (delete(profiles)..where((t) => t.id.isIn(demoProfiles)))
                .go();

            final usedBeerIds = <String>{
              ...await (selectOnly(checkins, distinct: true)
                    ..addColumns([checkins.beerId]))
                  .map((r) => r.read(checkins.beerId)!)
                  .get(),
              ...await (selectOnly(wishlistItems, distinct: true)
                    ..addColumns([wishlistItems.beerId]))
                  .map((r) => r.read(wishlistItems.beerId)!)
                  .get(),
            };
            await (delete(beers)
                  ..where((t) =>
                      t.id.like('beer-%') &
                      t.id.isNotIn(usedBeerIds.toList())))
                .go();
            final usedBreweryIds = await (selectOnly(beers, distinct: true)
                  ..addColumns([beers.breweryId]))
                .map((r) => r.read(beers.breweryId)!)
                .get();
            await (delete(breweries)
                  ..where((t) =>
                      t.id.like('brewery-%') &
                      t.id.isNotIn(usedBreweryIds)))
                .go();
          }
          if (from < 6) {
            // v6: Gasthaus-Cache (gemeinsame Venue-DB aus Supabase) und
            // Venue-Verknüpfung an Check-ins/Sessions (venueName bleibt
            // als denormalisierter Anzeigename erhalten).
            await m.createTable(venues);
            await m.addColumn(checkins, checkins.venueId);
            await m.addColumn(sessions, sessions.venueId);
          }
          if (from < 7) {
            // v7: Offline-Cache für Challenges (Herausforderungen).
            await m.createTable(challengeCache);
          }
          if (from < 8) {
            // v8: Offline-Queue für Gasthaus-Pflege + strukturierte
            // Öffnungszeiten.
            await m.createTable(venueEditQueue);
            await m.addColumn(venues, venues.openingHoursJson);
          }
          if (from < 9) {
            // v9: Foto-Check-ins.
            await m.addColumn(checkins, checkins.photoUrl);
          }
          if (from < 10) {
            // v10: Offline-Warteschlange für gelöschte eigene Check-ins.
            await m.createTable(checkinDeleteQueue);
          }
          if (from < 11) {
            // v11: Füllmenge je Check-in (Grundlage der Literauswertung).
            await m.addColumn(checkins, checkins.volumeMl);
          }
          if (from < 12) {
            // v12: Hintergrundgeschichten zu Bier und Brauerei.
            await m.addColumn(beers, beers.story);
            await m.addColumn(breweries, breweries.story);
          }
          if (from < 15) {
            // v15: Herkunft der Produktbilder (Funktion 04).
            await m.addColumn(beers, beers.imageSource);
            await m.addColumn(beers, beers.imageLicense);
          }
          if (from < 14) {
            // v14: Gebindegröße je Barcode (Funktion 28).
            await m.createTable(barcodeVolumes);
          }
          if (from < 13) {
            // v13: Korrekturen an Check-ins (Funktion 27). Bestehende
            // Zeilen gelten als sauber — sie sind entweder längst
            // hochgeladen oder werden über den ID-Abgleich erkannt.
            await m.addColumn(checkins, checkins.dirty);
          }
        },
      );


  // --------------------------------------------------------------------------
  // Profil
  // --------------------------------------------------------------------------

  Stream<Profile> watchMe() => (select(profiles)
        ..where((t) => t.isMe.equals(true))
        ..limit(1))
      .watchSingle();

  Future<Profile> getMe() => (select(profiles)
        ..where((t) => t.isMe.equals(true))
        ..limit(1))
      .getSingle();

  Future<void> updateMe(
      {String? displayName, String? avatarEmoji, String? bio}) async {
    final me = await getMe();
    await (update(profiles)..where((t) => t.id.equals(me.id))).write(
      ProfilesCompanion(
        displayName:
            displayName != null ? Value(displayName) : const Value.absent(),
        avatarEmoji:
            avatarEmoji != null ? Value(avatarEmoji) : const Value.absent(),
        bio: bio != null ? Value(bio) : const Value.absent(),
      ),
    );
  }

  Stream<List<Profile>> watchFriends() =>
      (select(profiles)..where((t) => t.isMe.equals(false))).watch();

  // --------------------------------------------------------------------------
  // Feed
  // --------------------------------------------------------------------------

  /// Check-ins mit Bier, Brauerei und Autor, neueste zuerst.
  ///
  /// [limit] begrenzt die Zeilen (Feed und Tagebuch laden seitenweise
  /// nach). Ohne Grenze wächst die Abfrage mit jedem Check-in — das ist
  /// nur für Auswertungen über den Gesamtbestand gedacht.
  ///
  /// [search] filtert über Bier, Brauerei, Stil und Notiz. Die Suche
  /// gehört in die Abfrage und nicht hinter das Fenster: Sonst fände das
  /// Tagebuch nur, was ohnehin schon geladen war.
  Stream<List<CheckinDetails>> watchFeed({
    String? onlyProfileId,
    int? limit,
    String? search,
  }) {
    final query = select(checkins).join([
      innerJoin(beers, beers.id.equalsExp(checkins.beerId)),
      innerJoin(breweries, breweries.id.equalsExp(beers.breweryId)),
      innerJoin(profiles, profiles.id.equalsExp(checkins.profileId)),
    ])
      ..orderBy([OrderingTerm.desc(checkins.createdAt)]);
    if (onlyProfileId != null) {
      query.where(checkins.profileId.equals(onlyProfileId));
    }
    final term = search?.trim().toLowerCase();
    if (term != null && term.isNotEmpty) {
      final pattern = '%$term%';
      query.where(beers.name.lower().like(pattern) |
          breweries.name.lower().like(pattern) |
          beers.style.lower().like(pattern) |
          checkins.note.lower().like(pattern));
    }
    if (limit != null) query.limit(limit);
    return query.watch().map((rows) => rows
        .map((row) => CheckinDetails(
              checkin: row.readTable(checkins),
              beer: row.readTable(beers),
              brewery: row.readTable(breweries),
              author: row.readTable(profiles),
            ))
        .toList());
  }

  /// Anzahl eigener Check-ins (für „alles geladen?" und Statistiken).
  Stream<int> watchCheckinCount(String profileId) {
    final count = checkins.id.count();
    return (selectOnly(checkins)
          ..addColumns([count])
          ..where(checkins.profileId.equals(profileId)))
        .watchSingle()
        .map((row) => row.read(count) ?? 0);
  }

  Stream<List<CheckinDetails>> watchSessionCheckins(String sessionId) {
    final query = select(checkins).join([
      innerJoin(beers, beers.id.equalsExp(checkins.beerId)),
      innerJoin(breweries, breweries.id.equalsExp(beers.breweryId)),
      innerJoin(profiles, profiles.id.equalsExp(checkins.profileId)),
    ])
      ..where(checkins.sessionId.equals(sessionId))
      ..orderBy([OrderingTerm.asc(checkins.createdAt)]);
    return query.watch().map((rows) => rows
        .map((row) => CheckinDetails(
              checkin: row.readTable(checkins),
              beer: row.readTable(beers),
              brewery: row.readTable(breweries),
              author: row.readTable(profiles),
            ))
        .toList());
  }

  // --------------------------------------------------------------------------
  // Toasts & Kommentare
  // --------------------------------------------------------------------------

  Stream<int> watchToastCount(String checkinId) {
    final count = toasts.checkinId.count();
    final query = selectOnly(toasts)
      ..addColumns([count])
      ..where(toasts.checkinId.equals(checkinId));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  Stream<bool> watchToastedByMe(String checkinId, String myId) =>
      (select(toasts)
            ..where((t) =>
                t.checkinId.equals(checkinId) & t.profileId.equals(myId)))
          .watch()
          .map((rows) => rows.isNotEmpty);

  Future<void> toggleToast(String checkinId, String profileId) async {
    final existing = await (select(toasts)
          ..where((t) =>
              t.checkinId.equals(checkinId) & t.profileId.equals(profileId)))
        .get();
    if (existing.isEmpty) {
      await into(toasts).insert(
          ToastsCompanion.insert(checkinId: checkinId, profileId: profileId));
    } else {
      await (delete(toasts)
            ..where((t) =>
                t.checkinId.equals(checkinId) & t.profileId.equals(profileId)))
          .go();
    }
  }

  Future<int> countToastsGiven(String profileId) async {
    final count = toasts.checkinId.count();
    final query = selectOnly(toasts)
      ..addColumns([count])
      ..where(toasts.profileId.equals(profileId));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Stream<List<(Comment, Profile)>> watchComments(String checkinId) {
    final query = select(comments).join([
      innerJoin(profiles, profiles.id.equalsExp(comments.profileId)),
    ])
      ..where(comments.checkinId.equals(checkinId))
      ..orderBy([OrderingTerm.asc(comments.createdAt)]);
    return query.watch().map((rows) => rows
        .map((row) => (row.readTable(comments), row.readTable(profiles)))
        .toList());
  }

  Stream<int> watchCommentCount(String checkinId) {
    final count = comments.id.count();
    final query = selectOnly(comments)
      ..addColumns([count])
      ..where(comments.checkinId.equals(checkinId));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  // --------------------------------------------------------------------------
  // Sessions
  // --------------------------------------------------------------------------

  Future<void> endExpiredSessions(DateTime now) async {
    await (update(sessions)
          ..where((t) =>
              t.status.equalsValue(SessionStatus.active) &
              t.expiresAt.isSmallerThanValue(now)))
        .write(SessionsCompanion(
      status: const Value(SessionStatus.ended),
      endedAt: Value(now),
    ));
  }

  Stream<List<SessionDetails>> watchActiveSessions(DateTime now) {
    final query = select(sessions).join([
      innerJoin(profiles, profiles.id.equalsExp(sessions.hostId)),
    ])
      ..where(sessions.status.equalsValue(SessionStatus.active) &
          sessions.expiresAt.isBiggerThanValue(now))
      ..orderBy([OrderingTerm.desc(sessions.startedAt)]);
    return query.watch().asyncMap((rows) async {
      final result = <SessionDetails>[];
      for (final row in rows) {
        final session = row.readTable(sessions);
        result.add(SessionDetails(
          session: session,
          host: row.readTable(profiles),
          participants: await _participantsOf(session.id),
        ));
      }
      return result;
    });
  }

  Stream<SessionDetails?> watchSession(String id) {
    final query = select(sessions).join([
      innerJoin(profiles, profiles.id.equalsExp(sessions.hostId)),
    ])
      ..where(sessions.id.equals(id));
    return query.watchSingleOrNull().asyncMap((row) async {
      if (row == null) return null;
      final session = row.readTable(sessions);
      return SessionDetails(
        session: session,
        host: row.readTable(profiles),
        participants: await _participantsOf(session.id),
      );
    });
  }

  Future<List<Profile>> _participantsOf(String sessionId) async {
    final query = select(sessionParticipants).join([
      innerJoin(
          profiles, profiles.id.equalsExp(sessionParticipants.profileId)),
    ])
      ..where(sessionParticipants.sessionId.equals(sessionId) &
          sessionParticipants.kind.equalsValue(ParticipantKind.joined));
    final rows = await query.get();
    return rows.map((r) => r.readTable(profiles)).toList();
  }

  /// Eigene Session aus dem Server-Abgleich übernehmen (gleiche ID wie am
  /// Server — `upsertSession` überträgt sie unverändert).
  Future<void> upsertSession(SessionsCompanion row) =>
      into(sessions).insertOnConflictUpdate(row);

  Future<Session?> getSession(String id) =>
      (select(sessions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<Session?> watchMyActiveSession(String myId, DateTime now) =>
      (select(sessions)
            ..where((t) =>
                t.hostId.equals(myId) &
                t.status.equalsValue(SessionStatus.active) &
                t.expiresAt.isBiggerThanValue(now))
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
            ..limit(1))
          .watchSingleOrNull();

  Future<Session?> getMyActiveSession(String myId, DateTime now) =>
      (select(sessions)
            ..where((t) =>
                t.hostId.equals(myId) &
                t.status.equalsValue(SessionStatus.active) &
                t.expiresAt.isBiggerThanValue(now))
            ..limit(1))
          .getSingleOrNull();

  /// Neues Ende einer laufenden Session (Verlängern).
  Future<void> setSessionExpiry(String id, DateTime until) async {
    await (update(sessions)..where((t) => t.id.equals(id)))
        .write(SessionsCompanion(expiresAt: Value(until)));
  }

  Future<void> endSession(String id, DateTime now) async {
    await (update(sessions)..where((t) => t.id.equals(id))).write(
      SessionsCompanion(
        status: const Value(SessionStatus.ended),
        endedAt: Value(now),
      ),
    );
  }

  /// Nimmt ein [endSession] zurück („Rückgängig" nach einem Fehltipp).
  ///
  /// Das Ablaufdatum bleibt unangetastet: Ein wiederbelebter Beacon läuft
  /// genau so lange weiter, wie er ohne den Fehltipp gelaufen wäre. Alles
  /// andere wäre eine heimliche Verlängerung.
  Future<void> reviveSession(String id) async {
    await (update(sessions)..where((t) => t.id.equals(id))).write(
      const SessionsCompanion(
        status: Value(SessionStatus.active),
        endedAt: Value(null),
      ),
    );
  }

  Future<void> joinSession(
      String sessionId, String profileId, ParticipantKind kind) async {
    // Zusage und Absage schließen einander aus; Prost steht daneben (man
    // kann zuprosten UND absagen). Der Schlüssel ist
    // (session, profil, art) — ohne das Löschen stünden nach „doch nicht"
    // beide Antworten nebeneinander.
    if (kind != ParticipantKind.toast) {
      await (delete(sessionParticipants)
            ..where((t) =>
                t.sessionId.equals(sessionId) &
                t.profileId.equals(profileId) &
                t.kind.equalsValue(ParticipantKind.toast).not()))
          .go();
    }
    await into(sessionParticipants).insert(
      SessionParticipantsCompanion.insert(
        sessionId: sessionId,
        profileId: profileId,
        kind: kind,
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// Die eigene Zu- oder Absage zurücknehmen. Der Prost bleibt.
  Future<void> antwortZuruecknehmen(String sessionId, String profileId) =>
      (delete(sessionParticipants)
            ..where((t) =>
                t.sessionId.equals(sessionId) &
                t.profileId.equals(profileId) &
                t.kind.equalsValue(ParticipantKind.toast).not()))
          .go();

  Future<int> countMySessions(String profileId) async {
    final hosted = await (select(sessions)
          ..where((t) => t.hostId.equals(profileId)))
        .get();
    final joined = await (select(sessionParticipants)
          ..where((t) =>
              t.profileId.equals(profileId) &
              t.kind.equalsValue(ParticipantKind.joined)))
        .get();
    final ids = <String>{
      ...hosted.map((s) => s.id),
      ...joined.map((p) => p.sessionId),
    };
    return ids.length;
  }

  // --------------------------------------------------------------------------
  // Biere & Brauereien
  // --------------------------------------------------------------------------

  Stream<List<BeerWithBrewery>> watchBeers(
      {String search = '', String? style}) {
    final query = select(beers).join([
      innerJoin(breweries, breweries.id.equalsExp(beers.breweryId)),
    ])
      ..orderBy([OrderingTerm.asc(beers.name)]);
    if (search.isNotEmpty) {
      final term = '%${search.toLowerCase()}%';
      query.where(beers.name.lower().like(term) |
          breweries.name.lower().like(term) |
          beers.style.lower().like(term));
    }
    if (style != null) {
      query.where(beers.style.equals(style));
    }
    return query.watch().map((rows) => rows
        .map((row) => BeerWithBrewery(
              beer: row.readTable(beers),
              brewery: row.readTable(breweries),
            ))
        .toList());
  }

  Future<List<String>> allStyles() async {
    final query = selectOnly(beers, distinct: true)..addColumns([beers.style]);
    final rows = await query.get();
    final styles = rows.map((r) => r.read(beers.style)!).toList()..sort();
    return styles;
  }

  Stream<BeerWithBrewery?> watchBeer(String id) {
    final query = select(beers).join([
      innerJoin(breweries, breweries.id.equalsExp(beers.breweryId)),
    ])
      ..where(beers.id.equals(id));
    return query.watchSingleOrNull().map((row) => row == null
        ? null
        : BeerWithBrewery(
            beer: row.readTable(beers),
            brewery: row.readTable(breweries),
          ));
  }

  Stream<BeerStats> watchBeerStats(String beerId) {
    final count = checkins.id.count();
    final avg = checkins.rating.avg();
    final query = selectOnly(checkins)
      ..addColumns([count, avg])
      ..where(checkins.beerId.equals(beerId));
    return query.watchSingle().map((row) => BeerStats(
          checkinCount: row.read(count) ?? 0,
          avgRating: row.read(avg),
        ));
  }

  Future<void> addBeer({
    required String id,
    required String breweryId,
    required String name,
    required String style,
    double? abv,
    bool isAlcoholFree = false,
    String? description,
    String? barcode,
  }) =>
      into(beers).insert(BeersCompanion.insert(
        id: id,
        breweryId: breweryId,
        name: name,
        style: style,
        abv: Value(abv),
        isAlcoholFree: Value(isAlcoholFree),
        description: Value(description),
        isUserSubmitted: const Value(true),
        barcodes: Value(barcode ?? ''),
      ));

  /// Bier über einen gescannten EAN finden. LIKE nur als Vorfilter —
  /// die exakte Prüfung passiert in Dart, weil ein EAN-8 sonst als
  /// Teilstring eines EAN-13 fälschlich matchen würde.
  Future<BeerWithBrewery?> findBeerByBarcode(String ean) async {
    final query = select(beers).join([
      innerJoin(breweries, breweries.id.equalsExp(beers.breweryId)),
    ])
      ..where(beers.barcodes.like('%$ean%'));
    final rows = await query.get();
    for (final row in rows) {
      final beer = row.readTable(beers);
      if (beer.barcodes.split(',').map((c) => c.trim()).contains(ean)) {
        return BeerWithBrewery(
            beer: beer, brewery: row.readTable(breweries));
      }
    }
    return null;
  }

  /// Einen gescannten Barcode an ein **vorhandenes** Bier hängen.
  ///
  /// Der Fall dahinter: Ein Bier steht längst in der Datenbank, hat aber
  /// noch keine EAN — etwa weil es aus der gebündelten Community-Liste
  /// stammt, die nur für einen Teil der Einträge Barcodes kennt. Wer es
  /// scannt, soll es **vervollständigen** statt ein Duplikat anzulegen.
  ///
  /// Ein Bier hat mehrere Barcodes, weil eine EAN nicht das Bier
  /// bezeichnet, sondern die Handelseinheit: 0,33-Flasche, 0,5-Dose und
  /// Sixpack tragen je eigene Nummern.
  ///
  /// Rückgabe: ob etwas geändert wurde. `false` heißt, die EAN hing dort
  /// bereits — kein Fehler, nur nichts zu tun.
  Future<bool> addBarcodeToBeer(String beerId, String ean) async {
    final beer = await (select(beers)..where((t) => t.id.equals(beerId)))
        .getSingleOrNull();
    if (beer == null) return false;
    final vorhanden = beer.barcodes
        .split(',')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
    if (vorhanden.contains(ean)) return false;
    await (update(beers)..where((t) => t.id.equals(beerId))).write(
      BeersCompanion(barcodes: Value([...vorhanden, ean].join(','))),
    );
    return true;
  }

  /// Gebindegröße zu einem Barcode merken.
  ///
  /// Idempotent: Derselbe Code darf mehrfach gemeldet werden, die letzte
  /// Angabe gewinnt. Eine Korrektur soll wirken, ohne dass jemand vorher
  /// löschen muss.
  Future<void> setBarcodeVolume(String ean, int volumeMl) =>
      into(barcodeVolumes).insertOnConflictUpdate(
          BarcodeVolumesCompanion.insert(ean: ean, volumeMl: volumeMl));

  /// Viele Gebindegrößen auf einmal übernehmen (Community-Abgleich).
  ///
  /// Wie [setBarcodeVolume] idempotent: Der Abgleich läuft bei jedem
  /// Start, und eine korrigierte Angabe soll die alte ersetzen.
  Future<void> setBarcodeVolumes(Map<String, int> volumes) async {
    if (volumes.isEmpty) return;
    await batch((b) {
      b.insertAllOnConflictUpdate(barcodeVolumes, [
        for (final e in volumes.entries)
          BarcodeVolumesCompanion.insert(ean: e.key, volumeMl: e.value),
      ]);
    });
  }

  /// Bekannte Gebindegröße zu einem Barcode (null = unbekannt).
  ///
  /// Damit weiß der Check-in nach dem Scannen, ob eine 0,33er oder eine
  /// 0,5er in der Hand ist — der eigentliche Unterschied zwischen zwei
  /// Barcodes desselben Biers.
  Future<int?> barcodeVolume(String ean) async {
    final row = await (select(barcodeVolumes)..where((t) => t.ean.equals(ean)))
        .getSingleOrNull();
    return row?.volumeMl;
  }

  Stream<Brewery?> watchBrewery(String id) =>
      (select(breweries)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Stream<List<BeerWithBrewery>> watchBeersOfBrewery(String breweryId) {
    final query = select(beers).join([
      innerJoin(breweries, breweries.id.equalsExp(beers.breweryId)),
    ])
      ..where(beers.breweryId.equals(breweryId))
      ..orderBy([OrderingTerm.asc(beers.name)]);
    return query.watch().map((rows) => rows
        .map((row) => BeerWithBrewery(
              beer: row.readTable(beers),
              brewery: row.readTable(breweries),
            ))
        .toList());
  }

  /// Brauereien nach Name/Ort/Land suchen (Entdecken-Suche).
  Stream<List<Brewery>> watchBreweriesSearch(String search) {
    final term = '%${search.toLowerCase()}%';
    return (select(breweries)
          ..where((t) =>
              t.name.lower().like(term) |
              t.city.lower().like(term) |
              t.country.lower().like(term))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  /// Brauereien mit bekanntem Standort (für die Karten-Ebene).
  Stream<List<Brewery>> watchBreweriesWithLocation() => (select(breweries)
        ..where((t) => t.latitude.isNotNull() & t.longitude.isNotNull())
        ..orderBy([(t) => OrderingTerm.asc(t.name)]))
      .watch();

  /// Upsert aus der Community-Datenbank (GitHub-JSON).
  // ---------------------------------------------------------------------
  // Gasthäuser (lokaler Cache der gemeinsamen Supabase-Venue-DB)
  // ---------------------------------------------------------------------

  /// Cache-Abgleich aus Supabase (idempotent per Upsert).
  Future<void> upsertVenues(List<VenuesCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(venues, rows));
  }

  /// Jüngster bekannter Stand – Grundlage für Delta-Sync über updated_at.
  Future<DateTime?> latestVenueUpdate() async {
    final row = await (selectOnly(venues)
          ..addColumns([venues.updatedAt.max()]))
        .getSingle();
    return row.read(venues.updatedAt.max());
  }

  Stream<List<Venue>> watchVenuesWithLocation() => (select(venues)
        ..where((t) => t.latitude.isNotNull() & t.longitude.isNotNull())
        ..orderBy([(t) => OrderingTerm.asc(t.name)]))
      .watch();

  /// Komplette Gasthausliste (Sortierung übernimmt die UI).
  Stream<List<Venue>> watchAllVenues() =>
      (select(venues)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Stream<List<Venue>> watchVenueSearch(String query) {
    final term = query.trim().toLowerCase();
    final q = select(venues)
      ..orderBy([(t) => OrderingTerm.asc(t.name)])
      ..limit(30);
    if (term.isNotEmpty) {
      q.where((t) =>
          t.name.lower().like('%$term%') | t.city.lower().like('%$term%'));
    }
    return q.watch();
  }

  Future<Venue?> venueById(String id) =>
      (select(venues)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<Venue?> watchVenue(String id) =>
      (select(venues)..where((t) => t.id.equals(id))).watchSingleOrNull();

  // ---------------------------------------------------------------------
  // Offline-Warteschlange für Gasthaus-Änderungen
  // ---------------------------------------------------------------------

  /// Stellt eine offline erfasste Änderung in die Warteschlange
  /// (venueId null = Neuanlage).
  Future<int> enqueueVenueEdit({
    String? venueId,
    required String payloadJson,
    required DateTime createdAt,
  }) =>
      into(venueEditQueue).insert(VenueEditQueueCompanion.insert(
        venueId: Value(venueId),
        payloadJson: payloadJson,
        createdAt: createdAt,
      ));

  /// Alle wartenden Einträge in Erfassungsreihenfolge (FIFO).
  Future<List<VenueEditQueueData>> pendingVenueEdits() =>
      (select(venueEditQueue)..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();

  Future<void> deleteVenueEdit(int id) async {
    await (delete(venueEditQueue)..where((t) => t.id.equals(id))).go();
  }

  // --------------------------------------------------------------------------
  // Check-ins löschen (lokal sofort, Server beim nächsten Sync)
  // --------------------------------------------------------------------------

  /// Hat der Mensch dieses Bier schon einmal eingecheckt?
  ///
  /// Damit erkennt der Scanner das „erste Mal", ohne dafür eine eigene
  /// Tabelle gesehener Geschichten zu brauchen.
  Future<bool> hasCheckinForBeer(String profileId, String beerId) async {
    final row = await (select(checkins)
          ..where((t) => t.profileId.equals(profileId) & t.beerId.equals(beerId))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  Future<Checkin?> findCheckin(String id) =>
      (select(checkins)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Stellt einen gelöschten Check-in wieder her („Rückgängig").
  Future<void> restoreCheckinRow(Checkin row) async {
    await into(checkins).insertOnConflictUpdate(row);
  }

  /// Löscht einen eigenen Check-in lokal samt Toasts und Kommentaren und
  /// merkt ihn für den Server vor.
  ///
  /// Einen eigenen Check-in korrigieren (Funktion 27).
  ///
  /// Wirkt sofort lokal und markiert die Zeile als [Checkins.dirty], damit
  /// der nächste Abgleich sie erneut überträgt. Das Bier selbst lässt sich
  /// bewusst nicht ändern — ein anderes Bier ist ein anderer Check-in.
  ///
  /// `null` als Wert heißt „nicht anfassen"; um ein Feld zu **leeren**,
  /// gibt es je einen expliziten Schalter. Ohne diese Unterscheidung
  /// könnte man eine Notiz nie wieder loswerden.
  Future<void> updateCheckinLocal(
    String checkinId, {
    double? rating,
    bool clearRating = false,
    String? note,
    bool clearNote = false,
    String? flavorTags,
    ServingStyle? servingStyle,
    bool clearServingStyle = false,
    int? volumeMl,
    bool clearVolume = false,
    String? venueName,
    String? venueId,
    bool clearVenue = false,
  }) async {
    await (update(checkins)..where((t) => t.id.equals(checkinId))).write(
      CheckinsCompanion(
        // Wie bei Notiz und Gebinde: `null` heißt „nicht anfassen",
        // gelöscht wird nur auf ausdrückliche Ansage. Ohne diese
        // Unterscheidung ließe sich eine versehentliche Bewertung nie
        // wieder zurücknehmen.
        rating: clearRating
            ? const Value(null)
            : (rating == null ? const Value.absent() : Value(rating)),
        note: clearNote
            ? const Value(null)
            : (note == null ? const Value.absent() : Value(note)),
        flavorTags:
            flavorTags == null ? const Value.absent() : Value(flavorTags),
        servingStyle: clearServingStyle
            ? const Value(null)
            : (servingStyle == null
                ? const Value.absent()
                : Value(servingStyle)),
        volumeMl: clearVolume
            ? const Value(null)
            : (volumeMl == null ? const Value.absent() : Value(volumeMl)),
        venueName: clearVenue
            ? const Value(null)
            : (venueName == null ? const Value.absent() : Value(venueName)),
        venueId: clearVenue
            ? const Value(null)
            : (venueId == null ? const Value.absent() : Value(venueId)),
        dirty: const Value(true),
      ),
    );
  }

  /// Nach erfolgreichem Upload: Die Zeile ist wieder deckungsgleich mit
  /// dem Server.
  Future<void> markCheckinsClean(Iterable<String> ids) async {
    if (ids.isEmpty) return;
    await (update(checkins)..where((t) => t.id.isIn(ids.toList())))
        .write(const CheckinsCompanion(dirty: Value(false)));
  }

  /// Der Aufrufer stellt sicher, dass es sich um einen eigenen Check-in
  /// handelt — die Server-Policy erzwingt es zusätzlich.
  Future<void> deleteCheckinLocal(
    String checkinId, {
    String? photoUrl,
    required DateTime now,
    bool queueForServer = true,
  }) async {
    await transaction(() async {
      await (delete(toasts)..where((t) => t.checkinId.equals(checkinId))).go();
      await (delete(comments)..where((t) => t.checkinId.equals(checkinId)))
          .go();
      await (delete(checkins)..where((t) => t.id.equals(checkinId))).go();
      if (queueForServer) {
        await into(checkinDeleteQueue).insert(
          CheckinDeleteQueueCompanion.insert(
            checkinId: checkinId,
            photoUrl: Value(photoUrl),
            createdAt: now,
          ),
        );
      }
    });
  }

  /// Wartende Löschungen in Erfassungsreihenfolge (FIFO).
  Future<List<CheckinDeleteQueueData>> pendingCheckinDeletes() =>
      (select(checkinDeleteQueue)..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();

  Future<void> deleteCheckinDeleteEntry(int id) async {
    await (delete(checkinDeleteQueue)..where((t) => t.id.equals(id))).go();
  }

  /// Nimmt eine Löschung zurück („Rückgängig"), solange sie noch nicht
  /// übertragen wurde. Der Check-in selbst wird vom Aufrufer wieder
  /// eingefügt; hier verschwindet nur der Auftrag.
  Future<void> cancelCheckinDelete(String checkinId) async {
    await (delete(checkinDeleteQueue)
          ..where((t) => t.checkinId.equals(checkinId)))
        .go();
  }

  /// Anzahl wartender Einträge (für Sync-Status-Anzeigen).
  Stream<int> watchPendingVenueEditCount() {
    final count = venueEditQueue.id.count();
    return (selectOnly(venueEditQueue)..addColumns([count]))
        .watchSingle()
        .map((row) => row.read(count) ?? 0);
  }

  /// Entfernt eine lokale Pseudo-Zeile (`local-…`) wieder, wenn der
  /// Server die Neuanlage fachlich ablehnt (z. B. Duplikat).
  Future<void> deleteVenueCacheRow(String id) async {
    await (delete(venues)..where((t) => t.id.equals(id))).go();
  }

  /// Ersetzt nach erfolgreicher Offline-Neuanlage die lokale Pseudo-ID
  /// (`local-…`) durch die echte Supabase-UUID – im Venue-Cache und in
  /// allen Check-in-/Session-Verweisen.
  Future<void> replaceLocalVenueId(String localId, String realId) =>
      transaction(() async {
        await (update(venues)..where((t) => t.id.equals(localId)))
            .write(VenuesCompanion(id: Value(realId)));
        await (update(checkins)..where((t) => t.venueId.equals(localId)))
            .write(CheckinsCompanion(venueId: Value(realId)));
        await (update(sessions)..where((t) => t.venueId.equals(localId)))
            .write(SessionsCompanion(venueId: Value(realId)));
      });

  // ---------------------------------------------------------------------
  // Challenges (Offline-Cache)
  // ---------------------------------------------------------------------

  Future<void> upsertChallengeCache(List<ChallengeCacheCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(challengeCache, rows));
  }

  Future<List<ChallengeCacheData>> allCachedChallenges() =>
      (select(challengeCache)
            ..orderBy([(t) => OrderingTerm.desc(t.endsAt)]))
          .get();

  Future<ChallengeCacheData?> challengeCacheById(String id) =>
      (select(challengeCache)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  /// Verdiente Challenge-Badges (Slug-Präfix `challenge-`).
  Future<List<UserBadge>> earnedChallengeBadges(String profileId) =>
      (select(userBadges)
            ..where((t) =>
                t.profileId.equals(profileId) &
                t.badgeSlug.like('challenge-%')))
          .get();

  Future<void> upsertCommunityData({
    required List<BreweriesCompanion> breweryRows,
    required List<BeersCompanion> beerRows,
  }) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(breweries, breweryRows);
      b.insertAllOnConflictUpdate(beers, beerRows);
    });
  }

  Future<Brewery> getOrCreateBrewery({
    required String id,
    required String name,
    required String country,
    required String city,
  }) async {
    final existing = await (select(breweries)
          ..where((t) => t.name.lower().equals(name.toLowerCase()))
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) return existing;
    final companion = BreweriesCompanion.insert(
        id: id, name: name, country: country, city: city);
    await into(breweries).insert(companion);
    return (select(breweries)..where((t) => t.id.equals(id))).getSingle();
  }

  // --------------------------------------------------------------------------
  // Wunschliste
  // --------------------------------------------------------------------------

  Stream<List<BeerWithBrewery>> watchWishlist(String profileId) {
    final query = select(wishlistItems).join([
      innerJoin(beers, beers.id.equalsExp(wishlistItems.beerId)),
      innerJoin(breweries, breweries.id.equalsExp(beers.breweryId)),
    ])
      ..where(wishlistItems.profileId.equals(profileId))
      ..orderBy([OrderingTerm.desc(wishlistItems.createdAt)]);
    return query.watch().map((rows) => rows
        .map((row) => BeerWithBrewery(
              beer: row.readTable(beers),
              brewery: row.readTable(breweries),
            ))
        .toList());
  }

  Stream<bool> watchOnWishlist(String profileId, String beerId) =>
      (select(wishlistItems)
            ..where((t) =>
                t.profileId.equals(profileId) & t.beerId.equals(beerId)))
          .watch()
          .map((rows) => rows.isNotEmpty);

  Future<void> toggleWishlist(
      String profileId, String beerId, DateTime now) async {
    final existing = await (select(wishlistItems)
          ..where(
              (t) => t.profileId.equals(profileId) & t.beerId.equals(beerId)))
        .get();
    if (existing.isEmpty) {
      await into(wishlistItems).insert(WishlistItemsCompanion.insert(
          profileId: profileId, beerId: beerId, createdAt: now));
    } else {
      await (delete(wishlistItems)
            ..where((t) =>
                t.profileId.equals(profileId) & t.beerId.equals(beerId)))
          .go();
    }
  }

  // --------------------------------------------------------------------------
  // Abzeichen
  // --------------------------------------------------------------------------

  Stream<List<UserBadge>> watchMyBadges(String profileId) =>
      (select(userBadges)..where((t) => t.profileId.equals(profileId)))
          .watch();

  /// Steht das Bier aktuell auf der Wunschliste? (Für den Server-Spiegel
  /// nach [toggleWishlist].)
  Future<bool> isWishlisted(String profileId, String beerId) async {
    final rows = await (select(wishlistItems)
          ..where(
              (t) => t.profileId.equals(profileId) & t.beerId.equals(beerId)))
        .get();
    return rows.isNotEmpty;
  }

  Future<Set<String>> earnedBadgeSlugs(String profileId) async {
    final rows = await (select(userBadges)
          ..where((t) => t.profileId.equals(profileId)))
        .get();
    return rows.map((b) => b.badgeSlug).toSet();
  }

  Future<void> awardBadge(
      String profileId, String slug, DateTime now) async {
    await into(userBadges).insert(
      UserBadgesCompanion.insert(
          profileId: profileId, badgeSlug: slug, awardedAt: now),
      mode: InsertMode.insertOrIgnore,
    );
  }

  // --------------------------------------------------------------------------
  // Statistiken
  // --------------------------------------------------------------------------

  Future<List<CheckinDetails>> myCheckinsDetailed(String profileId) async {
    final query = select(checkins).join([
      innerJoin(beers, beers.id.equalsExp(checkins.beerId)),
      innerJoin(breweries, breweries.id.equalsExp(beers.breweryId)),
      innerJoin(profiles, profiles.id.equalsExp(checkins.profileId)),
    ])
      ..where(checkins.profileId.equals(profileId))
      ..orderBy([OrderingTerm.desc(checkins.createdAt)]);
    final rows = await query.get();
    return rows
        .map((row) => CheckinDetails(
              checkin: row.readTable(checkins),
              beer: row.readTable(beers),
              brewery: row.readTable(breweries),
              author: row.readTable(profiles),
            ))
        .toList();
  }

  Stream<ProfileStats> watchProfileStats(String profileId) {
    // Bei jeder Check-in-/Session-/Badge-Änderung neu berechnen.
    final trigger = select(checkins).watch();
    return trigger.asyncMap((_) => computeProfileStats(profileId));
  }

  Future<ProfileStats> computeProfileStats(String profileId) async {
    final mine = await myCheckinsDetailed(profileId);
    final badgeCount = (await earnedBadgeSlugs(profileId)).length;
    return ProfileStats(
      uniqueBeers: mine.map((c) => c.beer.id).toSet().length,
      uniqueStyles: mine.map((c) => c.beer.style).toSet().length,
      uniqueBreweries: mine.map((c) => c.brewery.id).toSet().length,
      uniqueCountries: mine.map((c) => c.brewery.country).toSet().length,
      uniqueVenues: mine
          .map((c) => c.checkin.venueName)
          .whereType<String>()
          .toSet()
          .length,
      totalCheckins: mine.length,
      totalSessions: await countMySessions(profileId),
      badgeCount: badgeCount,
    );
  }
}
