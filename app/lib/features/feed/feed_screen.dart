import 'package:flutter/material.dart';

import '../../data/demo_data.dart';
import '../../domain/models.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = DemoData.activeSessions();
    final checkins = DemoData.feed();

    return Scaffold(
      appBar: AppBar(title: const Text('BrewMates')),
      body: ListView(
        children: [
          if (sessions.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('Gerade unterwegs 🍻',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            SizedBox(
              height: 150,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final s in sessions) _ActiveSessionCard(session: s),
                ],
              ),
            ),
            const Divider(),
          ],
          for (final c in checkins) _CheckInCard(checkin: c),
        ],
      ),
    );
  }
}

class _ActiveSessionCard extends StatelessWidget {
  const _ActiveSessionCard({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () {}, // TODO: Session-Detail
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                      radius: 14,
                      child: Text(session.host.displayName[0])),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${session.host.displayName} @ ${session.venueName ?? '…'}',
                      style: Theme.of(context).textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (session.message != null) ...[
                const SizedBox(height: 4),
                Text(session.message!,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  children: [
                    FilledButton.tonal(
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                      child: const Text('Prost! 🍻'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                      child: const Text('Bin dabei!'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({required this.checkin});

  final CheckIn checkin;

  @override
  Widget build(BuildContext context) {
    final c = checkin;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(c.author.displayName[0])),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.author.displayName,
                          style: Theme.of(context).textTheme.titleSmall),
                      Text(
                        '${c.beer.name} · ${c.beer.brewery.name}'
                        '${c.venueName != null ? ' · 📍 ${c.venueName}' : ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (c.rating != null)
                  Chip(label: Text('⭐ ${c.rating!.toStringAsFixed(2)}')),
              ],
            ),
            if (c.note != null) ...[
              const SizedBox(height: 8),
              Text(c.note!),
            ],
            if (c.flavorTags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final t in c.flavorTags)
                    Chip(
                      label: Text(t),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {},
                  icon: const Text('🍻'),
                  label: const Text('Toast'),
                ),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Kommentar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
