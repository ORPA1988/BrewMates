import 'package:flutter/material.dart';

import '../../domain/models.dart';

/// „Der eine Tap": Session starten (siehe docs/05-ui-screens.md, Screen 2).
class StartSessionScreen extends StatefulWidget {
  const StartSessionScreen({super.key});

  @override
  State<StartSessionScreen> createState() => _StartSessionScreenState();
}

class _StartSessionScreenState extends State<StartSessionScreen> {
  SessionVisibility _visibility = SessionVisibility.friends;
  Duration _autoEnd = const Duration(hours: 3);
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🍺 Bier-Zeit!')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // TODO: Venue-Vorschlag per GPS
          const ListTile(
            leading: Icon(Icons.place_outlined),
            title: Text('Standort wird erkannt …'),
            subtitle: Text('Venue antippen zum Ändern'),
          ),
          TextField(
            controller: _messageController,
            decoration: const InputDecoration(
              labelText: 'Nachricht (optional)',
              hintText: 'Wir sitzen hinten im Garten, Tisch 12',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text('Sichtbar für', style: Theme.of(context).textTheme.titleSmall),
          RadioListTile(
            value: SessionVisibility.friends,
            groupValue: _visibility,
            onChanged: (v) => setState(() => _visibility = v!),
            title: const Text('Alle Freunde'),
          ),
          RadioListTile(
            value: SessionVisibility.crew,
            groupValue: _visibility,
            onChanged: (v) => setState(() => _visibility = v!),
            title: const Text('Crew'),
            subtitle: const Text('Crew auswählen …'),
          ),
          RadioListTile(
            value: SessionVisibility.private,
            groupValue: _visibility,
            onChanged: (v) => setState(() => _visibility = v!),
            title: const Text('Nur ich (Stealth)'),
            subtitle: const Text('Kein Beacon, kein Standort'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.timer_outlined),
              const SizedBox(width: 8),
              const Text('Auto-Ende:'),
              const SizedBox(width: 8),
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
            onPressed: () {
              // TODO: Session via Repository anlegen → Beacon-Fan-out
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Session gestartet – Prost! 🍻')),
              );
              Navigator.of(context).pop();
            },
            icon: const Text('🍻', style: TextStyle(fontSize: 20)),
            label: const Text('Los geht\'s!'),
          ),
        ],
      ),
    );
  }
}
