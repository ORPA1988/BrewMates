import '../../../domain/auszeichnung.dart';
import 'online_api.dart';

/// Eine verliehene Trophäe, wie sie der Server kennt.
class RemoteAuszeichnung {
  const RemoteAuszeichnung({
    required this.challengeId,
    required this.titel,
    required this.emoji,
    required this.art,
    required this.verliehenAm,
    required this.jahr,
    this.crewName,
  });

  final String challengeId;
  final String titel;
  final String emoji;
  final Auszeichnungsart art;
  final DateTime verliehenAm;

  /// Das Jahr, in dem die Challenge **endete** — nicht das der Verleihung.
  ///
  /// Der Unterschied zählt genau einmal im Jahr und dann sofort: „Bratapfel
  /// & Bock" läuft vom 1. Dezember bis zum 6. Jänner. Wer am 3. Jänner
  /// abschließt, bekäme sonst eine Trophäe mit der falschen Jahreszahl —
  /// und ein Jahr später stünde neben der 2027er eine zweite 2027er.
  final int jahr;

  /// Nur bei [Auszeichnungsart.besteCrew] gesetzt.
  final String? crewName;
}

/// Die Trophäen aus abgeschlossenen Challenges (Migration 0063).
///
/// Eigene Datei statt Anbau an den Kern: Der Bereich beantwortet keine
/// Frage über Challenges selbst, sondern über das, was jemand daraus
/// mitgenommen hat (Regel G, docs/11).
class AuszeichnungenApi extends OnlineApi {
  const AuszeichnungenApi(super.client, super.nutzer);

  /// Alle eigenen Auszeichnungen, neueste zuerst.
  ///
  /// Gibt eine leere Liste zurück, wenn niemand angemeldet ist oder der
  /// Abruf scheitert — die Abzeichen-Galerie bleibt dann vollständig, nur
  /// ohne Trophäen. Ein Fehler hier darf den Bildschirm nicht leeren.
  Future<List<RemoteAuszeichnung>> meine() async {
    final me = currentUser;
    if (me == null) return const [];
    try {
      final rows = await client
          .from('challenge_awards')
          .select('kind, awarded_at, '
              'challenges(id, title, emoji, ends_at), '
              'crews(name)')
          .eq('profile_id', me.id)
          .order('awarded_at', ascending: false);
      final out = <RemoteAuszeichnung>[];
      for (final row in (rows as List)) {
        final m = row as Map<String, dynamic>;
        final art = Auszeichnungsart.vomServer(m['kind'] as String?);
        final ch = m['challenges'] as Map<String, dynamic>?;
        // Eine Art, die neuer ist als die App, wird übersprungen statt
        // zum Absturz gebracht — dieselbe Regel wie bei den
        // Challenge-Regeln selbst.
        if (art == null || ch == null) continue;
        final endet = DateTime.tryParse(ch['ends_at'] as String? ?? '');
        final verliehen =
            DateTime.tryParse(m['awarded_at'] as String? ?? '') ??
                DateTime.now();
        out.add(RemoteAuszeichnung(
          challengeId: ch['id'] as String? ?? '',
          titel: ch['title'] as String? ?? 'Challenge',
          emoji: ch['emoji'] as String? ?? '🏆',
          art: art,
          verliehenAm: verliehen.toLocal(),
          jahr: (endet ?? verliehen).toLocal().year,
          crewName: (m['crews'] as Map<String, dynamic>?)?['name'] as String?,
        ));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}
