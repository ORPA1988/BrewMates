import '../models.dart';
import 'online_api.dart';

/// 👥 Crews: der Feed einer Gruppe und der Beitritt per sprechbarem Code.
///
/// **Warum der Crew-Feed keine neue Regel am Server brauchte:** Die
/// Sichtbarkeit stand seit 0001 in `checkins_select` — ein Check-in mit
/// `visibility = 'crew'`, der zu einer Runde dieser Crew gehört, ist für
/// jedes Mitglied lesbar. Gefehlt hat nur die Abfrage. Wer hier etwas
/// ändert, ändert also die **Anzeige**, nicht die Berechtigung; die
/// bleibt beim Server, wo sie hingehört.
class CrewsApi extends OnlineApi {
  const CrewsApi(super.client, super.nutzer);

  /// Check-ins, die während der Runden dieser Crew entstanden sind.
  ///
  /// `sessions!inner` ist kein Schmuck: Ohne den inneren Verbund kämen
  /// auch Check-ins ohne Runde zurück, und der Filter auf `crew_id` liefe
  /// ins Leere. Was am Ende sichtbar ist, entscheidet ohnehin die RLS —
  /// diese Abfrage fragt nur nach dem, was ohnehin erlaubt wäre.
  Future<List<RemoteCheckin>> crewCheckins(
    String crewId, {
    int limit = 50,
  }) async {
    if (currentUser == null) return const [];
    try {
      final rows = await client
          .from('checkins')
          .select('id, beer_name, brewery_name, beer_style, is_alcohol_free, '
              'rating, note, venue_name, session_id, photo_url, created_at, '
              'author:profiles!checkins_profile_id_fkey('
              '${OnlineApi.profileCols}), '
              'sessions!inner(crew_id)')
          .eq('sessions.crew_id', crewId)
          .order('created_at', ascending: false)
          .limit(limit);
      return [
        for (final r in rows) RemoteCheckin.fromRow(r),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Beitritt über den sechsstelligen Code (0041).
  ///
  /// Rückgabe: die Crew-ID, oder `null` wenn der Code nicht passt. Die
  /// Funktion am Server unterscheidet bewusst nicht zwischen „gibt es
  /// nicht" und „ging nicht" — alles Feinere wäre eine Auskunft über
  /// fremde Gruppen.
  Future<String?> joinByCode(String code) async {
    if (currentUser == null) return null;
    try {
      final id = await client.rpc('join_crew_by_code', params: {
        'p_code': code,
      });
      return id as String?;
    } catch (_) {
      return null;
    }
  }
}
