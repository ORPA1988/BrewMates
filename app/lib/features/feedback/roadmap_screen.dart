import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/external_links.dart';
import '../../data/online/online_service.dart';
import '../../data/providers.dart';

/// Roadmap für Menschen, nicht für Entwickler.
///
/// Drei Gruppen — in Arbeit, geplant, fertig — mit je einem Satz, was sich
/// für den Nutzer ändert. Keine Migrationsnummern, keine Dateinamen. Die
/// Texte pflegt das Team in `roadmap_items`; die App zeigt sie nur.
class RoadmapScreen extends ConsumerWidget {
  const RoadmapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final roadmap = ref.watch(roadmapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Was kommt als Nächstes'),
        actions: [
          IconButton(
            tooltip: 'Wunsch äußern',
            icon: const Icon(Icons.lightbulb_outline),
            onPressed: () => context.push('/feedback?art=wish'),
          ),
        ],
      ),
      body: roadmap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const _Hinweis(
            'Die Roadmap konnte nicht geladen werden – keine Verbindung?'),
        data: (items) {
          if (items.isEmpty) {
            return const _Hinweis('Noch keine Einträge.');
          }
          Widget gruppe(String titel, RoadmapStatus status, String leer) {
            final teil = [for (final i in items) if (i.status == status) i];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(titel, style: theme.textTheme.titleMedium),
                ),
                if (teil.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(leer, style: theme.textTheme.bodySmall),
                  ),
                for (final i in teil)
                  ListTile(
                    leading: Text(i.statusEmoji,
                        style: const TextStyle(fontSize: 22)),
                    title: Text(i.title),
                    subtitle: Text(i.summary),
                    isThreeLine: true,
                    // Details und Diskussion liegen auf GitHub — lesen geht
                    // ohne Konto.
                    trailing: i.githubIssue == null
                        ? null
                        : const Icon(Icons.open_in_new, size: 18),
                    onTap: i.githubIssue == null
                        ? null
                        : () => launchUrl(githubIssueUri(i.githubIssue!),
                            mode: LaunchMode.externalApplication),
                  ),
              ],
            );
          }

          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  'BrewMates ist in der Testphase. Hier siehst du, woran '
                  'gerade gearbeitet wird – in Alltagssprache. Fehlt dir '
                  'etwas? Oben rechts kannst du es dir wünschen.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              gruppe('🔧 In Arbeit', RoadmapStatus.inProgress,
                  'Gerade nichts in Arbeit.'),
              gruppe('🗓️ Geplant', RoadmapStatus.planned, 'Nichts geplant.'),
              gruppe('✅ Fertig', RoadmapStatus.done, 'Noch nichts fertig.'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: OutlinedButton.icon(
                  onPressed: () => launchUrl(githubRoadmapUri(),
                      mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Alle Details und Diskussion auf GitHub'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _Hinweis extends StatelessWidget {
  const _Hinweis(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
}
