import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

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
/// Kommt der Nutzer vom Scanner, sind EAN (und ggf. Name/Brauerei aus
/// Open Food Facts) bereits vorbefüllt.
class AddBeerScreen extends ConsumerStatefulWidget {
  const AddBeerScreen({
    super.key,
    this.initialBarcode,
    this.initialName,
    this.initialBrewery,
  });

  final String? initialBarcode;
  final String? initialName;
  final String? initialBrewery;

  @override
  ConsumerState<AddBeerScreen> createState() => _AddBeerScreenState();
}

class _AddBeerScreenState extends ConsumerState<AddBeerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _styleController = TextEditingController();
  final _breweryController = TextEditingController();
  final _countryController = TextEditingController(text: 'Österreich');
  final _cityController = TextEditingController();
  final _abvController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isAlcoholFree = false;
  bool _saving = false;
  Uint8List? _photoBytes;

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) {
      _nameController.text = widget.initialName!;
    }
    if (widget.initialBrewery != null) {
      _breweryController.text = widget.initialBrewery!;
    }
  }

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

  /// Vorausgefülltes GitHub-Issue-Formular („🍺 Bier vorschlagen") öffnen —
  /// so landet der Vorschlag in der gemeinsamen Community-Datenbank.
  Uri _proposalUrl() {
    return Uri.https('github.com', '/ORPA1988/BrewMates/issues/new', {
      'template': 'bier-vorschlag.yml',
      'title': '[Bier] ${_nameController.text.trim()}',
      'biername': _nameController.text.trim(),
      'brauerei': _breweryController.text.trim(),
      'ort': _cityController.text.trim(),
      'stil': _styleController.text.trim(),
      'abv': _abvController.text.trim(),
      if (widget.initialBarcode != null) 'ean': widget.initialBarcode!,
      'beschreibung': _descriptionController.text.trim(),
    });
  }

  Future<void> _offerCommunityProposal() async {
    final propose = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Der Community vorschlagen?'),
        content: const Text(
            'Dein Bier ist lokal gespeichert. Soll es zusätzlich in die '
            'gemeinsame BrewMates-Datenbank auf GitHub? Es öffnet sich ein '
            'vorausgefülltes Formular – absenden genügt (GitHub-Konto '
            'nötig). Nach Prüfung bekommen es alle Nutzer beim nächsten '
            'Sync.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Nur lokal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Vorschlagen 🍺'),
          ),
        ],
      ),
    );
    if (propose ?? false) {
      await launchUrl(_proposalUrl(), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 80,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (mounted) setState(() => _photoBytes = bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Foto konnte nicht geladen werden.')));
      }
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final abvText = _abvController.text.trim().replaceAll(',', '.');
      final description = _descriptionController.text.trim();
      final abv = abvText.isEmpty ? null : double.tryParse(abvText);
      final id = await ref.read(actionsProvider).addBeer(
            name: _nameController.text,
            style: _styleController.text,
            breweryName: _breweryController.text,
            breweryCountry: _countryController.text,
            breweryCity: _cityController.text,
            abv: abv,
            isAlcoholFree: _isAlcoholFree,
            description: description.isEmpty ? null : description,
            barcode: widget.initialBarcode,
          );
      if (!mounted) return;

      // Angemeldet → direkt in die gemeinsame Community-DB (Supabase);
      // abgemeldet → wie bisher GitHub-Vorschlag anbieten.
      final online = await ref.read(onlineServiceProvider.future);
      String? onlineError;
      var wentOnline = false;
      if (online != null && online.currentUser != null) {
        wentOnline = true;
        onlineError = await online.submitCommunityBeer(
          name: _nameController.text,
          style: _styleController.text,
          breweryName: _breweryController.text,
          country: _countryController.text,
          city: _cityController.text,
          abv: abv,
          isAlcoholFree: _isAlcoholFree,
          description: description.isEmpty ? null : description,
          barcode: widget.initialBarcode,
          photoBytes: _photoBytes,
        );
      } else {
        await _offerCommunityProposal();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(!wentOnline
              ? 'Danke! Dein Bier ist drin 🍺'
              : onlineError == null
                  ? 'Danke! Dein Bier ist drin – auch in der '
                      'Community-DB für alle 🍺'
                  : 'Lokal gespeichert. Online: $onlineError'),
        ));
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
            if (widget.initialBarcode != null) ...[
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.qr_code_2),
                  title: Text('Barcode ${widget.initialBarcode}'),
                  subtitle: const Text(
                      'Wird gespeichert – der nächste Scan erkennt das Bier '
                      'sofort.'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Foto vom Bier/Etikett – landet mit dem Eintrag in der
            // Community-DB (angemeldet), damit alle das Bier erkennen.
            if (_photoBytes != null) ...[
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _photoBytes!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Foto entfernen',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _photoBytes = null),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async => _pickPhoto(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Foto aufnehmen'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async => _pickPhoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Aus Galerie'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
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
