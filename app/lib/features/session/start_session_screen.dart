import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/format.dart'
    show formatDuration, formatDate, formatTime;
import '../../data/db/database.dart';
import '../../data/location_service.dart';
import '../../data/providers.dart';
import '../../widgets/beacon_messages.dart';
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

  /// Termin einer Verabredung. `null` = jetzt losgehen (der Normalfall).
  ///
  /// Ein Beacon behauptet Anwesenheit, eine Verabredung nur eine Absicht
  /// — deshalb sind es zwei Wege durch dasselbe Formular und nicht ein
  /// Beacon mit Datumsfeld (docs/features/39).
  DateTime? _termin;

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

  /// Datum und Uhrzeit wählen. Abbruch an einer der beiden Stellen lässt
  /// den bisherigen Termin stehen — wer die Uhrzeit wegtippt, wollte
  /// nicht die ganze Verabredung zurücknehmen.
  Future<void> _terminWaehlen() async {
    final jetzt = DateTime.now();
    final tag = await showDatePicker(
      context: context,
      initialDate: _termin ?? jetzt.add(const Duration(days: 1)),
      firstDate: jetzt,
      lastDate: jetzt.add(const Duration(days: 365)),
      helpText: 'Wann trefft ihr euch?',
    );
    if (tag == null || !mounted) return;
    final zeit = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _termin?.hour ?? 19, minute: _termin?.minute ?? 0),
      helpText: 'Um wie viel Uhr?',
    );
    if (zeit == null || !mounted) return;
    setState(() => _termin =
        DateTime(tag.year, tag.month, tag.day, zeit.hour, zeit.minute));
  }

  /// Eine Verabredung anlegen statt eines Beacons.
  Future<void> _plan() async {
    final venue = _venueController.text.trim();
    final termin = _termin;
    if (termin == null) return;
    if (termin.isBefore(DateTime.now())) {
      setState(() => _venueError = null);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Der Termin liegt in der Vergangenheit.'),
      ));
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      final ok = await ref.read(actionsProvider).planSession(
            scheduledFor: termin,
            venueName: venue.isEmpty ? null : venue,
            venueId: _venueId,
            message: _messageController.text,
            crewId:
                _visibility == SessionVisibility.crew ? _crewId : null,
          );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (ok) context.pop();
      // Kein „deine Freunde wissen Bescheid", das der Server nicht
      // bestätigt hat — und ohne Verbindung entsteht hier gar nichts,
      // weil eine Verabredung, von der niemand erfährt, keine ist.
      messenger.showSnackBar(SnackBar(
        content: Text(ok
            ? 'Verabredung steht — deine Freunde sehen sie 🍻'
            : 'Das hat nicht geklappt. Ohne Verbindung lässt sich keine '
                'Verabredung anlegen — sonst würde niemand davon erfahren.'),
        duration: Duration(seconds: ok ? 4 : 7),
      ));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _start() async {
    if (_termin != null) return _plan();
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
      final ergebnis = await ref.read(actionsProvider).startSession(
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
      if (ergebnis.earned.isNotEmpty) {
        await showBadgeCelebration(context, ergebnis.earned);
      }
      if (!mounted) return;
      context.pop();
      // Kein „deine Freunde wissen Bescheid", das der Server nicht
      // bestätigt hat.
      messenger.showSnackBar(SnackBar(
        content: Text(ergebnis.synced
            ? 'Beacon läuft – deine Freunde wissen Bescheid 🍻'
            : beaconStartNotSyncedText),
        duration: Duration(seconds: ergebnis.synced ? 4 : 7),
      ));
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
          _TerminZeile(
            termin: _termin,
            onWaehlen: _terminWaehlen,
            onZuruecknehmen: () => setState(() => _termin = null),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _venueController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: _termin == null ? 'Wo bist du?' : 'Wo trefft ihr euch?',
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
            icon: Text(_termin == null ? '🍻' : '📅',
                style: const TextStyle(fontSize: 20)),
            label: Text(_termin == null ? 'Los geht\'s!' : 'Verabreden'),
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

/// Der Schalter zwischen „jetzt losgehen“ und „später verabreden“.
///
/// Bewusst kein Umschalter mit zwei Zuständen: Der Normalfall ist der
/// Beacon, und der soll keinen zusätzlichen Tipp kosten. Wer einen Termin
/// wählt, hat damit schon umgeschaltet — und sieht das auch.
class _TerminZeile extends StatelessWidget {
  const _TerminZeile({
    required this.termin,
    required this.onWaehlen,
    required this.onZuruecknehmen,
  });

  final DateTime? termin;
  final VoidCallback onWaehlen;
  final VoidCallback onZuruecknehmen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (termin == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: onWaehlen,
          icon: const Icon(Icons.event_outlined, size: 18),
          label: const Text('Erst später? Termin wählen'),
        ),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Text('📅', style: TextStyle(fontSize: 22)),
        title: Text('${formatDate(termin!)}, ${formatTime(termin!)} Uhr'),
        subtitle: Text(
          'Deine Freunde können zusagen. Die Runde startest du selbst, '
          'wenn du da bist.',
          style: theme.textTheme.bodySmall,
        ),
        trailing: IconButton(
          tooltip: 'Termin zurücknehmen — dann geht es jetzt los',
          icon: const Icon(Icons.close),
          onPressed: onZuruecknehmen,
        ),
        onTap: onWaehlen,
      ),
    );
  }
}
