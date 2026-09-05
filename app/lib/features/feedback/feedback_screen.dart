import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/external_links.dart';
import '../../data/online/online_service.dart';
import '../../data/providers.dart';

/// Fehler melden oder Funktion wünschen — und sehen, was daraus wurde.
///
/// Testphase. Bewusst ein Formular mit **einem** Feld: Wer im Wirtshaus
/// einen Fehler sieht, tippt zwei Sätze, nicht ein Ticket. Version und
/// Plattform hängt die App selbst an. Unter dem Formular stehen die
/// eigenen Meldungen mit Status — das ist die Nachvollziehbarkeit.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key, this.initialKind = FeedbackKind.bug});

  final FeedbackKind initialKind;

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  late FeedbackKind _kind = widget.initialKind;
  final _text = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String get _platform {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name.toLowerCase();
  }

  Future<void> _senden() async {
    final online = await ref.read(onlineServiceProvider.future);
    if (online == null || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final fehler = await online.feedback.submit(
      kind: _kind,
      body: _text.text,
      appVersion: AppConfig.appVersion,
      platform: _platform,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (fehler != null) {
      // Regel A-8: kein Erfolg, der nicht stattfand.
      messenger.showSnackBar(SnackBar(content: Text(fehler)));
      return;
    }
    _text.clear();
    ref.invalidate(myFeedbackProvider);
    messenger.showSnackBar(SnackBar(
      content: Text(_kind == FeedbackKind.bug
          ? 'Danke – der Fehler ist gemeldet. Du siehst unten, was daraus wird.'
          : 'Danke – der Wunsch ist notiert. Du siehst unten, was daraus wird.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final angemeldet = ref.watch(onlineUserProvider).valueOrNull != null;
    final meine = ref.watch(myFeedbackProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Fehler & Wünsche')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<FeedbackKind>(
            segments: const [
              ButtonSegment(
                  value: FeedbackKind.bug,
                  icon: Icon(Icons.bug_report_outlined),
                  label: Text('Fehler')),
              ButtonSegment(
                  value: FeedbackKind.wish,
                  icon: Icon(Icons.lightbulb_outline),
                  label: Text('Wunsch')),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            enabled: angemeldet && !_busy,
            minLines: 3,
            maxLines: 8,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: _kind == FeedbackKind.bug
                  ? 'Was ist passiert – und was hast du erwartet?'
                  : 'Was soll BrewMates können?',
              hintText: _kind == FeedbackKind.bug
                  ? 'z. B. „Prost gedrückt, beim Gastgeber kam nichts an."'
                  : 'z. B. „Crew per QR-Code beitreten."',
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Version ${AppConfig.appVersion} · $_platform werden automatisch '
            'mitgeschickt. Deine Meldung erscheint anonym als öffentliches '
            'GitHub-Issue – ohne Namen und E-Mail. Bitte nichts Privates '
            'hineinschreiben.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 12),
          if (!angemeldet)
            Text('Zum Melden brauchst du ein Konto (Profil → Konto).',
                style: theme.textTheme.bodyMedium)
          else
            FilledButton.icon(
              onPressed: _busy ? null : _senden,
              icon: _busy
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              label: Text(_kind == FeedbackKind.bug
                  ? 'Fehler melden'
                  : 'Wunsch abschicken'),
            ),
          const SizedBox(height: 24),
          Text('Deine Meldungen', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          meine.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Text(
                'Konnte nicht laden – keine Verbindung? Später erneut versuchen.'),
            data: (liste) => liste.isEmpty
                ? Text('Noch keine. Alles, was du meldest, erscheint hier '
                    'mit Status.',
                    style: theme.textTheme.bodyMedium)
                : Column(
                    children: [for (final f in liste) _FeedbackTile(item: f)],
                  ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackTile extends StatelessWidget {
  const _FeedbackTile({required this.item});

  final FeedbackItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final datum = DateFormat('d. MMM', 'de').format(item.createdAt);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                    switch (item.kind) {
                      FeedbackKind.bug => Icons.bug_report_outlined,
                      FeedbackKind.wish => Icons.lightbulb_outline,
                      // Eine ergänzte Datenlücke ist keins von beidem:
                      // Sie steht hier, weil sie geprüft wird, nicht
                      // weil sie noch entschieden werden müsste.
                      FeedbackKind.data => Icons.fact_check_outlined,
                    },
                    size: 18),
                const SizedBox(width: 6),
                Text(datum, style: theme.textTheme.labelMedium),
                const Spacer(),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(item.statusLabel),
                  backgroundColor: item.status == FeedbackStatus.done
                      ? theme.colorScheme.primaryContainer
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(item.body),
            if (item.reply != null && item.reply!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Antwort: ${item.reply}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontStyle: FontStyle.italic)),
            ],
            if (item.roadmapTitle != null) ...[
              const SizedBox(height: 4),
              Text('→ Roadmap: ${item.roadmapTitle}',
                  style: theme.textTheme.bodySmall),
            ],
            if (item.githubIssue != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact),
                  onPressed: () => launchUrl(githubIssueUri(item.githubIssue!),
                      mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text('Auf GitHub ansehen (#${item.githubIssue})'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
