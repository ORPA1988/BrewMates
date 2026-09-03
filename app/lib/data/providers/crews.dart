part of '../providers.dart';

// ============================================================================
// 👥 Crew-Feed und Crew-Bilanz
// ============================================================================

/// Check-ins der Runden einer Crew.
///
/// `autoDispose`, weil die Liste an einen geöffneten Bildschirm gebunden
/// ist: Wer zehn Crews hat, soll nicht zehn Feeds im Speicher halten.
final crewCheckinsProvider =
    FutureProvider.autoDispose.family<List<RemoteCheckin>, String>(
  (ref, crewId) async {
    ref.watch(onlineUserProvider);
    // Beim Zurückkommen auf den Bildschirm neu holen — eine Runde kann
    // in der Zwischenzeit stattgefunden haben.
    ref.watch(_syncTickProvider);
    final online = await ref.watch(onlineServiceProvider.future);
    if (online == null) return const [];
    return online.crews.crewCheckins(crewId);
  },
);

/// Was in den Runden dieser Crew zusammengekommen ist.
///
/// Abgeleitet statt zweite Abfrage: Dieselben Zeilen, andere Sicht.
final crewBilanzProvider =
    Provider.autoDispose.family<CrewBilanz, String>((ref, crewId) {
  final rows =
      ref.watch(crewCheckinsProvider(crewId)).valueOrNull ?? const [];
  return berechneCrewBilanz([
    for (final c in rows)
      CrewCheckinFacts(
        authorId: c.author.id,
        beerName: c.beerName,
        beerStyle: c.beerStyle,
        rating: c.rating,
      ),
  ]);
});
