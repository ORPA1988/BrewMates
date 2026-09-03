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

/// 👥 Einladungen, die auf meine Antwort warten (0044).
final crewInvitesProvider = FutureProvider<List<CrewInvite>>((ref) async {
  ref.watch(onlineUserProvider);
  ref.watch(_syncTickProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null) return const [];
  return online.crews.myInvites();
});

/// Wer in dieser Crew noch aussteht.
final crewPendingProvider =
    FutureProvider.autoDispose.family<List<RemoteProfile>, String>(
  (ref, crewId) async {
    ref.watch(onlineUserProvider);
    final online = await ref.watch(onlineServiceProvider.future);
    if (online == null) return const [];
    return online.crews.pendingFor(crewId);
  },
);

/// Freunde, die man in diese Crew noch einladen kann.
///
/// Ohne diesen Filter stünden Mitglieder und bereits Eingeladene in der
/// Auswahl — und ein Tipp darauf endete in „Die Einladung steht schon".
/// Eine Liste, die Einträge anbietet, die nicht gehen, ist keine Auswahl.
final crewEinladbarProvider =
    Provider.autoDispose.family<List<RemoteProfile>, String>((ref, crewId) {
  final freunde = ref.watch(onlineFriendsProvider).valueOrNull ?? const [];
  final mitglieder =
      ref.watch(crewMembersProvider(crewId)).valueOrNull ?? const [];
  final offen = ref.watch(crewPendingProvider(crewId)).valueOrNull ?? const [];
  final schon = {
    for (final m in mitglieder) m.profile.id,
    for (final p in offen) p.id,
  };
  return [
    for (final f in freunde)
      if (!schon.contains(f.id)) f,
  ];
});

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
