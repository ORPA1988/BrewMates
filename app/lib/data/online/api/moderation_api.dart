import '../models.dart';
import 'online_api.dart';

/// Gemeldete Profile ansehen und abschließen — für Moderatoren und Admins.
///
/// **Warum die Liste über eine RPC kommt und nicht über `reports`:** Die
/// Liste braucht Namen, und `profiles_select` gibt private Profile
/// niemandem heraus — auch keinem Moderator, und das bleibt so. Ein
/// breiteres Leserecht wäre ein Dauerrecht auf jedes private Profil der
/// App für einen Einzelfall. `moderation_reports()` (Migration 0040) gibt
/// stattdessen genau die Namen heraus, die an einer Meldung hängen.
class ModerationApi extends OnlineApi {
  const ModerationApi(super.client, super.nutzer);

  /// Meldungen mit dem gegebenen Status; `null` = alle.
  ///
  /// Leere Liste heißt „nichts zu tun" **oder** „keine Rolle dafür" — die
  /// Funktion am Server prüft das selbst und schweigt sonst. Der Aufrufer
  /// entscheidet über die Vertrauensstufe, ob er die Liste überhaupt
  /// anzeigt.
  Future<List<ModerationReport>> reports({String? status = 'open'}) async {
    if (currentUser == null) return const [];
    try {
      final rows = await client.rpc(
        'moderation_reports',
        params: {'p_status': status},
      );
      if (rows is! List) return const [];
      return [
        for (final r in rows)
          ModerationReport.fromRow(r as Map<String, dynamic>),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Meldung abschließen (`resolved`), verwerfen (`dismissed`) oder wieder
  /// öffnen (`open`).
  ///
  /// Gibt zurück, ob der Server es übernommen hat. Ein `false` ist keine
  /// Formalie: Wer glaubt, eine Meldung bearbeitet zu haben, sieht nicht
  /// mehr nach.
  Future<bool> resolve(
    String reportId, {
    required String status,
    String? note,
  }) async {
    if (currentUser == null) return false;
    try {
      final ok = await client.rpc('resolve_report', params: {
        'p_report': reportId,
        'p_status': status,
        'p_note': note,
      });
      return ok == true;
    } catch (_) {
      return false;
    }
  }
}
