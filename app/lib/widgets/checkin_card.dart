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

  Future<void> _openComments(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CommentsSheet(checkinId: details.checkin.id),
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

    final toastCount =
        ref.watch(toastCountProvider(checkin.id)).valueOrNull ?? 0;
    final toasted =
        ref.watch(toastedByMeProvider(checkin.id)).valueOrNull ?? false;
    final commentCount =
        ref.watch(commentCountProvider(checkin.id)).valueOrNull ?? 0;

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

            // Fußzeile: Toast + Kommentare. Für Online-Einträge echter
            // Freunde (remote-…) gibt es lokal nichts zu zählen –
            // Interaktion darauf kommt mit einer späteren Beta.
            if (!checkin.id.startsWith('remote-'))
            Row(
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final earned =
                        await ref.read(actionsProvider).toggleToast(checkin.id);
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
                  onPressed: () async => _openComments(context),
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
