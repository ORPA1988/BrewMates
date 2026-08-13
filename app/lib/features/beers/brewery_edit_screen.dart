import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';

/// Selbst angelegte Brauereien bearbeiten (rein lokal – Brauereien leben
/// bisher nur in der lokalen DB). Redaktionelle Community-Brauereien sind
/// read-only; Korrekturen laufen über den GitHub-Vorschlag.
class BreweryEditScreen extends ConsumerStatefulWidget {
  const BreweryEditScreen({super.key, required this.breweryId});

  final String breweryId;

  @override
  ConsumerState<BreweryEditScreen> createState() =>
      _BreweryEditScreenState();
}

class _BreweryEditScreenState extends ConsumerState<BreweryEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  bool _loaded = false;
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _prefill(Brewery brewery) {
    if (_loaded) return;
    _loaded = true;
    _nameController.text = brewery.name;
    _countryController.text = brewery.country;
    _cityController.text = brewery.city;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final db = ref.read(databaseProvider);
      await (db.update(db.breweries)
            ..where((t) => t.id.equals(widget.breweryId)))
          .write(BreweriesCompanion(
        name: Value(_nameController.text.trim()),
        country: Value(_countryController.text.trim()),
        city: Value(_cityController.text.trim()),
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Brauerei aktualisiert 🍻')));
      context.pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brewery = ref.watch(breweryProvider(widget.breweryId)).valueOrNull;
    if (brewery == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Brauerei bearbeiten')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!isUuid(brewery.id)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Brauerei bearbeiten')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Redaktionelle Community-Brauereien werden über GitHub '
              'gepflegt – nutze „Korrektur vorschlagen" auf der Detailseite.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    _prefill(brewery);

    return Scaffold(
      appBar: AppBar(title: const Text('Brauerei bearbeiten')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Bitte einen Namen angeben'
                  : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _countryController,
                    decoration: const InputDecoration(
                      labelText: 'Land *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Bitte ein Land angeben'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'Stadt *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Bitte eine Stadt angeben'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _busy ? null : _save,
              child: const Text('Speichern'),
            ),
            const SizedBox(height: 8),
            Text(
              'Diese Brauerei existiert nur auf deinem Gerät – Änderungen '
              'bleiben lokal.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
