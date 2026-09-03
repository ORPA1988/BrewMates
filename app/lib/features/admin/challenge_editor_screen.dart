import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

/// Admin-Werkzeug: Challenges anlegen und verwalten (Migration 0012).
/// Die Regel wird als {"type": …, "threshold": …, "style"?: …} gespeichert
/// und clientseitig gegen die eigenen Check-ins ausgewertet.
const List<({String type, String label, bool needsStyle})> _ruleTypes = [
  (type: 'checkins_count', label: 'Check-ins insgesamt', needsStyle: false),
  (type: 'distinct_beers', label: 'Verschiedene Biere', needsStyle: false),
  (type: 'distinct_styles', label: 'Verschiedene Stile', needsStyle: false),
  (
    type: 'distinct_breweries',
    label: 'Verschiedene Brauereien',
    needsStyle: false
  ),
  (type: 'alcohol_free', label: 'Alkoholfreie Check-ins', needsStyle: false),
  (
    type: 'style_specific',
    label: 'Verschiedene Biere eines Stils',
    needsStyle: true
  ),
  (
    type: 'venue_checkins',
    label: 'Verschiedene Gasthäuser besucht',
    needsStyle: false
  ),
];

const List<String> _emojiChoices = [
  '🏆', '🍺', '🌍', '🧭', '💧', '🍂', '🎄', '☀️', '🥨', '🤝',
];

class ChallengeEditorScreen extends ConsumerStatefulWidget {
  const ChallengeEditorScreen({super.key});

  @override
  ConsumerState<ChallengeEditorScreen> createState() =>
      _ChallengeEditorScreenState();
}

class _ChallengeEditorScreenState
    extends ConsumerState<ChallengeEditorScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _styleController = TextEditingController();
  String _emoji = '🏆';
  String _ruleType = 'distinct_styles';
  int _threshold = 5;
  DateTimeRange? _range;
  bool _busy = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _styleController.dispose();
    super.dispose();
  }

  DateTimeRange get _effectiveRange =>
      _range ??
      DateTimeRange(
        start: DateTime.now(),
        end: DateTime.now().add(const Duration(days: 14)),
      );

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _effectiveRange,
    );
    if (picked != null && mounted) setState(() => _range = picked);
  }

  Future<void> _create() async {
    final title = _titleController.text.trim();
    if (title.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bitte einen Titel mit mindestens 3 Zeichen.')));
      return;
    }
    final needsStyle =
        _ruleTypes.firstWhere((r) => r.type == _ruleType).needsStyle;
    final style = _styleController.text.trim();
    if (needsStyle && style.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Dieser Regeltyp braucht einen Bierstil.')));
      return;
    }
    final online = await ref.read(onlineServiceProvider.future);
    if (online == null) return;
    setState(() => _busy = true);
    try {
      final range = _effectiveRange;
      final err = await online.createChallenge(
        title: title,
        description: _descriptionController.text,
        emoji: _emoji,
        rule: {
          'type': _ruleType,
          'threshold': _threshold,
          if (needsStyle) 'style': style,
        },
        startsAt: DateTime(
            range.start.year, range.start.month, range.start.day),
        endsAt: DateTime(range.end.year, range.end.month, range.end.day)
            .add(const Duration(days: 1)), // Endtag inklusive
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err ?? 'Challenge „$title" läuft! 🏆')));
      if (err == null) {
        _titleController.clear();
        _descriptionController.clear();
        _styleController.clear();
        setState(() => _range = null);
        ref.invalidate(challengesProvider);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(String id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('„$title" löschen?'),
        content: const Text('Auch die Abschluss-Einträge der Nutzer '
            'verschwinden damit vom Server (lokale Badges bleiben).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true) return;
    final online = await ref.read(onlineServiceProvider.future);
    if (online == null || !mounted) return;
    final err = await online.deleteChallenge(id);
    if (!mounted) return;
    if (err == null) ref.invalidate(challengesProvider);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(err ?? 'Gelöscht.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdmin = ref.watch(isAdminProvider).valueOrNull ?? false;
    final challenges = ref.watch(challengesProvider).valueOrNull ?? const [];
    final needsStyle =
        _ruleTypes.firstWhere((r) => r.type == _ruleType).needsStyle;
    final range = _effectiveRange;

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Challenges')),
        body: const Center(child: Text('Nur für Admins.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('🏆 Challenges verwalten')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Neue Challenge', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Titel *',
              hintText: 'z. B. Oktober-Stil-Safari',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Beschreibung',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final emoji in _emojiChoices)
                ChoiceChip(
                  label: Text(emoji),
                  selected: _emoji == emoji,
                  onSelected: (_) => setState(() => _emoji = emoji),
                ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _ruleType,
            decoration: const InputDecoration(
              labelText: 'Regel',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final rule in _ruleTypes)
                DropdownMenuItem(value: rule.type, child: Text(rule.label)),
            ],
            onChanged: (v) => setState(() => _ruleType = v!),
          ),
          if (needsStyle) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _styleController,
              decoration: const InputDecoration(
                labelText: 'Bierstil *',
                hintText: 'z. B. IPA',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Ziel:', style: theme.textTheme.bodyLarge),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Ziel verringern',
                onPressed: _threshold > 1
                    ? () => setState(() => _threshold--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_threshold', style: theme.textTheme.titleMedium),
              IconButton(
                tooltip: 'Ziel erhöhen',
                onPressed: () => setState(() => _threshold++),
                icon: const Icon(Icons.add_circle_outline),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range, size: 18),
                label: Text(
                    '${range.start.day}.${range.start.month}. – '
                    '${range.end.day}.${range.end.month}.'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _create,
            icon: const Icon(Icons.emoji_events_outlined),
            label: const Text('Challenge starten'),
          ),
          const SizedBox(height: 24),
          Text('Bestehende Challenges', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          if (challenges.isEmpty)
            Text('Noch keine.', style: theme.textTheme.bodyMedium)
          else
            for (final c in challenges)
              Card(
                child: ListTile(
                  leading:
                      Text(c.emoji, style: const TextStyle(fontSize: 24)),
                  title: Text(c.title),
                  subtitle: Text(
                      '${c.startsAt.day}.${c.startsAt.month}. – '
                      '${c.endsAt.day}.${c.endsAt.month}.${c.endsAt.year}'),
                  trailing: IconButton(
                    tooltip: 'Löschen',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async => _delete(c.id, c.title),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
