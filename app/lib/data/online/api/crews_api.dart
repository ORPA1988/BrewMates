import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException;

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
      // Über `checkin_crews` (0051), nicht mehr über `sessions.crew_id`.
      //
      // Der alte Weg fand nur Runden, die **ausdrücklich als Crew-Runde**
      // gestartet wurden — also eine Crew je Abend, und nur wenn jemand
      // daran gedacht hatte. Jetzt zählt jede Runde für jede Crew, aus der
      // jemand dabei war, und zwar so, wie es **damals** war: Die Tabelle
      // ist eine Momentaufnahme, kein Rechenergebnis. Ein Austritt lässt
      // die Bilanz vergangener Abende unangetastet.
      final rows = await client
          .from('checkins')
          .select('id, beer_name, brewery_name, beer_style, is_alcohol_free, '
              'rating, note, venue_name, session_id, photo_url, created_at, '
              'author:profiles!checkins_profile_id_fkey('
              '${OnlineApi.profileCols}), '
              'checkin_crews!inner(crew_id)')
          .eq('checkin_crews.crew_id', crewId)
          .order('created_at', ascending: false)
          .limit(limit);
      return [
        for (final r in rows) RemoteCheckin.fromRow(r),
      ];
    } catch (_) {
      return const [];
    }
  }

  // --------------------------------------------------------------------------
  // Einladungen (0044)
  //
  // Anders als der Code brauchen sie eine Antwort — die Begründung steht
  // in der Migration und in [CrewInvite]. Hier steht nur, wie es geht.
  // --------------------------------------------------------------------------

  /// Einen Freund in eine Crew einladen.
  ///
  /// Rückgabe: `null` bei Erfolg, sonst ein Satz für den Menschen. Die
  /// Regeln stehen am Server (nur Mitglieder, nur Freunde, nur im eigenen
  /// Namen); hier wird nur übersetzt, was er sagt.
  /// Jemanden zum Verwalter machen oder zurückstufen (0061).
  ///
  /// Darf nur der Gründer — die Regel steht in `crew_members_update` und
  /// wird hier nicht nachgebaut: Ein Client, der sie kennt, ist kein
  /// Schutz, und ein zweiter Client kennte sie nicht.
  ///
  /// `true` heißt: Der Server hat es übernommen. Trifft das Update keine
  /// Zeile — weil die Regel es nicht zulässt —, kommt `false` zurück
  /// statt eines stillen Erfolgs (Regel A).
  Future<bool> setRole(String crewId, String profileId, String role) async {
    if (currentUser == null) return false;
    try {
      final rows = await client
          .from('crew_members')
          .update({'role': role})
          .eq('crew_id', crewId)
          .eq('profile_id', profileId)
          .select('role');
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Ein Mitglied aus der Crew entfernen.
  ///
  /// Erlaubt für Gründer und Verwalter; den Gründer selbst entfernt
  /// niemand (0061). Wie oben: Was der Server nicht bestätigt, gilt
  /// nicht als getan.
  Future<bool> removeMember(String crewId, String profileId) async {
    if (currentUser == null) return false;
    try {
      final rows = await client
          .from('crew_members')
          .delete()
          .eq('crew_id', crewId)
          .eq('profile_id', profileId)
          .select('profile_id');
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<String?> invite(String crewId, String profileId) async {
    final me = currentUser;
    if (me == null) return 'Dafür musst du angemeldet sein.';
    try {
      await client.from('crew_invites').insert({
        'crew_id': crewId,
        'invitee_id': profileId,
        'inviter_id': me.id,
      });
      return null;
    } on PostgrestException catch (e) {
      // 23505 = schon eingeladen. Das ist kein Fehler, über den man
      // stolpern muss — die Einladung steht ja bereits.
      if (e.code == '23505') return 'Die Einladung steht schon.';
      return 'Einladen hat nicht geklappt.';
    } catch (_) {
      return 'Keine Verbindung.';
    }
  }

  /// Einladungen, die auf **meine** Antwort warten.
  Future<List<CrewInvite>> myInvites() async {
    final me = currentUser;
    if (me == null) return const [];
    try {
      final rows = await client
          .from('crew_invites')
          .select('crew_id, created_at, '
              'crew:crews!crew_invites_crew_id_fkey(name, emoji), '
              'inviter:profiles!crew_invites_inviter_id_fkey('
              '${OnlineApi.profileCols})')
          .eq('invitee_id', me.id)
          .order('created_at', ascending: false);
      return [for (final r in rows) CrewInvite.fromRow(r)];
    } catch (_) {
      return const [];
    }
  }

  /// Wer in dieser Crew noch aussteht — für die Mitgliederliste.
  Future<List<RemoteProfile>> pendingFor(String crewId) async {
    if (currentUser == null) return const [];
    try {
      final rows = await client
          .from('crew_invites')
          .select('invitee:profiles!crew_invites_invitee_id_fkey('
              '${OnlineApi.profileCols})')
          .eq('crew_id', crewId);
      return [
        for (final r in rows)
          RemoteProfile.fromRow(r['invitee'] as Map<String, dynamic>),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Einladung annehmen: eintragen **und** die Einladung wegräumen.
  ///
  /// Zwei Schritte, weil es zwei Dinge sind — und in dieser Reihenfolge:
  /// Bliebe die Einladung nach einem Fehlschlag beim Eintragen liegen,
  /// könnte man es erneut versuchen. Andersherum wäre sie weg und die
  /// Mitgliedschaft nicht da.
  Future<bool> acceptInvite(String crewId) async {
    final me = currentUser;
    if (me == null) return false;
    try {
      await client.from('crew_members').insert({
        'crew_id': crewId,
        'profile_id': me.id,
      });
      await declineInvite(crewId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Einladung ablehnen — oder als Crew zurückziehen.
  Future<bool> declineInvite(String crewId, {String? invitee}) async {
    final me = currentUser;
    if (me == null) return false;
    try {
      await client
          .from('crew_invites')
          .delete()
          .eq('crew_id', crewId)
          .eq('invitee_id', invitee ?? me.id);
      return true;
    } catch (_) {
      return false;
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
