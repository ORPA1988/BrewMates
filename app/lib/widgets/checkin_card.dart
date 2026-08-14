import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../data/db/database.dart';
import '../data/providers.dart';
import 'badge_celebration.dart';
import 'rating_stars.dart';

/// Die zentrale Feed-Karte: ein Check-in mit Bier, Bewertung, Notiz,
/// Geschmacks-Tags sowie Toast- und Kommentar-Aktionen.
class CheckinCard extends ConsumerWidget {
  const CheckinCard({super.key, required this.details, this.showAuthor = true});

  final CheckinDetails details;
  final bool showAuthor;

  String _servingStyleLabel(ServingStyle style) => switch (style) {
        ServingStyle.draft => 'vom Fass',
        ServingStyle.bottle => 'Flasche',
        ServingStyle.can => 'Dose',
        ServingStyle.growler => 'Growler',
      };

  Future<void> _openComments(BuildContext context,
      {String? serverId}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => serverId != null
          ? _RemoteCommentsSheet(serverId: serverId)
          : _CommentsSheet(checkinId: details.checkin.id),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkin = details.checkin;
    final beer = details.beer;
    final brewery = details.brewery;
    final author = details.author;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Reaktionen: Für hochgeladene Check-ins (eigene wie Freunde) zählt
    // der Server – so sind auch Toasts/Kommentare der Freunde sichtbar.
    // Offline/abgemeldet: lokale Zähler wie bisher.
    final serverId = serverCheckinId(checkin.id);
    final serverEntry = serverId == null
        ? null
        : ref.watch(feedReactionsProvider).valueOrNull?[serverId];

    final toastCount = serverEntry?.toasts ??
        (ref.watch(toastCountProvider(checkin.id)).valueOrNull ?? 0);
    final toasted = serverEntry?.toastedByMe ??
        (ref.watch(toastedByMeProvider(checkin.id)).valueOrNull ?? false);
    final commentCount = serverEntry?.comments ??
        (ref.watch(commentCountProvider(checkin.id)).valueOrNull ?? 0);

    final flavorTags = checkin.flavorTags
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kopfzeile: Autor + Zeit (oder nur Zeit).
            if (showAuthor)
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    child: Text(author.avatarEmoji,
                        style: const TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      author.displayName,
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    timeAgo(checkin.createdAt),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  timeAgo(checkin.createdAt),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 8),

            // Bier-Zeile.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => context.push('/beer/${beer.id}'),
                        child: Text(
                          beer.name,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        '${brewery.name} · ${beer.style}'
                        '${beer.abv != null ? ' · ${beer.abv} %' : ''}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (beer.isAlcoholFree) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('💧 alkoholfrei',
                        style: theme.textTheme.labelSmall),
                  ),
                ],
              ],
            ),
            if (checkin.venueName != null) ...[
              const SizedBox(height: 4),
              Text(
                '📍 ${checkin.venueName}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],

            // Bewertung.
            if (checkin.rating != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  RatingStars(rating: checkin.rating!),
                  const SizedBox(width: 6),
                  Text(
                    checkin.rating!.toStringAsFixed(2),
                    style: theme.textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],

            // Foto (öffentliche URL aus dem beer-photos-Bucket).
            if (checkin.photoUrl != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  checkin.photoUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) =>
                      progress == null
                          ? child
                          : Container(
                              height: 200,
                              alignment: Alignment.center,
                              color: scheme.surfaceContainerHighest,
                              child: const CircularProgressIndicator(),
                            ),
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],

            // Notiz.
            if (checkin.note != null) ...[
              const SizedBox(height: 8),
              Text(checkin.note!),
            ],

            // Geschmacks-Tags.
            if (flavorTags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: -8,
                children: [
                  for (final tag in flavorTags)
                    Chip(
                      label: Text(tag),
                      labelStyle: theme.textTheme.labelSmall,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ],

            // Ausschankart.
            if (checkin.servingStyle != null) ...[
              const SizedBox(height: 4),
              Text(
                '🍺 ${_servingStyleLabel(checkin.servingStyle!)}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],

            const SizedBox(height: 4),

            // Fußzeile: Toast + Kommentare. Hochgeladene Check-ins laufen
            // über den Server (Reaktionen der Freunde inklusive); rein
            // lokale Einträge (Demo/Seed) über die lokalen Tabellen.
            // Remote-Einträge ohne Server-Stand (offline) bleiben ohne
            // Fußzeile.
            if (serverEntry != null || !checkin.id.startsWith('remote-'))
            Row(
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final actions = ref.read(actionsProvider);
                    final earned = serverEntry != null
                        ? await actions.toggleServerToast(
                            checkin.id, serverId!, on: !toasted)
                        : await actions.toggleToast(checkin.id);
                    if (context.mounted) {
                      await showBadgeCelebration(context, earned);
                    }
                  },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor:
                        toasted ? scheme.primary : scheme.onSurfaceVariant,
                    backgroundColor:
                        toasted ? scheme.primaryContainer : null,
                  ),
                  icon: const Text('🍻', style: TextStyle(fontSize: 16)),
                  label: Text(
                    '$toastCount',
                    style: TextStyle(
                      fontWeight:
                          toasted ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () async => _openComments(context,
                      serverId: serverEntry != null ? serverId : null),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: scheme.onSurfaceVariant,
                  ),
                  icon: const Text('💬', style: TextStyle(fontSize: 16)),
                  label: Text('$commentCount'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom-Sheet für Kommentare auf hochgeladenen Check-ins: Liste und
/// Eingabe laufen direkt gegen den Server (Freunde sehen sie sofort).
class _RemoteCommentsSheet extends ConsumerStatefulWidget {
  const _RemoteCommentsSheet({required this.serverId});

  final String serverId;

  @override
  ConsumerState<_RemoteCommentsSheet> createState() =>
      _RemoteCommentsSheetState();
}

class _RemoteCommentsSheetState extends ConsumerState<_RemoteCommentsSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final error = await ref
        .read(actionsProvider)
        .addServerComment(widget.serverId, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comments = ref.watch(remoteCommentsProvider(widget.serverId));

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Kommentare', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Flexible(
              child: comments.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Fehler beim Laden: $e'),
                ),
                data: (list) => (list == null || list.isEmpty)
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          list == null
                              ? 'Kommentare sind gerade nicht erreichbar '
                                  '(offline?).'
                              : 'Noch keine Kommentare – sei die erste '
                                  'Stimme 🍻',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final entry = list[index];
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              child: Text(entry.author.avatarEmoji,
                                  style: const TextStyle(fontSize: 16)),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.author.displayName,
                                    style: theme.textTheme.titleSmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  timeAgo(entry.createdAt),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme
                                          .colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                            subtitle: Text(entry.body),
                          );
                        },
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Kommentar schreiben …',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) async => _send(),
                    ),
                  ),
                  IconButton(
                    onPressed: _sending ? null : () async => _send(),
                    icon: const Icon(Icons.send),
                    tooltip: 'Senden',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom-Sheet mit Kommentarliste und Eingabefeld.
class _CommentsSheet extends ConsumerStatefulWidget {
  const _CommentsSheet({required this.checkinId});

  final String checkinId;

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await ref.read(actionsProvider).addComment(widget.checkinId, text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comments = ref.watch(commentsProvider(widget.checkinId));

    return Padding(
      // Hebt das Sheet über die Tastatur.
      padding:
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Kommentare', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Flexible(
              child: comments.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Fehler beim Laden: $e'),
                ),
                data: (list) => list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Noch keine Kommentare – sei die erste Stimme 🍻',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final (comment, profile) = list[index];
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              child: Text(profile.avatarEmoji,
                                  style: const TextStyle(fontSize: 16)),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    profile.displayName,
                                    style: theme.textTheme.titleSmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  timeAgo(comment.createdAt),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                            subtitle: Text(comment.body),
                          );
                        },
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Kommentar schreiben …',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) async => _send(),
                    ),
                  ),
                  IconButton(
                    onPressed: () async => _send(),
                    icon: const Icon(Icons.send),
                    tooltip: 'Senden',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
