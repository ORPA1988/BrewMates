part of '../providers.dart';

// Trophäen aus abgeschlossenen Challenges (Migration 0063)
//
// Eigene Datei statt Anbau an `challenges.dart` (Regel G, docs/11): Der
// Bereich beantwortet keine Frage über laufende Challenges, sondern über
// das, was jemand daraus mitgenommen hat.

/// Die eigenen Trophäen, neueste zuerst.
///
/// **Der Rang kommt vom Server, die Teilnahme kann auch das Gerät wissen.**
///
/// „Blitzschluck" braucht den Vergleich mit allen anderen, „Beste Crew" und
/// „Schlusslicht" sogar das Ende der Challenge — ein Gerät kann das nicht
/// wissen, und ein lokal geratener Rang wäre eine Behauptung.
///
/// Was das Gerät sehr wohl weiß: **dass es abgeschlossen hat.** Für jede
/// lokal verdiente Challenge-Trophäe, zu der der Server (noch) nichts
/// liefert, steht deshalb ein „Dabei gewesen" in Bronze. Das ist keine
/// Schätzung, sondern genau die Aussage, die der lokale Eintrag deckt.
///
/// Ohne diesen Rückfall wäre die Zeile offline leer, wo bis 0.10.27
/// Trophäen standen — ein Bildschirm, der ohne Netz weniger zeigt als
/// vorher, ist eine Verschlechterung, auch wenn er ehrlicher aussieht.
final meineAuszeichnungenProvider =
    FutureProvider<List<RemoteAuszeichnung>>((ref) async {
  // Nach einem Challenge-Abschluss soll die Trophäe ohne App-Neustart da
  // sein: `myBadgesProvider` schlägt aus, sobald sich Abzeichen ändern.
  ref.watch(myBadgesProvider);
  ref.watch(onlineUserProvider);

  final online = await ref.watch(onlineServiceProvider.future);
  final vomServer =
      online == null ? const <RemoteAuszeichnung>[] : await online.auszeichnungen.meine();

  // Lokale Abschlüsse, zu denen der Server nichts sagt.
  final me = await ref.watch(meProvider.future);
  final db = ref.watch(databaseProvider);
  final lokal = await db.earnedChallengeBadges(me.id);
  if (lokal.isEmpty) return vomServer;

  final bekannt = vomServer.map((a) => a.challengeId).toSet();
  final cache = await db.allCachedChallenges();
  final ergaenzt = <RemoteAuszeichnung>[];
  for (final zeile in lokal) {
    final idPrefix = zeile.badgeSlug.substring('challenge-'.length);
    final treffer = cache.where((c) => c.id.startsWith(idPrefix)).firstOrNull;
    if (treffer != null && bekannt.contains(treffer.id)) continue;
    ergaenzt.add(RemoteAuszeichnung(
      challengeId: treffer?.id ?? idPrefix,
      titel: treffer?.title ?? 'Challenge',
      emoji: treffer?.emoji ?? '🏆',
      art: Auszeichnungsart.dabei,
      verliehenAm: zeile.awardedAt,
      // Das Jahr des Challenge-ENDES, nicht der Verleihung: „Bratapfel &
      // Bock" endet am 6. Jänner, wer am 3. abschließt, bekäme sonst die
      // falsche Zahl im Sockel. Ohne Cache-Treffer bleibt nur die
      // Verleihung.
      jahr: (treffer?.endsAt ?? zeile.awardedAt).year,
    ));
  }
  return [...vomServer, ...ergaenzt]
    ..sort((a, b) => b.verliehenAm.compareTo(a.verliehenAm));
});
