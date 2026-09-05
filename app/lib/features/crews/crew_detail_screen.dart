import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/brewmates_code.dart';
import '../../core/format.dart' show timeAgo;
import '../../data/online/online_service.dart';
import '../../data/providers.dart';
import '../../widgets/rating_stars.dart';

/// Crew-Detail: Bilanz, Runden, Mitglieder, Einladung, Verlassen/Auflösen.
class CrewDetailScreen extends ConsumerWidget {
  const CrewDetailScreen({super.key, required this.crewId});

  final String crewId;

  Future<void> _leaveOrDelete(
      BuildContext context, WidgetRef ref, bool isOwner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isOwner ? 'Crew auflösen?' : 'Crew verlassen?'),
        content: Text(isOwner
            ? 'Die Crew wird für alle Mitglieder gelöscht.'
            : 'Du kannst später mit dem Einladungscode wieder beitreten.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isOwner ? 'Auflösen' : 'Verlassen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final online = await ref.read(onlineServiceProvider.future);
    if (online == null) return;
    final error = isOwner
        ? await online.deleteCrew(crewId)
        : await online.leaveCrew(crewId);
    ref.invalidate(myCrewsProvider);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    context.pop();
  }

  /// Freunde auswählen und einladen.
  ///
  /// Angeboten wird nur, wer noch nicht dabei ist und noch nicht wartet —
  /// eine Liste, die Einträge zeigt, die nicht gehen, ist keine Auswahl.
  Future<void> _freundeEinladen(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _EinladeListe(crewId: crewId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final crews = ref.watch(myCrewsProvider).valueOrNull ?? const [];
    RemoteCrew? crew;
    for (final c in crews) {
      if (c.id == crewId) crew = c;
    }
    final membersAsync = ref.watch(crewMembersProvider(crewId));
    final myUid = ref.watch(onlineUserProvider).valueOrNull?.id;
    final isOwner = crew != null && crew.ownerId == myUid;

    return Scaffold(
      appBar: AppBar(
          title: Text(
              crew == null ? 'Crew' : '${crew.emoji} ${crew.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Einladung: Code = Crew-UUID (bewusst kein Kontakte-Import).
          //
          // Der QR-Code steht oben, der getippte darunter — nicht
          // umgekehrt. Eine Crew entsteht am Tisch, und dort hält man
          // das Telefon hin, statt 36 Zeichen zu diktieren. Die UUID
          // bleibt trotzdem sichtbar und kopierbar: für Desktop, für die
          // Einladung per Nachricht und für alle ohne Kamera.
          Card(
            color: scheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Einladung', style: theme.textTheme.titleSmall),
                  if (crew?.joinCode != null) ...[
                    const SizedBox(height: 4),
                    // Der Code zum Vorlesen. Das ist der eine Fall, in
                    // dem weder Kamera noch Zwischenablage hilft: am
                    // Telefon, über den Tisch gerufen, auf einen
                    // Bierdeckel geschrieben.
                    Center(
                      child: SelectableText(
                        crew!.joinCode!,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontFamily: 'monospace',
                          letterSpacing: 4,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Center(
                      child: Text('zum Vorlesen',
                          style: theme.textTheme.labelSmall),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      // Weißer Grund unabhängig vom Farbschema: Ein
                      // QR-Code auf dunklem Hintergrund wird von vielen
                      // Kameras nicht erkannt.
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QrImageView(
                        data: buildCrewCode(crewId),
                        version: QrVersions.auto,
                        size: 200,
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Scannen lassen — wer den Code scannt, ist sofort '
                      'in der Crew.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const Divider(height: 24),
                  Text('Oder die lange Kennung schicken',
                      style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  SelectableText(crewId,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontFamily: 'monospace')),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Code kopieren'),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: crewId));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Code kopiert – schick ihn '
                                  'deiner Runde 🍻')));
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Der zweite Weg hinein: jemanden holen, statt ihm einen Code
          // zu geben. Für den Stammtisch, dessen Leute man längst als
          // Freunde hat.
          OutlinedButton.icon(
            icon: const Icon(Icons.person_add_alt, size: 18),
            label: const Text('Freunde einladen'),
            onPressed: () => _freundeEinladen(context, ref),
          ),
          const SizedBox(height: 16),
          _Bilanz(crewId: crewId),
          const SizedBox(height: 16),
          Text('Mitglieder', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          membersAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Fehler: $e'),
            data: (members) => members == null
                ? const Text('Mitglieder gerade nicht abrufbar (offline?).')
                : Column(
                    children: [
                      for (final m in members)
                        ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            child: Text(m.profile.avatarEmoji,
                                style: const TextStyle(fontSize: 16)),
                          ),
                          title: Text(m.profile.displayName),
                          subtitle: Text('@${m.profile.username}'),
                          // Rollen sichtbar machen — und dem Gründer die
                          // Handgriffe geben, die es dazu braucht (0061).
                          trailing: _mitgliedsAktionen(
                            context,
                            theme,
                            crewId: crewId,
                            rolle: m.role,
                            profil: m.profile,
                            binGruender: isOwner,
                            binVerwalter: isOwner ||
                                members.any((x) =>
                                    x.profile.id == myUid && x.role == 'admin'),
                          ),
                        ),
                      // Wer eingeladen ist, aber noch nicht geantwortet
                      // hat. Ohne diese Zeile lädt man ihn dreimal ein
                      // und wundert sich, warum nichts passiert.
                      for (final p in ref.watch(crewPendingProvider(crewId))
                              .valueOrNull ??
                          const <RemoteProfile>[])
                        ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: scheme.surfaceContainerHighest,
                            child: Text(p.avatarEmoji,
                                style: const TextStyle(fontSize: 16)),
                          ),
                          title: Text(p.displayName,
                              style: TextStyle(color: scheme.outline)),
                          subtitle: const Text('eingeladen, wartet noch'),
                          trailing: TextButton(
                            onPressed: () async {
                              final online = await ref
                                  .read(onlineServiceProvider.future);
                              await online?.crews.declineInvite(crewId,
                                  invitee: p.id);
                              ref.invalidate(crewPendingProvider(crewId));
                            },
                            child: const Text('Zurückziehen'),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          _CrewFeed(crewId: crewId),
          const SizedBox(height: 24),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            icon: Icon(
                isOwner ? Icons.delete_forever_outlined : Icons.logout,
                size: 18),
            label: Text(isOwner ? 'Crew auflösen' : 'Crew verlassen'),
            onPressed: () async => _leaveOrDelete(context, ref, isOwner),
          ),
          const SizedBox(height: 8),
          Text(
            'Startest du beim Zusammenkommen einen Crew-Beacon, sehen ihn '
            'nur Crew-Mitglieder — inklusive Standort und Check-ins der '
            'Runde.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Was in den Runden der Crew zusammengekommen ist.
///
/// Bewusst schmal: Biername, Stil, Bewertung und Autor sind alles, was
/// eine Feed-Zeile vom Server trägt. Füllmenge, Gebinde und Land fehlen
/// dort — sie zu schätzen wäre eine Zahl, die nach Messung aussieht.
/// Warum das so ist, steht in `domain/crew_stats.dart`.
class _Bilanz extends ConsumerWidget {
  const _Bilanz({required this.crewId});

  final String crewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bilanz = ref.watch(crewBilanzProvider(crewId));
    if (bilanz.leer) return const SizedBox.shrink();

    Widget zahl(String wert, String was) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(wert,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(was, style: theme.textTheme.labelSmall),
          ],
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📊 Bilanz der Crew', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                zahl('${bilanz.checkins}', 'Check-ins'),
                // Vielfalt vor Menge — dieselbe Haltung wie bei den
                // Abzeichen.
                zahl('${bilanz.biere}', 'Biere'),
                zahl('${bilanz.aktiveMitglieder}', 'dabei'),
                if (bilanz.schnitt != null)
                  zahl(
                    bilanz.schnitt!.toStringAsFixed(1).replaceAll('.', ','),
                    'Schnitt',
                  ),
              ],
            ),
            if (bilanz.topBier != null) ...[
              const SizedBox(height: 12),
              Text('Meistgetrunken: ${bilanz.topBier}',
                  style: theme.textTheme.bodySmall),
            ],
            if (bilanz.topStile.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final s in bilanz.topStile)
                    Chip(
                      label: Text('${s.stil} · ${s.anzahl}'),
                      labelStyle: theme.textTheme.labelSmall,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Was an einer Mitgliederzeile steht — und was man damit tun kann.
///
/// **Die Rechte prüft der Server** (`crew_members_update`,
/// `crew_members_delete` seit 0061). Was hier passiert, ist nur, die
/// Knöpfe wegzulassen, die ohnehin abgewiesen würden: Ein Knopf, der
/// nichts tut, ist schlimmer als keiner.
Widget? _mitgliedsAktionen(
  BuildContext context,
  ThemeData theme, {
  required String crewId,
  required String rolle,
  required RemoteProfile profil,
  required bool binGruender,
  required bool binVerwalter,
}) {
  final zeichen = switch (rolle) {
    'owner' => 'Gründer',
    'admin' => 'Verwalter',
    _ => null,
  };
  final chip = zeichen == null
      ? null
      : Chip(
          label: Text(zeichen),
          labelStyle: theme.textTheme.labelSmall,
          visualDensity: VisualDensity.compact,
        );

  // Am Gründer gibt es nichts zu tun: Er lässt sich weder entfernen noch
  // umstufen, und die Datenbank sagt dasselbe.
  if (rolle == 'owner' || !binVerwalter) return chip;

  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (chip != null) chip,
      Consumer(
        builder: (context, ref, _) => PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20),
          itemBuilder: (_) => [
            // Rollen vergibt nur der Gründer — ein Verwalter, der sich
            // weitere Verwalter machen könnte, wäre der neue Besitzer.
            if (binGruender)
              PopupMenuItem(
                value: rolle == 'admin' ? 'member' : 'admin',
                child: Text(rolle == 'admin'
                    ? 'Verwalterrolle nehmen'
                    : 'Zum Verwalter machen'),
              ),
            const PopupMenuItem(
              value: 'entfernen',
              child: Text('Aus der Crew entfernen'),
            ),
          ],
          onSelected: (wahl) async {
            final messenger = ScaffoldMessenger.of(context);
            final online = await ref.read(onlineServiceProvider.future);
            if (online == null) return;
            final ok = wahl == 'entfernen'
                ? await online.crews.removeMember(crewId, profil.id)
                : await online.crews.setRole(crewId, profil.id, wahl);
            messenger.showSnackBar(SnackBar(
              content: Text(ok
                  ? (wahl == 'entfernen'
                      ? '${profil.displayName} ist nicht mehr dabei.'
                      : 'Rolle geändert.')
                  : 'Hat nicht geklappt — keine Verbindung, oder du '
                      'darfst das nicht.'),
            ));
            if (ok) ref.invalidate(crewMembersProvider(crewId));
          },
        ),
      ),
    ],
  );
}

/// Die Runden der Crew: was ihre Mitglieder gemeinsam getrunken haben.
///
/// **Was hier drinsteht und was nicht.** Nur Check-ins aus Crew-Runden —
/// also solche, die während eines Beacons mit Sichtbarkeit „nur meine
/// Crew" entstanden sind. Das ist keine Entscheidung der Anzeige,
/// sondern die Regel des Servers (`checkins_select`, seit 0001): Was
/// jemand außerhalb einer Crew-Runde trinkt, geht die Crew nichts an.
class _CrewFeed extends ConsumerWidget {
  const _CrewFeed({required this.crewId});

  final String crewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final feed = ref.watch(crewCheckinsProvider(crewId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('🍻 Aus euren Runden', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        feed.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Fehler: $e'),
          data: (rows) => rows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Noch nichts. Startet beim Zusammenkommen einen Beacon '
                    'mit Sichtbarkeit „nur meine Crew" — was ihr dabei '
                    'trinkt, landet hier.',
                    style: theme.textTheme.bodySmall,
                  ),
                )
              : Column(
                  children: [
                    for (final c in rows)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 16,
                          child: Text(c.author.avatarEmoji,
                              style: const TextStyle(fontSize: 16)),
                        ),
                        title: Text(c.beerName),
                        subtitle: Text([
                          c.author.displayName,
                          if (c.breweryName != null) c.breweryName!,
                          timeAgo(c.createdAt),
                        ].join(' · ')),
                        trailing: c.rating == null
                            ? null
                            : RatingStars(rating: c.rating!, size: 14),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Freunde auswählen und einladen.
///
/// Es gibt keinen „Alle einladen"-Knopf. Eine Crew ist eine Runde, keine
/// Verteilerliste — und jede Einladung landet als Meldung bei einem
/// Menschen, der antworten muss.
class _EinladeListe extends ConsumerStatefulWidget {
  const _EinladeListe({required this.crewId});

  final String crewId;

  @override
  ConsumerState<_EinladeListe> createState() => _EinladeListeState();
}

class _EinladeListeState extends ConsumerState<_EinladeListe> {
  /// Wen wir gerade fragen — sperrt genau diese Zeile, nicht die Liste.
  final _laeuft = <String>{};

  Future<void> _einladen(RemoteProfile freund) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _laeuft.add(freund.id));
    final online = await ref.read(onlineServiceProvider.future);
    // `null` heißt hier „hat geklappt" — deshalb darf der abgemeldete
    // Fall nicht über `??` hineinrutschen, sonst sähe er wie Erfolg aus.
    final String? fehler = online == null
        ? 'Dafür musst du angemeldet sein.'
        : await online.crews.invite(widget.crewId, freund.id);
    // Auffrischen, damit der Eingeladene sofort unter „wartet noch"
    // steht und aus der Auswahl verschwindet.
    ref.invalidate(crewPendingProvider(widget.crewId));
    if (!mounted) return;
    setState(() => _laeuft.remove(freund.id));
    messenger.showSnackBar(SnackBar(
      content: Text(fehler ?? '${freund.displayName} ist eingeladen 👥'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final einladbar = ref.watch(crewEinladbarProvider(widget.crewId));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('👥 Freunde einladen', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Sie bekommen eine Einladung und entscheiden selbst. Wer '
              'dazukommt, sieht eure Crew-Runden — inklusive Standort.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (einladbar.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Niemand übrig — entweder sind alle deine BrewMates schon '
                  'dabei, oder sie wurden bereits eingeladen. Für alle '
                  'anderen gibt es den Einladungscode.',
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: einladbar.length,
                  itemBuilder: (_, i) {
                    final f = einladbar[i];
                    final laeuft = _laeuft.contains(f.id);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 16,
                        child: Text(f.avatarEmoji,
                            style: const TextStyle(fontSize: 16)),
                      ),
                      title: Text(f.displayName),
                      subtitle: Text('@${f.username}'),
                      trailing: laeuft
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : TextButton(
                              onPressed: () => _einladen(f),
                              child: const Text('Einladen'),
                            ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
