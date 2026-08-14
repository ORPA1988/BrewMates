import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'db/database.dart';

/// Ergebnis eines Cloud-Restores (für Log/Tests). `complete` = alle drei
/// Abrufe haben geantwortet (false ⇒ offline, später erneut versuchen).
typedef RestoreSummary = ({
  int checkins,
  int badges,
  int wishlist,
  bool complete,
});

const _noRestore =
    (checkins: 0, badges: 0, wishlist: 0, complete: false);

/// Holt eigene Check-ins, Erfolge und Wunschliste aus der Cloud zurück und
/// vereinigt sie mit dem lokalen Bestand (Union — es wird nie gelöscht).
/// Läuft nach Neuinstallation/Gerätewechsel einmal pro Anmeldung; alle
/// Schritte sind idempotent (insertOrIgnore bzw. Server-Upsert).
///
/// Die Callbacks kapseln OnlineService (null = offline → Schritt wird
/// still übersprungen und beim nächsten Lauf nachgeholt).
Future<RestoreSummary> restoreFromCloud(
  AppDatabase db, {
  required Future<List<Map<String, dynamic>>?> Function() fetchCheckins,
  required Future<Map<String, DateTime>?> Function() fetchBadges,
  required Future<bool> Function(Map<String, DateTime> badges) pushBadges,
  required Future<Map<String, DateTime>?> Function() fetchWishlist,
  required Future<void> Function(String beerKey) pushWishlistItem,
}) async {
  final me = await (db.select(db.profiles)
        ..where((t) => t.isMe.equals(true))
        ..limit(1))
      .getSingleOrNull();
  if (me == null) return _noRestore;

  // ── Check-ins ─────────────────────────────────────────────────────────
  var restoredCheckins = 0;
  final remote = await fetchCheckins();
  if (remote != null && remote.isNotEmpty) {
    final localIds = {
      for (final c in await db.select(db.checkins).get()) c.id,
    };
    for (final r in remote) {
      final id = r['id'] as String?;
      final createdAt = r['created_at'] as String?;
      if (id == null || createdAt == null || localIds.contains(id)) continue;
      final beerId = await _resolveBeerId(db, r);
      await db.into(db.checkins).insert(
            CheckinsCompanion.insert(
              id: id,
              profileId: me.id,
              beerId: beerId,
              venueId: Value(r['venue_id'] as String?),
              venueName: Value(r['venue_name'] as String?),
              rating: Value((r['rating'] as num?)?.toDouble()),
              note: Value(r['note'] as String?),
              flavorTags: Value(_csvTags(r['flavor_tags'])),
              servingStyle: Value(_servingStyle(r['serving_style'])),
              photoUrl: Value(r['photo_url'] as String?),
              createdAt: DateTime.parse(createdAt).toUtc(),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      restoredCheckins++;
    }
  }

  // ── Erfolge (Union in beide Richtungen) ───────────────────────────────
  var restoredBadges = 0;
  final remoteBadges = await fetchBadges();
  if (remoteBadges != null) {
    final localRows = await (db.select(db.userBadges)
          ..where((t) => t.profileId.equals(me.id)))
        .get();
    final localSlugs = {for (final b in localRows) b.badgeSlug};
    for (final e in remoteBadges.entries) {
      if (localSlugs.contains(e.key)) continue;
      await db.awardBadge(me.id, e.key, e.value);
      restoredBadges++;
    }
    final missingRemote = {
      for (final b in localRows)
        if (!remoteBadges.containsKey(b.badgeSlug))
          b.badgeSlug: b.awardedAt.toUtc(),
    };
    if (missingRemote.isNotEmpty) await pushBadges(missingRemote);
  }

  // ── Wunschliste (Union; Remote-Einträge nur, wenn das Bier lokal
  //    existiert — Community-IDs sind über Installationen stabil) ────────
  var restoredWishlist = 0;
  final remoteWishlist = await fetchWishlist();
  if (remoteWishlist != null) {
    final localItems = await (db.select(db.wishlistItems)
          ..where((t) => t.profileId.equals(me.id)))
        .get();
    final localKeys = {for (final w in localItems) w.beerId};
    for (final e in remoteWishlist.entries) {
      if (localKeys.contains(e.key)) continue;
      final beer = await (db.select(db.beers)
            ..where((t) => t.id.equals(e.key)))
          .getSingleOrNull();
      if (beer == null) continue;
      await db.into(db.wishlistItems).insert(
            WishlistItemsCompanion.insert(
                profileId: me.id, beerId: e.key, createdAt: e.value),
            mode: InsertMode.insertOrIgnore,
          );
      restoredWishlist++;
    }
    for (final w in localItems) {
      if (!remoteWishlist.containsKey(w.beerId)) {
        await pushWishlistItem(w.beerId);
      }
    }
  }

  return (
    checkins: restoredCheckins,
    badges: restoredBadges,
    wishlist: restoredWishlist,
    complete:
        remote != null && remoteBadges != null && remoteWishlist != null,
  );
}

/// Bier eines Remote-Check-ins der lokalen DB zuordnen: Treffer über
/// Name (+ Brauerei bei Mehrdeutigkeit), sonst als nutzererstelltes Bier
/// samt Brauerei neu anlegen.
Future<String> _resolveBeerId(AppDatabase db, Map<String, dynamic> r) async {
  final name = ((r['beer_name'] as String?) ?? 'Unbekanntes Bier').trim();
  final breweryName = (r['brewery_name'] as String?)?.trim();

  final candidates = await (db.select(db.beers)
        ..where((t) => t.name.lower().equals(name.toLowerCase())))
      .get();
  if (candidates.isNotEmpty) {
    if (breweryName != null && breweryName.isNotEmpty && candidates.length > 1) {
      for (final beer in candidates) {
        final brewery = await (db.select(db.breweries)
              ..where((t) => t.id.equals(beer.breweryId)))
            .getSingleOrNull();
        if (brewery != null &&
            brewery.name.toLowerCase() == breweryName.toLowerCase()) {
          return beer.id;
        }
      }
    }
    return candidates.first.id;
  }

  const uuid = Uuid();
  final brewery = await db.getOrCreateBrewery(
    id: uuid.v4(),
    name: (breweryName == null || breweryName.isEmpty)
        ? 'Unbekannte Brauerei'
        : breweryName,
    country: '',
    city: '',
  );
  final style = (r['beer_style'] as String?)?.trim();
  final beerId = uuid.v4();
  await db.into(db.beers).insert(BeersCompanion.insert(
        id: beerId,
        breweryId: brewery.id,
        name: name,
        style: (style == null || style.isEmpty) ? 'Unbekannt' : style,
        isAlcoholFree: Value((r['is_alcohol_free'] as bool?) ?? false),
        isUserSubmitted: const Value(true),
      ));
  return beerId;
}

/// PostgREST liefert text[] als Liste → lokale CSV-Spalte.
String _csvTags(Object? raw) => raw is List
    ? raw.map((t) => t.toString().trim()).where((t) => t.isNotEmpty).join(',')
    : '';

ServingStyle? _servingStyle(Object? raw) {
  if (raw is! String) return null;
  for (final s in ServingStyle.values) {
    if (s.name == raw) return s;
  }
  return null;
}
