import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';

/// Häufigste Stile als Schnellauswahl.
const List<String> _kStyleSuggestions = [
  'Helles',
  'Pils',
  'IPA',
  'Weissbier',
  'Stout',
  'Lager',
];

/// Community-Einreichung: fehlendes Bier in 30 Sekunden eintragen.
class AddBeerScreen extends ConsumerStatefulWidget {
  const AddBeerScreen({super.key});

  @override
  ConsumerState<AddBeerScreen> createState() => _AddBeerScreenState();
}

class _AddBeerScreenState extends ConsumerState<AddBeerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _styleController = TextEditingController();
  final _breweryController = TextEditingController();
  final _countryController = TextEditingController(text: 'Deutschland');
  final _cityController = TextEditingController();
  final _abvController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isAlcoholFree = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _styleController.dispose();
    _breweryController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _abvController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? _required(String? value, String message) =>
      (value == null || value.trim().isEmpty) ? message : null;

  String? _validateAbv(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final abv = double.tryParse(value.trim().replaceAll(',', '.'));
    if (abv == null || abv < 0 || abv > 70) {
      return 'Bitte einen Wert zwischen 0 und 70 angeben';
    }
    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final abvText = _abvController.text.trim().replaceAll(',', '.');
      final description = _descriptionController.text.trim();
      final id = await ref.read(actionsProvider).addBeer(
            name: _nameController.text,
            style: _styleController.text,
            breweryName: _breweryController.text,
            breweryCountry: _countryController.text,
            breweryCity: _cityController.text,
            abv: abvText.isEmpty ? null : double.tryParse(abvText),
            isAlcoholFree: _isAlcoholFree,
            description: description.isEmpty ? null : description,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Danke! Dein Bier ist drin 🍺')),
        );
        context.pushReplacement('/beer/$id');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bier fehlt? 30 Sekunden.')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Name *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => _required(v, 'Bitte einen Namen angeben'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _styleController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Stil *',
                hintText: 'z. B. Helles, IPA …',
                border: OutlineInputBorder(),
              ),
              validator: (v) => _required(v, 'Bitte einen Stil angeben'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final style in _kStyleSuggestions)
                  ActionChip(
                    label: Text(style),
                    onPressed: () =>
                        setState(() => _styleController.text = style),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _breweryController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Brauerei *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => _required(v, 'Bitte eine Brauerei angeben'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _countryController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Land *',
                      hintText: 'Deutschland',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => _required(v, 'Bitte ein Land angeben'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cityController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Stadt *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        _required(v, 'Bitte eine Stadt angeben'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _abvController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Alkoholgehalt in % (optional)',
                border: OutlineInputBorder(),
              ),
              validator: _validateAbv,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('💧 Alkoholfrei'),
              value: _isAlcoholFree,
              onChanged: (value) => setState(() => _isAlcoholFree = value),
            ),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Beschreibung (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _saving ? null : _save,
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }
}
