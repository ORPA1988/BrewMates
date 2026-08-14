import 'dart:convert';

import 'db/database.dart';

/// Schlüssel im Payload einer Offline-Neuanlage: verweist auf die lokale
/// Pseudo-Zeile (`local-…`) im Venue-Cache, die nach erfolgreichem Upload
/// durch die echte Supabase-UUID ersetzt wird.
const venueQueueLocalIdKey = '_local_id';

/// OnlineService-Fehlermeldungen beginnen bei Netzproblemen einheitlich
/// mit „Keine Verbindung" – alles andere ist ein fachlicher Fehler.
bool isConnectionError(String message) =>
    message.startsWith('Keine Verbindung');

/// Spielt die Offline-Warteschlange der Gasthaus-Änderungen FIFO ab.
///
/// - Erfolg → Eintrag löschen (bei Neuanlagen zusätzlich die lokale
///   Pseudo-ID im Cache und in Check-in-/Session-Verweisen ersetzen).
/// - Verbindungsfehler → Abbruch, der Rest bleibt für den nächsten Sync.
/// - Fachlicher Fehler (Duplikat, Vertrauensstufe, …) → Eintrag verwerfen,
///   sonst würde er die Queue für immer blockieren (Last-write-wins).
///
/// Rückgabe: Anzahl erfolgreich übertragener Einträge.
Future<int> replayVenueQueue(
  AppDatabase db, {
  required Future<(String?, String?)> Function(Map<String, dynamic> payload)
      create,
  required Future<String?> Function(String id, Map<String, dynamic> patch)
      update,
}) async {
  final entries = await db.pendingVenueEdits();
  var replayed = 0;
  for (final entry in entries) {
    Map<String, dynamic> payload;
    try {
      payload = (jsonDecode(entry.payloadJson) as Map).cast<String, dynamic>();
    } catch (_) {
      // Unlesbarer Eintrag: verwerfen statt die Queue zu blockieren.
      await db.deleteVenueEdit(entry.id);
      continue;
    }
    if (entry.venueId == null) {
      // Neuanlage
      final localId = payload.remove(venueQueueLocalIdKey) as String?;
      final (realId, error) = await create(payload);
      if (error != null) {
        if (isConnectionError(error)) return replayed;
        await db.deleteVenueEdit(entry.id);
        if (localId != null) await db.deleteVenueCacheRow(localId);
        continue;
      }
      if (realId != null && localId != null) {
        await db.replaceLocalVenueId(localId, realId);
      }
      await db.deleteVenueEdit(entry.id);
      replayed++;
    } else {
      // Änderung an bestehendem Gasthaus
      final error = await update(entry.venueId!, payload);
      if (error != null) {
        if (isConnectionError(error)) return replayed;
        await db.deleteVenueEdit(entry.id);
        continue;
      }
      await db.deleteVenueEdit(entry.id);
      replayed++;
    }
  }
  return replayed;
}
