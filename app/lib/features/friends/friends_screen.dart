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
    final results = await online.searchProfiles(query);
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
    final err = await online.sendFriendRequest(profile.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(err ?? 'Anfrage gesendet 🍻')));
  }

  Future<void> _respond(FriendRequest request, {required bool accept}) async {
    final online = await ref.read(onlineServiceProvider.future);
    if (online == null) return;
    await online.respondRequest(request.friendshipId, accept: accept);
    if (!mounted) return;
    ref.invalidate(friendRequestsProvider);
    ref.invalidate(onlineFriendsProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(accept
          ? 'Ihr seid jetzt Freunde! 🍻'
          : 'Anfrage abgelehnt.'),
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
    final err = await online.blockProfile(profile.id);
    if (!mounted) return;
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? '@${profile.username} blockiert.')));
  }

  Future<void> _unblock(RemoteProfile profile) async {
    final online = await ref.read(onlineServiceProvider.future);
    if (online == null) return;
    await online.unblockProfile(profile.id);
    if (!mounted) return;
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
    final err = await online.reportProfile(profile.id, reason);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? 'Danke, wir schauen uns das an. 🕵️')));
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

    final requests =
        ref.watch(friendRequestsProvider).valueOrNull ?? const [];
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
                          onPressed: () async =>
                              _respond(request, accept: true),
                        ),
                        IconButton(
                          tooltip: 'Ablehnen',
                          icon: Icon(Icons.cancel_outlined,
                              color: scheme.error),
                          onPressed: () async =>
                              _respond(request, accept: false),
                        ),
                      ],
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
            Text('Deine Freunde', style: theme.textTheme.titleMedium),
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
            else
              for (final friend in friends)
                ListTile(
                  leading: CircleAvatar(
                    child: Text(friend.avatarEmoji,
                        style: const TextStyle(fontSize: 20)),
                  ),
                  title: Text(friend.displayName),
                  subtitle: Text('@${friend.username}'),
                  trailing: _moderationMenu(friend),
                ),

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
