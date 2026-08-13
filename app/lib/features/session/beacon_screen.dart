import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/database.dart';
import '../../data/location_service.dart';
import '../../data/providers.dart';
import '../../widgets/badge_celebration.dart';

/// Hero-Funktion „🍻 Zusammenkommen!": Ein Tap → Standort holen → Session
/// startet sofort mit „Alle willkommen! 🍻". Kein Formular; nur eine
/// Bestätigung mit Undo. Ohne Standort → Fallback auf die manuelle
/// Venue-Wahl (/session/start).
class BeaconScreen extends ConsumerStatefulWidget {
  const BeaconScreen({super.key});

  @override
  ConsumerState<BeaconScreen> createState() => _BeaconScreenState();
}

enum _BeaconState { locating, active, failed }

class _BeaconScreenState extends ConsumerState<BeaconScreen> {
  _BeaconState _state = _BeaconState.locating;
  String? _failureHint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final location =
        await ref.read(locationServiceProvider).getCurrentPosition();
    if (!mounted) return;

    switch (location) {
      case LocationGranted(:final latitude, :final longitude):
        final earned = await ref.read(actionsProvider).startSession(
              message: 'Alle willkommen! 🍻',
              visibility: SessionVisibility.friends,
              autoEnd: const Duration(hours: 3),
              latitude: latitude,
              longitude: longitude,
            );
        if (!mounted) return;
        setState(() => _state = _BeaconState.active);
        await showBadgeCelebration(context, earned);
      case LocationDenied(:final forever):
        setState(() {
          _state = _BeaconState.failed;
          _failureHint = forever
              ? 'Standort ist dauerhaft deaktiviert – du kannst ihn in den '
                  'System-Einstellungen wieder erlauben oder einfach den Ort '
                  'von Hand wählen.'
              : 'Ohne Standort kein Karten-Pin – wähle deinen Ort einfach '
                  'von Hand.';
        });
      case LocationUnavailable():
        setState(() {
          _state = _BeaconState.failed;
          _failureHint =
              'Kein Standort verfügbar – wähle deinen Ort von Hand.';
        });
    }
  }

  Future<void> _undo() async {
    await ref.read(actionsProvider).endMySession();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('🍻 Zusammenkommen!')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: switch (_state) {
            _BeaconState.locating => const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Standort wird ermittelt …'),
                ],
              ),
            _BeaconState.active => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🍻', style: TextStyle(fontSize: 72)),
                  const SizedBox(height: 16),
                  Text('Beacon läuft!',
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Deine Freunde sehen jetzt 3 Stunden lang, wo du bist – '
                    'und dass alle willkommen sind. Danach endet die Session '
                    'automatisch.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16)),
                    onPressed: () => context.pop(),
                    child: const Text('Passt 🍻'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _undo,
                    child: const Text('Ups – wieder beenden'),
                  ),
                ],
              ),
            _BeaconState.failed => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('📍', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 12),
                  Text(
                    _failureHint ?? 'Kein Standort verfügbar.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () =>
                        context.pushReplacement('/session/start'),
                    child: const Text('Ort von Hand wählen'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Abbrechen'),
                  ),
                ],
              ),
          },
        ),
      ),
    );
  }
}
