part of '../providers.dart';

// ============================================================================
// Moderation: gemeldete Profile bearbeiten (Migration 0040)
// ============================================================================

/// Ab dieser Vertrauensstufe gibt es den Moderationsbereich.
///
/// 4 = Moderator, 5 = Admin (Migration 0013). Die Zahl steht hier, weil
/// die Oberfläche nur **spiegelt**: Durchgesetzt wird die Regel am Server
/// (`is_moderator` in RLS-Policy und RPC). Wer sie hier umgeht, sieht eine
/// leere Liste.
const moderationMinLevel = 4;

/// Darf ich moderieren? `false` auch offline und abgemeldet.
final canModerateProvider = Provider<bool>((ref) {
  final level = ref.watch(accountLevelProvider).valueOrNull?.level ?? 0;
  return level >= moderationMinLevel;
});

/// Welcher Stapel gerade angezeigt wird: `open`, `resolved`, `dismissed`
/// oder `null` für alles.
final moderationFilterProvider = StateProvider<String?>((ref) => 'open');

/// Die Meldungen zum gewählten Stapel.
final moderationReportsProvider =
    FutureProvider<List<ModerationReport>>((ref) async {
  ref.watch(onlineUserProvider);
  if (!ref.watch(canModerateProvider)) return const [];
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null) return const [];
  return online.moderation.reports(status: ref.watch(moderationFilterProvider));
});

/// Wie viele Meldungen offen sind — für den Hinweis im Admin-Bereich.
///
/// Eigener Provider statt `moderationReportsProvider.length`: Der zeigt
/// den gerade gewählten Stapel, und der kann „erledigt" sein. Ein Zähler,
/// der sich beim Umschalten eines Filters ändert, ist kein Zähler.
final offeneMeldungenProvider = FutureProvider<int>((ref) async {
  ref.watch(onlineUserProvider);
  if (!ref.watch(canModerateProvider)) return 0;
  final online = await ref.watch(onlineServiceProvider.future);
  if (online == null) return 0;
  return (await online.moderation.reports(status: 'open')).length;
});
