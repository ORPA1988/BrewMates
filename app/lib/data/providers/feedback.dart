part of '../providers.dart';

/// Testphasen-Schalter aus `app_config`. Ohne Netz oder abgeschaltet:
/// Die drei Knöpfe auf der Startseite erscheinen schlicht nicht.
final feedbackEnabledProvider = FutureProvider<bool>((ref) async {
  ref.watch(clockProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null) return false;
  return online.feedback.enabled();
});

/// Eigene Meldungen mit Status — die Nachvollziehbarkeit, die der Tester
/// verlangt hat: „Was ist aus meinem Hinweis geworden?"
final myFeedbackProvider = FutureProvider<List<FeedbackItem>>((ref) async {
  ref.watch(onlineUserProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null) return const [];
  return online.feedback.mine();
});

/// Roadmap in Laiensprache. Für alle lesbar, auch ohne Konto.
final roadmapProvider = FutureProvider<List<RoadmapItem>>((ref) async {
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null) return const [];
  return online.feedback.roadmap();
});

/// Wer auf dem Server zu **meiner** Session „Prost" oder „Bin dabei"
/// gesagt hat. Die lokale Datenbank kennt nur lokale Teilnehmer — genau
/// deshalb wirkten beide Knöpfe für den Gastgeber funktionslos.
final remoteParticipantsProvider = FutureProvider.autoDispose
    .family<List<RemoteParticipant>, String>((ref, sessionId) async {
  ref.watch(clockProvider);
  // Eine eingehende Benachrichtigung (Prost/Dabei) lädt sofort nach.
  ref.watch(incomingNotificationsProvider);
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null || online.currentUser == null) return const [];
  // `stripRemote`, weil fremde Sessions hier mit `remote-` ankommen. Ohne
  // das fragte die Abfrage nach einer ID, die es am Server nicht gibt —
  // für eigene Sessions fiel es nie auf, weil die keinen Präfix tragen.
  return online.sessions.participantsOf(stripRemote(sessionId));
});
