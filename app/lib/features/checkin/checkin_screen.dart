import 'package:flutter/material.dart';

import '../../data/demo_data.dart';
import '../../domain/models.dart';

/// Bier einchecken: Suche → Bewertung → optional Foto/Tags/Notiz.
/// Funktioniert offline (Drift-Queue, siehe docs/03-architektur.md).
class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  Beer? _selected;
  double _rating = 3.5;
  final _noteController = TextEditingController();

  static const _demoBeers = [DemoData.hopfengold, DemoData.nebelwerfer];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bier einchecken')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Autocomplete<Beer>(
            displayStringForOption: (b) => '${b.name} · ${b.brewery.name}',
            optionsBuilder: (input) {
              if (input.text.isEmpty) return _demoBeers;
              final q = input.text.toLowerCase();
              return _demoBeers.where((b) =>
                  b.name.toLowerCase().contains(q) ||
                  b.brewery.name.toLowerCase().contains(q));
            },
            onSelected: (b) => setState(() => _selected = b),
            fieldViewBuilder: (context, controller, focusNode, onSubmit) =>
                TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(
                labelText: 'Bier suchen',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                // TODO v1: Barcode-Scanner als suffixIcon
              ),
            ),
          ),
          if (_selected != null) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: Text(_selected!.name),
                subtitle: Text(
                    '${_selected!.style} · ${_selected!.abv ?? '?'} % · '
                    '${_selected!.brewery.name}'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text('Bewertung: ${_rating.toStringAsFixed(2)} ⭐',
              style: Theme.of(context).textTheme.titleSmall),
          Slider(
            value: _rating,
            min: 0,
            max: 5,
            divisions: 20, // 0,25er-Schritte wie Untappd
            label: _rating.toStringAsFixed(2),
            onChanged: (v) => setState(() => _rating = v),
          ),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notiz (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {}, // TODO: Foto aufnehmen/wählen
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Foto hinzufügen'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: _selected == null
                ? null
                : () {
                    // TODO: lokal speichern (Drift) → Sync nach Supabase
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Check-in gespeichert 🍺')),
                    );
                    Navigator.of(context).pop();
                  },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }
}
