import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart' show volumeChoicesMl, formatVolume;
import '../../data/providers.dart';
import '../../widgets/beer_picker.dart';

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
  /// Gebindegröße des **gescannten** Barcodes.
  ///
  /// Vorbelegt mit einem halben Liter, weil das im DACH-Raum der
  /// Normalfall ist. Die Größe hängt am Barcode und nicht am Bier: Ein
  /// Bier hat mehrere EANs, und genau darin unterscheiden sie sich.
  int? _volumeMl = 500;

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

  /// Vorhandenes Bier suchen und den gescannten Barcode dort nachtragen.
  ///
  /// Der haeufigste Grund fuer eine unbekannte EAN ist nicht ein neues
  /// Bier, sondern ein bekanntes **ohne diesen Barcode** — eine EAN
  /// bezeichnet die Handelseinheit, nicht das Getraenk. Ein Duplikat
  /// anzulegen waere hier der teuerste Fehler: Zwei Eintraege fuer
  /// dasselbe Bier trennen Bewertungen, Abzeichen und Statistik.
  Future<void> _sucheVorhandenes() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final gewaehlt = await showBeerPicker(context);
    if (gewaehlt == null || !mounted) return;

    final ean = widget.initialBarcode;
    if (ean == null) {
      // Ohne Barcode gibt es nichts nachzutragen — dann fuellen wir nur
      // die Felder, damit man von dort weiterarbeiten kann.
      setState(() {
        _nameController.text = gewaehlt.beer.name;
        _styleController.text = gewaehlt.beer.style;
        _breweryController.text = gewaehlt.brewery.name;
        _countryController.text = gewaehlt.brewery.country;
        _cityController.text = gewaehlt.brewery.city;
      });
      return;
    }

    final geaendert =
        await ref.read(databaseProvider).addBarcodeToBeer(gewaehlt.beer.id, ean);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(geaendert
          ? 'Barcode zu „${gewaehlt.beer.name}" ergaenzt 🍺'
          : '„${gewaehlt.beer.name}" kannte diesen Barcode schon.'),
    ));
    navigator.pop();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final abvText = _abvController.text.trim().replaceAll(',', '.');
      final description = _descriptionController.text.trim();
      final abv = abvText.isEmpty ? null : double.tryParse(abvText);
      // Nichts ist Pflicht. Wer scannt, will einchecken — nicht einen
      // Datensatz pflegen. Was fehlt, traegt spaeter jemand nach; genau
      // dafuer gibt es die Bearbeitung durch die Community (ab Stufe 2).
      // Ein leeres Feld bekommt einen ehrlichen Platzhalter statt einer
      // erfundenen Angabe.
      final marke = _nameController.text.trim();
      final id = await ref.read(actionsProvider).addBeer(
            name: marke.isEmpty ? 'Unbekanntes Bier' : marke,
            style: _styleController.text.trim(),
            breweryName: _breweryController.text.trim().isEmpty
                ? 'Unbekannte Brauerei'
                : _breweryController.text.trim(),
            breweryCountry: _countryController.text.trim(),
            breweryCity: _cityController.text.trim(),
            abv: abv,
            isAlcoholFree: _isAlcoholFree,
            description: description.isEmpty ? null : description,
            barcode: widget.initialBarcode,
          );

      // Die Größe gehört an den Barcode, nicht ans Bier — sie ist genau
      // das, was zwei EANs desselben Biers unterscheidet. Beim nächsten
      // Scan füllt der Check-in sie von selbst aus.
      final ean = widget.initialBarcode;
      if (ean != null && _volumeMl != null) {
        await ref.read(databaseProvider).setBarcodeVolume(ean, _volumeMl!);
      }
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
              decoration: InputDecoration(
                labelText: 'Marke',
                hintText: 'z. B. Stiegl-Goldbraeu',
                border: const OutlineInputBorder(),
                // Die Lupe sucht im vorhandenen Bestand. Der haeufigste
                // Fall bei einer unbekannten EAN ist naemlich nicht „neues
                // Bier", sondern „bekanntes Bier ohne diesen Barcode" —
                // eine EAN bezeichnet die Handelseinheit, und 0,33-Flasche,
                // 0,5-Dose und Sixpack tragen je eigene Nummern.
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Vorhandenes Bier suchen',
                  onPressed: _sucheVorhandenes,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _styleController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Sorte/Typ',
                hintText: 'z. B. Helles, IPA …',
                border: OutlineInputBorder(),
              ),
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
            Text('Gebindegröße', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Gehört zum gescannten Barcode: Dieselbe Marke in 0,33 und '
              '0,5 hat zwei verschiedene EANs.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final ml in volumeChoicesMl)
                  ChoiceChip(
                    label: Text(formatVolume(ml)),
                    selected: _volumeMl == ml,
                    // Nochmal tippen hebt die Auswahl auf — „weiß ich
                    // nicht" ist eine ehrlichere Angabe als eine geratene.
                    onSelected: (an) =>
                        setState(() => _volumeMl = an ? ml : null),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _breweryController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Brauerei',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _countryController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Land',
                      hintText: 'Deutschland',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cityController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Stadt',
                      border: OutlineInputBorder(),
                    ),
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
