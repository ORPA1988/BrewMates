import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../widgets/checkin_card.dart';
import '../../widgets/session_card.dart';

/// Startbildschirm: die zwei Hero-Aktionen der App —
/// „🍺 Bier scannen" und „🍻 Zusammenkommen!" — plus ein kompakter
/// Blick auf aktive Sessions und die letzte Aktivität.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mySession = ref.watch(myActiveSessionProvider).valueOrNull;
    final sessions = ref.watch(activeSessionsProvider).valueOrNull ??
        const <SessionDetails>[];
    final feed =
        ref.watch(feedProvider).valueOrNull ?? const <CheckinDetails>[];
    // Persönliche Begrüßung, sobald das Online-Profil da ist —
    // offline/abgemeldet bleibt es beim App-Namen.
    final profile = ref.watch(myRemoteProfileProvider).valueOrNull;
    final title = profile == null
        ? 'BrewMates'
        : 'Servus, ${profile.displayName}! ${profile.avatarEmoji}';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ------------------------------------------------------------------
          // Hero-Aktionen
          // ------------------------------------------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _HeroCard(
              emoji: '🍺',
              title: 'Bier scannen',
              subtitle:
                  'Barcode scannen, bewerten, ins Tagebuch – in Sekunden.',
              onTap: () => context.push('/scan'),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: mySession == null
                ? _HeroCard(
                    emoji: '🍻',
                    title: 'Zusammenkommen!',
                    subtitle:
                        'Ein Tap: Freunde sehen, wo du bist – alle willkommen.',
                    onTap: () => context.push('/beacon'),
                  )
                : _ActiveBeaconCard(session: mySession),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () => context.push('/checkin'),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Ohne Scannen einchecken'),
            ),
          ),

          // ------------------------------------------------------------------
          // Gerade unterwegs
          // ------------------------------------------------------------------
          if (sessions.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('Gerade unterwegs 🍻',
                  style: theme.textTheme.titleMedium),
            ),
            SizedBox(
              height: 150,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (final s in sessions) SessionCard(details: s),
                ],
              ),
            ),
          ],

          // ------------------------------------------------------------------
          // Letzte Aktivität
          // ------------------------------------------------------------------
          if (feed.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Letzte Aktivität',
                        style: theme.textTheme.titleMedium),
                  ),
                  TextButton(
                    onPressed: () => context.go('/feed'),
                    child: const Text('Mehr im Feed'),
                  ),
                ],
              ),
            ),
            for (final details in feed.take(3)) CheckinCard(details: details),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 44)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ersetzt die Beacon-Hero-Karte, solange die eigene Session läuft.
class _ActiveBeaconCard extends ConsumerWidget {
  const _ActiveBeaconCard({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.tertiaryContainer,
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/session/${session.id}'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Text('📡', style: TextStyle(fontSize: 44)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dein Beacon läuft',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${session.venueName ?? 'Unterwegs'} · '
                      'endet in ${remaining(session.expiresAt)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => ref.read(actionsProvider).endMySession(),
                child: const Text('Beenden'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
