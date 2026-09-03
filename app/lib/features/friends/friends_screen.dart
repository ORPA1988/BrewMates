import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/online/online_service.dart';
import '../../data/providers.dart';

/// Echte Freunde (Online-Beta): Anfragen beantworten, Nutzer suchen,
/// Freundesliste ansehen.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _searchController = TextEditingController();
  List<RemoteProfile> _results = const [];
  bool _searching = false;

  /// Aktiver Kreis-Filter (null = alle).
  FriendTier? _tierFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final online = await ref.read(onlineServiceProvider.future);
    if (online == null || !mounted) return;
    if (query.trim().length < 3) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final results = await online.friends.searchProfiles(query);
    if (!mounted) return;
    // Nur übernehmen, wenn die Eingabe inzwischen nicht geändert wurde.
    if (_searchController.text.trim() == query.trim()) {
      setState(() {
        _results = results;
        _searching = false;
      });
    }
  }

  Future<void> _sendRequest(RemoteProfile profile) async {
    final online = await ref.read(onlineServiceProvider.future);
    if (online == null) return;
    final err = await online.friends.sendFriendRequest(profile.id);
    if (!mounted) return;
    // Damit die Anfrage sofort unter „Von dir angefragt" auftaucht —
    // sonst waere sie bis zum naechsten 30-Sekunden-Takt wieder unsichtbar,
    // also genau das Problem, das diese Liste behebt.
    if (err == null) ref.invalidate(outgoingRequestsProvider);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(err ?? 'Anfrage gesendet 🍻')));
  }

  /// Eine selbst gestellte Anfrage zuruecknehmen.
  Future<void> _zuruecknehmen(OutgoingRequest anfrage) async {
    final messenger = ScaffoldMessenger.of(context);
    final online = await ref.read(onlineServiceProvider.future);
    final ok =
        await online?.friends.withdrawRequest(anfrage.friendshipId) ?? false;
    if (!mounted) return;
    if (!ok) {
      // Regel aus A-8: keinen Erfolg behaupten, der nicht stattfand.
      messenger.showSnackBar(const SnackBar(
        content: Text('Hat nicht geklappt — vielleicht ist sie schon '
            'angenommen.'),
      ));
      return;
    }
    ref.invalidate(outgoingRequestsProvider);
    messenger.showSnackBar(
        const SnackBar(content: Text('Anfrage zurückgenommen.')));
  }

  Future<void> _annehmen(FriendRequest request) async {
    final online = await ref.read(onlineServiceProvider.future);
    if (online == null) return;
    final ok =
        await online.friends.respondRequest(request.friendshipId, accept: true);
    if (!mounted) return;
    if (!ok) {
      // Nicht invalidieren: Der Serverstand hat sich nicht geändert. Eine
      // verschwundene Anfrage, die in Wahrheit noch offen ist, wäre die
      // schlechtere Anzeige.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Hat nicht geklappt — keine Verbindung? '
            'Die Anfrage ist weiterhin offen.'),
      ));
      return;
    }
    ref.invalidate(friendRequestsProvider);
    ref.invalidate(onlineFriendsProvider);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Ihr seid jetzt Freunde! 🍻'),
    ));
  }

  /// Ablehnen mit Rückgängig-Frist — dieselbe Mechanik wie auf der
  /// Startseite (siehe [AbgelehnteAnfragen]), nur ein anderer Knopf.
  void _ablehnen(FriendRequest request) {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(abgelehnteAnfragenProvider.notifier);
    final id = request.friendshipId;

    unawaited(notifier.ablehnen(id).then((ok) {
      if (ok == false) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Hat nicht geklappt — keine Verbindung? '
              'Die Anfrage ist weiterhin offen.'),
        ));
      }
    }));

    messenger.showSnackBar(SnackBar(
      content: Text('Anfrage von ${request.from.displayName} abgelehnt.'),
      duration: rueckgaengigFrist,
      action: SnackBarAction(
        label: 'Rückgängig',
        onPressed: () => notifier.zuruecknehmen(id),
      ),
    ));
  }

  Future<void> _refresh() async {
    ref.invalidate(friendRequestsProvider);
    ref.invalidate(onlineFriendsProvider);
    ref.invalidate(blockedProfilesProvider);
    await Future.wait([
      ref.read(friendRequestsProvider.future),
      ref.read(onlineFriendsProvider.future),
      ref.read(blockedProfilesProvider.future),
    ]);
  }

  Future<void> _block(RemoteProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('@${profile.username} blockieren?'),
        content: const Text(
            'Ihr seht gegenseitig keine Check-ins, Sessions und Profile '
            'mehr; eine bestehende Freundschaft wird entfernt. Du kannst '
            'die Blockierung hier jederzeit aufheben.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Blockieren'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final online = await ref.read(onlineServiceProvider.future);
    if (online == null || !mounted) return;
    final err = await online.friends.blockProfile(profile.id);
    if (!mounted) return;
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? '@${profile.username} blockiert.')));
  }

  Future<void> _unblock(RemoteProfile profile) async {
    final online = await ref.read(onlineServiceProvider.future);
    if (online == null) return;
    final ok = await online.friends.unblockProfile(profile.id);
    if (!mounted) return;
    if (!ok) {
      // Blockieren ist eine Sicherheitsentscheidung. Wer glaubt, entsperrt
      // zu haben, es aber nicht ist, wundert sich später — und umgekehrt
      // wäre es noch schlimmer.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Hat nicht geklappt — keine Verbindung? '
            'Die Blockierung besteht weiterhin.'),
      ));
      return;
    }
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Blockierung von @${profile.username} aufgehoben.')));
  }

  Future<void> _report(RemoteProfile profile) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('@${profile.username} melden'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Was ist das Problem?',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Melden'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null) return;
    final online = await ref.read(onlineServiceProvider.future);
    if (online == null || !mounted) return;
    final err = await online.friends.reportProfile(profile.id, reason);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? 'Danke, wir schauen uns das an. 🕵️')));
  }

  /// „Wer sieht was" — die Kreise sind wertlos, wenn niemand weiß, was
  /// sie bewirken.
  Future<void> _showVisibilityTable() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final t = Theme.of(sheetContext);
        Widget row(String what, bool bekannter) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(child: Text(what, style: t.textTheme.bodyMedium)),
                  SizedBox(
                      width: 40,
                      child: Text(bekannter ? '✅' : '—',
                          textAlign: TextAlign.center)),
                  const SizedBox(
                      width: 40,
                      child: Text('✅', textAlign: TextAlign.center)),
                  const SizedBox(
                      width: 40,
                      child: Text('✅', textAlign: TextAlign.center)),
                ],
              ),
            );

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Wer sieht was von dir',
                    style: t.textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(child: SizedBox()),
                    SizedBox(
                        width: 40,
                        child: Text('👋', textAlign: TextAlign.center,
                            style: t.textTheme.titleMedium)),
                    SizedBox(
                        width: 40,
                        child: Text('🍺', textAlign: TextAlign.center,
                            style: t.textTheme.titleMedium)),
                    SizedBox(
                        width: 40,
                        child: Text('🍻', textAlign: TextAlign.center,
                            style: t.textTheme.titleMedium)),
                  ],
                ),
                const Divider(),
                row('Deine Check-ins im Feed', true),
                row('Dein Profil und deine Abzeichen', true),
                row('Deine Beacons auf der Karte', false),
                row('Wo du gerade bist', false),
                row('Deine Bierlaune', false),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Bekannte (👋) sehen nicht, dass du unterwegs bist — du '
                  'zählst für sie nur in der Zahl „weitere BrewMates '
                  'aktiv". Deine Einteilung bleibt privat: Niemand erfährt, '
                  'in welchem Kreis er steht.',
                  style: t.textTheme.bodySmall
                      ?.copyWith(color: t.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Kreis eines Freundes ändern.
  ///
  /// Die Einteilung ist einseitig und privat: Sie steuert nur, was der
  /// andere von MIR sieht, und er erfährt nie, wie ich ihn einsortiert
  /// habe. Alles andere wäre eine Kränkungsmaschine.
  Future<void> _pickTier(RemoteProfile friend) async {
    final chosen = await showModalBottomSheet<FriendTier>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(friend.displayName,
                  style: Theme.of(sheetContext).textTheme.titleMedium),
              subtitle: const Text(
                  'Was sieht diese Person von dir? Deine Wahl bleibt '
                  'privat.'),
            ),
            for (final t in FriendTier.values)
              ListTile(
                leading: Text(t.emoji, style: const TextStyle(fontSize: 22)),
                title: Text(t.label),
                subtitle: Text(t.description),
                trailing: friend.tier == t ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(sheetContext, t),
              ),
          ],
        ),
      ),
    );
    if (chosen == null || chosen == friend.tier) return;
    final online = await ref.read(onlineServiceProvider.future);
    if (online == null) return;
    final ok = await online.friends.setFriendTier(friend.id, chosen);
    if (!mounted) return;
    if (!ok) {
      // Kein Invalidieren: Die Liste zeigt weiter den Stand des Servers,
      // und der hat sich nicht geändert. Ein neu gezeichneter Kreis, den
      // niemand kennt, wäre schlimmer als gar keiner.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Kreis konnte nicht gespeichert werden — '
            'keine Verbindung? Bitte später nochmal.'),
      ));
      return;
    }
    ref.invalidate(onlineFriendsProvider);
    // Sichtbarkeit ändert sich sofort – abhängige Ansichten mitziehen.
    // Entwertet wird der ABRUF: `thirstyFriendsProvider` ist abgeleitet
    // und holt von sich aus nichts nach.
    ref.invalidate(thirstyFriendsAbrufProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${friend.displayName}: ${chosen.label}'),
    ));
  }

  /// Überlauf-Menü mit Melden/Blockieren – an Freunden wie Suchtreffern.
  Widget _moderationMenu(RemoteProfile profile) {
    return PopupMenuButton<String>(
      tooltip: 'Mehr',
      onSelected: (action) async {
        switch (action) {
          case 'report':
            await _report(profile);
          case 'block':
            await _block(profile);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'report', child: Text('Melden')),
        PopupMenuItem(value: 'block', child: Text('Blockieren')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final signedIn = ref.watch(isSignedInProvider);

    if (!signedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Freunde')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('👥', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(
                  'Melde dich an, um echte Freunde hinzuzufügen.',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.push('/account'),
                  child: const Text('Zum Konto'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final requests = ref.watch(offeneAnfragenProvider);
    final gestellt =
        ref.watch(outgoingRequestsProvider).valueOrNull ?? const [];
    final friends = ref.watch(onlineFriendsProvider).valueOrNull;
    final blocked =
        ref.watch(blockedProfilesProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Freunde'),
        actions: [
          IconButton(
            tooltip: 'Mein Code',
            icon: const Icon(Icons.qr_code_2),
            onPressed: () => context.push('/friends/code'),
          ),
          IconButton(
            tooltip: 'Code scannen',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => context.push('/friends/scan'),
          ),
          IconButton(
            tooltip: 'Crews (Gruppen)',
            icon: const Icon(Icons.groups_outlined),
            onPressed: () => context.push('/crews'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // 👥 Crews: fester Einstieg (Stammtisch & Co.).
            Card(
              child: ListTile(
                leading:
                    const Text('👥', style: TextStyle(fontSize: 24)),
                title: const Text('Crews'),
                subtitle: const Text(
                    'Stammtisch, Verein, WG – Beacons nur für die Gruppe'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/crews'),
              ),
            ),
            const SizedBox(height: 8),
            // ------------------------------------------------------------------
            // Anfragen
            // ------------------------------------------------------------------
            if (requests.isNotEmpty) ...[
              Text('Anfragen', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              for (final request in requests)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(request.from.avatarEmoji,
                          style: const TextStyle(fontSize: 20)),
                    ),
                    title: Text(request.from.displayName),
                    subtitle: Text('@${request.from.username}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Annehmen',
                          icon: Icon(Icons.check_circle,
                              color: scheme.primary),
                          onPressed: () => _annehmen(request),
                        ),
                        IconButton(
                          tooltip: 'Ablehnen',
                          icon: Icon(Icons.cancel_outlined,
                              color: scheme.error),
                          onPressed: () => _ablehnen(request),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],

            // ------------------------------------------------------------------
            // Von mir gestellt
            //
            // Diese Liste gab es nicht. Wer jemanden angefragt hatte, sah
            // danach nichts mehr — weder dass die Anfrage laeuft, noch
            // eine Moeglichkeit, sie zurueckzunehmen. Ein Fehlgriff war
            // damit endgueltig, und man konnte nur hoffen, dass der andere
            // ablehnt.
            // ------------------------------------------------------------------
            if (gestellt.isNotEmpty) ...[
              Text('Von dir angefragt', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              for (final anfrage in gestellt)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(anfrage.to.avatarEmoji,
                          style: const TextStyle(fontSize: 20)),
                    ),
                    title: Text(anfrage.to.displayName),
                    subtitle: const Text('wartet auf Antwort'),
                    trailing: TextButton(
                      onPressed: () async => _zuruecknehmen(anfrage),
                      child: const Text('Zurücknehmen'),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],

            // ------------------------------------------------------------------
            // Freund finden
            // ------------------------------------------------------------------
            Text('Freund finden', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Name oder Nutzername (min. 3 Zeichen)',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              onChanged: (value) async => _search(value),
            ),
            for (final profile in _results)
              ListTile(
                leading: CircleAvatar(
                  child: Text(profile.avatarEmoji,
                      style: const TextStyle(fontSize: 20)),
                ),
                title: Text(profile.displayName),
                subtitle: Text('@${profile.username}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () async => _sendRequest(profile),
                      child: const Text('+ Anfrage'),
                    ),
                    _moderationMenu(profile),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // ------------------------------------------------------------------
            // Deine Freunde
            // ------------------------------------------------------------------
            Row(
              children: [
                Expanded(
                  child: Text('Deine Freunde',
                      style: theme.textTheme.titleMedium),
                ),
                TextButton.icon(
                  onPressed: _showVisibilityTable,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Wer sieht was'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (friends == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (friends.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Noch keine Freunde – such oben nach ihren Nutzernamen! '
                  'Jeder Tester registriert sich einmal und ihr fügt euch '
                  'gegenseitig hinzu.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              )
            else ...[
              // Filter nach Kreis — erst ab einer Handvoll Freunde
              // sinnvoll, vorher nur Lärm.
              if (friends.length > 4)
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Alle'),
                      selected: _tierFilter == null,
                      onSelected: (_) => setState(() => _tierFilter = null),
                    ),
                    for (final t in FriendTier.values)
                      ChoiceChip(
                        label: Text('${t.emoji} ${t.label}'),
                        selected: _tierFilter == t,
                        onSelected: (_) => setState(() => _tierFilter = t),
                      ),
                  ],
                ),
              for (final friend in friends
                  .where((f) => _tierFilter == null || f.tier == _tierFilter))
                ListTile(
                  leading: CircleAvatar(
                    child: Text(friend.avatarEmoji,
                        style: const TextStyle(fontSize: 20)),
                  ),
                  title: Text(friend.displayName),
                  subtitle: Text('@${friend.username}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Der Kreis steht offen da — aber nur für einen
                      // selbst; der andere erfährt ihn nie.
                      TextButton(
                        onPressed: () => _pickTier(friend),
                        child: Text('${friend.tier.emoji} ${friend.tier.label}'),
                      ),
                      _moderationMenu(friend),
                    ],
                  ),
                ),
            ],

            // ------------------------------------------------------------------
            // Blockierte Nutzer (nur sichtbar, wenn es welche gibt)
            // ------------------------------------------------------------------
            if (blocked.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Blockiert', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              for (final profile in blocked)
                ListTile(
                  leading: CircleAvatar(
                    child: Text(profile.avatarEmoji,
                        style: const TextStyle(fontSize: 20)),
                  ),
                  title: Text(profile.displayName),
                  subtitle: Text('@${profile.username}'),
                  trailing: TextButton(
                    onPressed: () async => _unblock(profile),
                    child: const Text('Aufheben'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
