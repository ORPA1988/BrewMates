import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';

/// Nutzererstellte Community-Biere bearbeiten (Datenpflege).
/// Redaktionelle Biere aus den gebündelten JSON-Dateien sind in-app
/// read-only – Korrekturen laufen über den GitHub-Vorschlag.
class BeerEditScreen extends ConsumerStatefulWidget {
  const BeerEditScreen({super.key, required this.beerId});

  final String beerId;

  @override
  ConsumerState<BeerEditScreen> createState() => _BeerEditScreenState();
}

class _BeerEditScreenState extends ConsumerState<BeerEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _styleController = TextEditingController();
  final _abvController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isAlcoholFree = false;
  bool _loaded = false;
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    _styleController.dispose();
    _abvController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _prefill(Beer beer) {
    if (_loaded) return;
    _loaded = true;
    _nameController.text = beer.name;
    _styleController.text = beer.style;
    _abvController.text =
        beer.abv?.toString().replaceAll('.', ',') ?? '';
    _descriptionController.text = beer.description ?? '';
    _isAlcoholFree = beer.isAlcoholFree;
  }

  Future<void> _save(BeerWithBrewery item) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final abvText = _abvController.text.trim().replaceAll(',', '.');
      final abv = abvText.isEmpty ? null : double.tryParse(abvText);
      final description = _descriptionController.text.trim();
      final db = ref.read(databaseProvider);
      await (db.update(db.beers)..where((t) => t.id.equals(item.beer.id)))
          .write(BeersCompanion(
        name: Value(_nameController.text.trim()),
        style: Value(_styleController.text.trim()),
        abv: Value(abv),
        isAlcoholFree: Value(_isAlcoholFree),
        description: Value(description.isEmpty ? null : description),
      ));

      // Ist das Bier auch online in der Community-DB (per Barcode),
      // best-effort mitpflegen – die RLS/Vertrauensstufe entscheidet.
      String? onlineError;
      String? barcode;
      for (final code in item.beer.barcodes.split(',')) {
        final trimmed = code.trim();
        if (trimmed.isNotEmpty) {
          barcode = trimmed;
          break;
        }
      }
      final online = await ref.read(onlineServiceProvider.future);
      if (barcode != null && online != null && online.currentUser != null) {
        onlineError = await online.updateCommunityBeer(barcode, {
          'name': _nameController.text.trim(),
          'style': _styleController.text.trim(),
          'abv': abv,
          'is_alcohol_free': _isAlcoholFree,
          'description': description.isEmpty ? null : description,
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(onlineError == null
              ? 'Gespeichert – danke für die Datenpflege! 🍻'
              : 'Lokal gespeichert. Online: $onlineError')));
      context.pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemAsync = ref.watch(beerProvider(widget.beerId));
    final item = itemAsync.valueOrNull;
    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bier bearbeiten')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!item.beer.isUserSubmitted) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bier bearbeiten')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Redaktionelle Community-Biere werden über GitHub gepflegt – '
              'nutze „Korrektur vorschlagen" auf der Detailseite.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    _prefill(item.beer);

    return Scaffold(
      appBar: AppBar(title: const Text('Bier bearbeiten')),
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
            TextFormField(
              controller: _styleController,
              decoration: const InputDecoration(
                labelText: 'Stil *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Bitte einen Stil angeben'
                  : null,
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
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('💧 Alkoholfrei'),
              value: _isAlcoholFree,
              onChanged: (v) => setState(() => _isAlcoholFree = v),
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
              onPressed: _busy ? null : () async => _save(item),
              child: const Text('Speichern'),
            ),
            const SizedBox(height: 8),
            Text(
              'Änderungen an Community-Bieren sind für alle sichtbar und '
              'werden protokolliert.',
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
