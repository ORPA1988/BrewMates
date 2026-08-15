import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:brewmates/data/db/database.dart' as local;
import 'package:brewmates/data/online/online_service.dart';

/// Test-Doppel für [OnlineService].
///
/// **Warum es das gibt:** Bis 2026-08-15 überschrieben alle Tests den
/// `onlineServiceProvider` mit `null` — der Zweig „Konto vorhanden" war
/// damit vollständig ungetestet. Genau dort schlich sich zweimal derselbe
/// Fehler ein: eine Bedingung vor dem Serveraufruf, die immer griff, so
/// dass der Aufruf nie stattfand und die App trotzdem Erfolg meldete
/// (siehe `session_id_test.dart`). Kein Test konnte das bemerken, weil
/// nie ein Aufruf erwartet wurde.
///
/// [OnlineService] hängt fest am Supabase-Client, ist aber weder final
/// noch privat konstruiert — ableiten und die interessanten Methoden
/// überschreiben genügt. Der übergebene Client wird nie benutzt; die
/// Konstruktion allein stellt keine Verbindung her.
class FakeOnlineService extends OnlineService {
  FakeOnlineService()
      : super(SupabaseClient('http://localhost:1', 'test-anon-key'));

  /// Aufgezeichnete Aufrufe, in Reihenfolge — `methode:argument`.
  final List<String> aufrufe = [];

  /// Was der „Server" als laufende eigene Sessions führt.
  final List<String> aktiveSessionIds = [];

  /// Soll der nächste schreibende Aufruf scheitern?
  bool schlaegtFehl = false;

  /// Ein angemeldeter Nutzer muss vorgetäuscht werden: Die Provider
  /// prüfen `currentUser != null`, bevor sie überhaupt etwas versuchen.
  @override
  User? get currentUser => User(
        id: '11111111-1111-1111-1111-111111111111',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: DateTime(2026).toIso8601String(),
      );

  @override
  Future<bool> endSession(String sessionId) async {
    aufrufe.add('endSession:$sessionId');
    if (schlaegtFehl) return false;
    aktiveSessionIds.remove(sessionId);
    return true;
  }

  @override
  Future<bool> updateSessionExpiry(String sessionId, DateTime until) async {
    aufrufe.add('updateSessionExpiry:$sessionId');
    return !schlaegtFehl;
  }

  @override
  Future<List<String>> myActiveSessionIds() async {
    aufrufe.add('myActiveSessionIds');
    return List.of(aktiveSessionIds);
  }

  @override
  Future<bool> upsertSession(local.Session session, {String? crewId}) async {
    aufrufe.add('upsertSession:${session.id}');
    aktiveSessionIds.add(session.id);
    return true;
  }
}
