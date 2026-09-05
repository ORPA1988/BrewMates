import 'online_api.dart';

/// Zahlen über die Gemeinschaft — anonym und aggregiert.
///
/// Eigene Datei statt Anbau an `checkins_api.dart`: Der Bereich beantwortet
/// keine Frage über Check-ins, sondern eine über **alle anderen**, und er
/// wird als einziger von der Statistik gebraucht (Regel G, docs/11).
class StatsApi extends OnlineApi {
  const StatsApi(super.client, super.nutzer);

  /// Durchschnitt aller **anderen** BrewMates im Zeitraum
  /// [von] (einschließlich) bis [bis] (ausschließlich).
  ///
  /// `teilnehmer` sagt, wie viele beigetragen haben. Die Durchschnitte
  /// sind `null`, solange es zu wenige sind — das entscheidet der Server
  /// (Migration 0054), nicht die App: Eine Schwelle, die die Oberfläche
  /// zieht, ist keine.
  ///
  /// Gibt `null` zurück, wenn niemand angemeldet ist oder der Aufruf
  /// scheitert. Der Vergleich ist ein Zusatz; ohne ihn bleibt die
  /// Statistik vollständig.
  Future<({int teilnehmer, double? checkins, double? biere})?> community({
    required DateTime von,
    required DateTime bis,
  }) async {
    if (currentUser == null) return null;
    try {
      final rows = await client.rpc('community_stats', params: {
        'p_von': von.toUtc().toIso8601String(),
        'p_bis': bis.toUtc().toIso8601String(),
      });
      if (rows is! List || rows.isEmpty) return null;
      final row = rows.first as Map<String, dynamic>;
      return (
        teilnehmer: (row['teilnehmer'] as num?)?.toInt() ?? 0,
        checkins: (row['schnitt_checkins'] as num?)?.toDouble(),
        biere: (row['schnitt_biere'] as num?)?.toDouble(),
      );
    } catch (_) {
      // Ein fehlgeschlagener Vergleich darf die Statistik nicht leeren.
      return null;
    }
  }
}
