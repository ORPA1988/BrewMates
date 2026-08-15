import 'db/database.dart';
import 'venue_queue.dart' show isConnectionError;

/// Spielt die Offline-Warteschlange gelöschter Check-ins FIFO ab.
///
/// Reihenfolge je Eintrag: erst der Server, dann das Foto. Ein verwaistes
/// Bild im Bucket ist harmloser als ein Check-in, dessen Bild schon weg
/// ist — deshalb nie umgekehrt.
///
/// - Erfolg → Eintrag löschen.
/// - Verbindungsfehler → Abbruch, der Rest bleibt für den nächsten Sync.
/// - Fachlicher Fehler (Zeile längst weg, fremder Check-in) → Eintrag
///   verwerfen, sonst blockiert er die Queue für immer.
///
/// Rückgabe: Anzahl erfolgreich übertragener Löschungen.
Future<int> replayCheckinDeleteQueue(
  AppDatabase db, {
  required Future<String?> Function(String checkinId) deleteRemote,
  required Future<void> Function(String photoUrl) deletePhoto,
}) async {
  final entries = await db.pendingCheckinDeletes();
  var replayed = 0;
  for (final entry in entries) {
    final error = await deleteRemote(entry.checkinId);
    if (error != null) {
      if (isConnectionError(error)) return replayed;
      await db.deleteCheckinDeleteEntry(entry.id);
      continue;
    }
    final photo = entry.photoUrl;
    if (photo != null && photo.isNotEmpty) {
      // Best effort: Ein Fehler beim Bild darf die Löschung nicht
      // wiederholen lassen – der Check-in ist bereits weg.
      try {
        await deletePhoto(photo);
      } catch (_) {}
    }
    await db.deleteCheckinDeleteEntry(entry.id);
    replayed++;
  }
  return replayed;
}
