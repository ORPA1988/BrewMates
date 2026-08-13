import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../seed.dart';

part 'database.g.dart';

// ============================================================================
// Enums (Spiegel des Supabase-Schemas, docs/04-datenmodell.md)
// ============================================================================

enum SessionVisibility { friends, crew, private }

enum SessionStatus { active, ended }

enum ServingStyle { draft, bottle, can, growler }

enum ParticipantKind { joined, toast }

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

  /// Etikett-/Produktfoto als URL (Open Food Facts, CC-BY-SA – nur verlinkt).
  TextColumn get imageUrl => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Sessions extends Table {
  TextColumn get id => text()();
  TextColumn get hostId => text().references(Profiles, #id)();
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
  TextColumn get venueName => text().nullable()();
  RealColumn get rating => real().nullable()();
  TextColumn get note => text().nullable()();

  /// Kommagetrennt, z. B. "hopfig,fruchtig".
  TextColumn get flavorTags => text().withDefault(const Constant(''))();
  TextColumn get servingStyle => textEnum<ServingStyle>().nullable()();
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
  Sessions,
  SessionParticipants,
  Checkins,
  Toasts,
  Comments,
  UserBadges,
  WishlistItems,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.open() : super(_openConnection());

  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 4;

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
        },
      );

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, 'brewmates.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }

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

  Stream<List<CheckinDetails>> watchFeed({String? onlyProfileId}) {
    final query = select(checkins).join([
      innerJoin(beers, beers.id.equalsExp(checkins.beerId)),
      innerJoin(breweries, breweries.id.equalsExp(beers.breweryId)),
      innerJoin(profiles, profiles.id.equalsExp(checkins.profileId)),
    ])
      ..orderBy([OrderingTerm.desc(checkins.createdAt)]);
    if (onlyProfileId != null) {
      query.where(checkins.profileId.equals(onlyProfileId));
    }
    return query.watch().map((rows) => rows
        .map((row) => CheckinDetails(
              checkin: row.readTable(checkins),
              beer: row.readTable(beers),
              brewery: row.readTable(breweries),
              author: row.readTable(profiles),
            ))
        .toList());
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

  Future<void> endSession(String id, DateTime now) async {
    await (update(sessions)..where((t) => t.id.equals(id))).write(
      SessionsCompanion(
        status: const Value(SessionStatus.ended),
        endedAt: Value(now),
      ),
    );
  }

  Future<void> joinSession(
      String sessionId, String profileId, ParticipantKind kind) async {
    await into(sessionParticipants).insert(
      SessionParticipantsCompanion.insert(
        sessionId: sessionId,
        profileId: profileId,
        kind: kind,
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

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
