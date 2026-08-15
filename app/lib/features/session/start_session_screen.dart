import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/format.dart' show formatDuration;
import '../../data/db/database.dart';
import '../../data/location_service.dart';
import '../../data/providers.dart';
import '../../data/venue_sync.dart';
import '../../widgets/badge_celebration.dart';
import '../../widgets/venue_picker.dart';

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

  /// Gewählte Crew für `visibility == crew`.
  String? _crewId;
  /// Vorbelegt mit der zuletzt gewählten Laufzeit (sonst drei Stunden).
  late Duration _autoEnd = ref.read(preferredSessionDurationProvider);
  bool _shareLocation = true;
  String? _venueError;
  bool _submitting = false;

  /// Gewähltes Gasthaus aus der gemeinsamen DB (null = Freitext).
  String? _venueId;

  /// „Bist du hier?" – nächstgelegenes Gasthaus aus dem Cache (< 150 m).
  Venue? _nearbySuggestion;

  @override
  void initState() {
    super.initState();
    unawaited(_suggestNearestVenue());
  }

  Future<void> _suggestNearestVenue() async {
    final location =
        await ref.read(locationServiceProvider).getCurrentPosition();
    if (location is! LocationGranted || !mounted) return;
    final venues =
        await ref.read(databaseProvider).watchVenuesWithLocation().first;
    const distance = Distance();
    Venue? best;
    var bestMeters = 150.0;
    for (final venue in venues) {
      final meters = distance(
        LatLng(location.latitude, location.longitude),
        LatLng(venue.latitude!, venue.longitude!),
      );
      if (meters < bestMeters) {
        best = venue;
        bestMeters = meters;
      }
    }
    if (mounted && best != null) {
      setState(() => _nearbySuggestion = best);
    }
  }

  Future<void> _pickVenue() async {
    final selection =
        await showVenuePicker(context, initialQuery: _venueController.text);
    if (selection == null || !mounted) return;
    setState(() {
      _venueId = selection.venueId;
      _venueController.text = selection.venueName;
      _venueError = null;
    });
  }

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
    // Echtes GPS; ohne Berechtigung/Signal startet die Session ohne
    // Karten-Pin (Venue-Name reicht).
    double? latitude;
    double? longitude;
    if (shareLocation) {
      final location =
          await ref.read(locationServiceProvider).getCurrentPosition();
      if (location
          case LocationGranted(latitude: final lat, longitude: final lng)) {
        latitude = lat;
        longitude = lng;
      }
    }
    if (!mounted) return;

    try {
      final earned = await ref.read(actionsProvider).startSession(
            venueName: venue,
            venueId: _venueId,
            message: _messageController.text,
            visibility: _visibility,
            autoEnd: _autoEnd,
            latitude: latitude,
            longitude: longitude,
            crewId:
                _visibility == SessionVisibility.crew ? _crewId : null,
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
              // Manuelle Eingabe löst die Verknüpfung zum DB-Gasthaus.
              setState(() {
                _venueId = null;
                _venueError = null;
              });
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (_nearbySuggestion != null)
                ActionChip(
                  avatar: const Icon(Icons.near_me, size: 16),
                  label: Text('Bist du hier? '
                      '${venueCategoryEmoji(_nearbySuggestion!.category)} '
                      '${_nearbySuggestion!.name}'),
                  onPressed: () => setState(() {
                    _venueId = _nearbySuggestion!.id;
                    _venueController.text = _nearbySuggestion!.name;
                    _venueError = null;
                  }),
                ),
              ActionChip(
                avatar: const Icon(Icons.storefront_outlined, size: 16),
                label: const Text('Gasthaus wählen'),
                onPressed: () async => _pickVenue(),
              ),
              ActionChip(
                label: const Text('Zuhause'),
                onPressed: () => setState(() {
                  _venueId = null;
                  _venueController.text = 'Zuhause';
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
          // 👥 Crew-Beacon: nur sichtbar, wenn man Crews hat.
          ...() {
            final crews =
                ref.watch(myCrewsProvider).valueOrNull ?? const [];
            if (crews.isEmpty) return const <Widget>[];
            // Vorauswahl: erste Crew, sobald „Crew" gewählt wird.
            _crewId ??= crews.first.id;
            return [
              RadioListTile<SessionVisibility>(
                value: SessionVisibility.crew,
                groupValue: _visibility,
                onChanged: (v) => setState(() => _visibility = v!),
                title: const Text('Nur meine Crew'),
                subtitle: _visibility == SessionVisibility.crew
                    ? DropdownButton<String>(
                        value: _crewId,
                        isExpanded: true,
                        items: [
                          for (final c in crews)
                            DropdownMenuItem(
                              value: c.id,
                              child: Text('${c.emoji} ${c.name}'),
                            ),
                        ],
                        onChanged: (v) => setState(() => _crewId = v),
                      )
                    : null,
              ),
            ];
          }(),
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
                items: [
                  for (final d in sessionDurationChoices)
                    DropdownMenuItem(
                        value: d, child: Text(formatDuration(d))),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _autoEnd = v);
                  // Als Vorgabe merken — auch für den Ein-Tap-Beacon.
                  ref.read(preferredSessionDurationProvider.notifier).state =
                      v;
                },
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
