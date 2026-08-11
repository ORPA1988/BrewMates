import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../widgets/badge_celebration.dart';

/// Venue-Schnellauswahl, solange es noch kein echtes GPS gibt.
const List<String> _venueSuggestions = [
  'Hopfengarten',
  'Craft Corner',
  'Biergarten am See',
  'Zum Goldenen Fass',
  'Zuhause',
];

/// „Der eine Tap": Session starten (siehe docs/05-ui-screens.md, Screen 2).
class StartSessionScreen extends ConsumerStatefulWidget {
  const StartSessionScreen({super.key});

  @override
  ConsumerState<StartSessionScreen> createState() =>
      _StartSessionScreenState();
}

class _StartSessionScreenState extends ConsumerState<StartSessionScreen> {
  final _venueController = TextEditingController();
  final _messageController = TextEditingController();
  SessionVisibility _visibility = SessionVisibility.friends;
  Duration _autoEnd = const Duration(hours: 3);
  bool _shareLocation = true;
  String? _venueError;
  bool _submitting = false;

  @override
  void dispose() {
    _venueController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final venue = _venueController.text.trim();
    if (venue.isEmpty) {
      setState(() => _venueError = 'Sag deinen Freunden, wo du bist.');
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);

    final stealth = _visibility == SessionVisibility.private;
    final shareLocation = !stealth && _shareLocation;
    // Demo-GPS: München-Mittelpunkt plus kleiner Venue-abhängiger Versatz,
    // damit Marker auf der Karte nicht übereinanderliegen.
    // Echtes GPS folgt mit geolocator.
    final offset = venue.hashCode % 20;
    final latitude = shareLocation ? 48.1374 + offset * 0.001 : null;
    final longitude = shareLocation ? 11.5755 + offset * 0.0015 : null;

    try {
      final earned = await ref.read(actionsProvider).startSession(
            venueName: venue,
            message: _messageController.text,
            visibility: _visibility,
            autoEnd: _autoEnd,
            latitude: latitude,
            longitude: longitude,
          );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (earned.isNotEmpty) {
        await showBadgeCelebration(context, earned);
      }
      if (!mounted) return;
      context.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Session gestartet – deine Freunde wissen Bescheid 🍻'),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stealth = _visibility == SessionVisibility.private;

    return Scaffold(
      appBar: AppBar(title: const Text('🍺 Bier-Zeit!')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _venueController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Wo bist du?',
              errorText: _venueError,
              prefixIcon: const Icon(Icons.place_outlined),
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_venueError != null) setState(() => _venueError = null);
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final venue in _venueSuggestions)
                ActionChip(
                  label: Text(venue),
                  onPressed: () => setState(() {
                    _venueController.text = venue;
                    _venueError = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _messageController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nachricht (optional)',
              hintText: 'Wir sitzen hinten im Garten, Tisch 12',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: !stealth && _shareLocation,
            onChanged: stealth
                ? null
                : (v) => setState(() => _shareLocation = v),
            title: const Text('Standort auf der Karte teilen'),
            subtitle: const Text('Nur solange die Session läuft'),
            secondary: const Icon(Icons.map_outlined),
          ),
          const SizedBox(height: 8),
          Text('Sichtbar für', style: theme.textTheme.titleSmall),
          RadioListTile<SessionVisibility>(
            value: SessionVisibility.friends,
            groupValue: _visibility,
            onChanged: (v) => setState(() => _visibility = v!),
            title: const Text('Alle Freunde'),
          ),
          // Kein Crew-Radio: Crews kommen in v1.1.
          RadioListTile<SessionVisibility>(
            value: SessionVisibility.private,
            groupValue: _visibility,
            onChanged: (v) => setState(() {
              _visibility = v!;
              _shareLocation = false;
            }),
            title: const Text('Nur ich (Stealth)'),
            subtitle: const Text('Kein Beacon, kein Standort'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.timer_outlined),
              const SizedBox(width: 8),
              const Text('Auto-Ende:'),
              const SizedBox(width: 12),
              DropdownButton<Duration>(
                value: _autoEnd,
                items: const [
                  DropdownMenuItem(
                      value: Duration(hours: 1), child: Text('1 h')),
                  DropdownMenuItem(
                      value: Duration(hours: 3), child: Text('3 h')),
                  DropdownMenuItem(
                      value: Duration(hours: 6), child: Text('6 h')),
                ],
                onChanged: (v) => setState(() => _autoEnd = v!),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: _submitting ? null : _start,
            icon: const Text('🍻', style: TextStyle(fontSize: 20)),
            label: const Text('Los geht\'s!'),
          ),
          const SizedBox(height: 12),
          Text(
            'Bei „Nur ich (Stealth)" erscheint nichts im Feed deiner Freunde.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
