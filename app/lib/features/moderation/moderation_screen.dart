import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart' show formatDate, timeAgo;
import '../../data/online/online_service.dart';
import '../../data/providers.dart';

/// 🛡 Meldungen: die Arbeitsliste der Moderatoren.
///
/// Melden gab es seit 0009 — bearbeiten nicht. Die Zeile lag in `reports`,
/// der Meldende sah sie in seiner eigenen Liste, und danach passierte
/// nichts. Eine Meldung, die niemand ansieht, ist ein Versprechen, das die
/// App nicht hält.
///
/// **Was dieser Bildschirm bewusst nicht kann:** den Gemeldeten sperren,
/// löschen oder verstecken. Nicht aus Zurückhaltung, sondern aus
/// Reihenfolge — erst muss jemand die Meldungen sehen und beantworten
/// können. Welche Maßnahmen es braucht, zeigt der erste echte Fall; heute
/// gibt es keinen. Eine Maßnahme auf Vorrat wäre eine Vermutung mit
/// Löschrechten.
class ModerationScreen extends ConsumerWidget {
  const ModerationScreen({super.key});

  static const _stapel = <(String?, String)>[
    ('open', 'Offen'),
    ('resolved', 'Erledigt'),
    ('dismissed', 'Verworfen'),
    (null, 'Alle'),
  ];

  Future<void> _abschliessen(
    BuildContext context,
    WidgetRef ref,
    ModerationReport report,
    String status,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final notiz = await _fragNachBefund(context, report, status);
    if (notiz == null) return; // abgebrochen

    final online = await ref.read(onlineServiceProvider.future);
    final ok = await online?.moderation.resolve(
          report.id,
          status: status,
          note: notiz.isEmpty ? null : notiz,
        ) ??
        false;
    ref.invalidate(moderationReportsProvider);
    ref.invalidate(offeneMeldungenProvider);

    // Regel A-8: kein Erfolg, den der Server nicht bestätigt hat.
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? (status == 'open'
              ? 'Wieder offen.'
              : 'Meldung ${status == 'resolved' ? 'erledigt' : 'verworfen'}.')
          : 'Hat nicht geklappt — keine Verbindung? Die Meldung ist '
              'unverändert.'),
    ));
  }

  /// Der Befund ist freiwillig, die Rückfrage nicht: Ein Klick, der eine
  /// Meldung ohne ein Wort schließt, macht später niemandem klar, warum.
  /// Leerer Text ist erlaubt — abbrechen gibt `null`.
  Future<String?> _fragNachBefund(
    BuildContext context,
    ModerationReport report,
    String status,
  ) async {
    if (status == 'open') return '';
    final controller = TextEditingController(text: report.note ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(status == 'resolved'
            ? 'Meldung erledigen'
            : 'Meldung verwerfen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(status == 'resolved'
                ? 'Was wurde unternommen?'
                : 'Warum ist nichts zu tun?'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText: 'Kurzer Befund (freiwillig)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sichtbar nur für Moderatoren — weder für den Meldenden noch '
              'für den Gemeldeten.',
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(status == 'resolved' ? 'Erledigen' : 'Verwerfen'),
          ),
        ],
      ),
    );
    return ok == true ? controller.text.trim() : null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (!ref.watch(canModerateProvider)) return _keinZutritt(context);

    final filter = ref.watch(moderationFilterProvider);
    final reportsAsync = ref.watch(moderationReportsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('🛡 Meldungen')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Wrap(
              spacing: 8,
              children: [
                for (final (wert, label) in _stapel)
                  ChoiceChip(
                    label: Text(label),
                    selected: filter == wert,
                    onSelected: (_) => ref
                        .read(moderationFilterProvider.notifier)
                        .state = wert,
                  ),
              ],
            ),
          ),
          Expanded(
            child: reportsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Fehler: $e')),
              data: (reports) => reports.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🕊', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            Text(
                              filter == 'open'
                                  ? 'Nichts zu tun — keine offenen Meldungen.'
                                  : 'Hier ist nichts.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(moderationReportsProvider);
                        await ref.read(moderationReportsProvider.future);
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        itemCount: reports.length,
                        itemBuilder: (context, i) =>
                            _karte(context, ref, theme, scheme, reports[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _karte(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ColorScheme scheme,
    ModerationReport r,
  ) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Chip(
                    label: Text(r.subjectLabel),
                    labelStyle: theme.textTheme.labelSmall,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'gemeldet: ${r.reportedName}',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    // Kurz im Kopf der Karte („vor 2 Tagen"); das genaue
                    // Datum steht unten bei der Bearbeitung, wo es zählt.
                    timeAgo(r.createdAt),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(r.reason, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(
                'von ${r.reporterName}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (!r.isOpen) ...[
                const SizedBox(height: 8),
                Text(
                  '${r.statusLabel}'
                  '${r.handledByName != null ? ' von ${r.handledByName}' : ''}'
                  '${r.handledAt != null ? ' am ${formatDate(r.handledAt!)}' : ''}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (r.note != null && r.note!.isNotEmpty)
                  Text('„${r.note}"', style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: r.isOpen
                    ? [
                        TextButton(
                          onPressed: () =>
                              _abschliessen(context, ref, r, 'dismissed'),
                          child: const Text('Verwerfen'),
                        ),
                        const SizedBox(width: 4),
                        FilledButton(
                          onPressed: () =>
                              _abschliessen(context, ref, r, 'resolved'),
                          child: const Text('Erledigen'),
                        ),
                      ]
                    : [
                        TextButton(
                          onPressed: () =>
                              _abschliessen(context, ref, r, 'open'),
                          child: const Text('Wieder öffnen'),
                        ),
                      ],
              ),
            ],
          ),
        ),
      );

  Widget _keinZutritt(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('🛡 Meldungen')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⛔', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text('Nur für Moderatoren',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Meldungen bearbeiten dürfen Moderatoren und Admins. '
                'Melden kann jeder — im Freunde-Bildschirm beim jeweiligen '
                'Profil.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
