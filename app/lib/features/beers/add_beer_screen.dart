import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart' show volumeChoicesMl, formatVolume;
import '../../core/foto_verkleinern.dart';
import '../../data/db/database.dart';
import '../../data/online/online_service.dart' show RemoteBeer;
import '../../data/providers.dart';
import '../../widgets/beer_picker.dart';
import '../../widgets/beer_thumbnail.dart';
import '../../widgets/suggest_list.dart';

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

  /// Was gerade im Marke-Feld steht — Grundlage der Live-Vorschläge.
  String _markeSuche = '';

  /// Nutzererstellte Biere anderer, vom Server nachgeladen.
  ///
  /// Die lokale Datenbank kennt die gebündelten Biere sofort; was ein
  /// anderer gestern angelegt hat, steht nur auf dem Server. Deshalb
  /// erst lokal (ohne Wartezeit), dann dieser Nachschlag.
  List<RemoteBeer> _serverTreffer = const [];
  Timer? _entprellung;

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
    _entprellung?.cancel();
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
      // Siehe `core/foto_verkleinern.dart`: Was der Picker zusagt, hält
      // er nicht überall. Nachgerechnet wird in einem eigenen Isolat.
      final roh = await file.readAsBytes();
      final bytes = await compute(verkleinereFoto, roh);
      if (mounted) setState(() => _photoBytes = bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Foto konnte nicht geladen werden.')));
      }
    }
  }

  /// Reaktion auf jeden Tastendruck im Marke-Feld.
  ///
  /// Der lokale Teil der Vorschläge kommt ohne Zutun: Er hängt an
  /// [_markeSuche] und aktualisiert sich mit dem Neuzeichnen. Nur die
  /// Server-Nachladung wird entprellt — sonst schickte jeder Buchstabe
  /// eine Abfrage los, und die Antworten kämen in beliebiger Reihenfolge
  /// zurück.
  void _markeGetippt(String wert) {
    setState(() {
      _markeSuche = wert;
      // Alte Server-Treffer gehören zu einem alten Wort. Sie stehen zu
      // lassen wäre schlimmer als eine kurz leere Liste: Sie sähen aus
      // wie Treffer für das, was gerade dasteht.
      _serverTreffer = const [];
    });
    _entprellung?.cancel();
    _entprellung = Timer(const Duration(milliseconds: 300), () async {
      final gesucht = wert.trim();
      if (gesucht.length < 2) return;
      final online = await ref.read(onlineServiceProvider.future);
      final treffer = await online?.searchCommunityBeers(gesucht) ?? const [];
      // Zwischenzeitlich weitergetippt? Dann gehört diese Antwort nicht
      // mehr zur Frage.
      if (!mounted || _nameController.text != wert) return;
      setState(() => _serverTreffer = treffer);
    });
  }

  /// Ein vom Server vorgeschlagenes Bier übernehmen.
  ///
  /// Es liegt noch nicht in der lokalen Datenbank — also erst eintragen
  /// (denselben Weg, den der Scanner bei einem Community-Treffer geht),
  /// dann wie ein lokaler Treffer behandeln. Das ist der Punkt der
  /// ganzen Funktion: kein zweiter Eintrag für dasselbe Bier.
  Future<void> _uebernehmenVomServer(RemoteBeer treffer) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final router = GoRouter.of(context);
    final ean = widget.initialBarcode;
    final db = ref.read(databaseProvider);

    final id = await ref.read(actionsProvider).addBeer(
          name: treffer.name,
          style: treffer.style,
          breweryName: treffer.breweryName ?? 'Unbekannte Brauerei',
          breweryCountry: treffer.breweryCountry ?? '',
          breweryCity: treffer.breweryCity ?? '',
          abv: treffer.abv,
          isAlcoholFree: treffer.isAlcoholFree,
          description: treffer.description,
          barcode: ean,
        );
    if (ean != null && _volumeMl != null) {
      await db.setBarcodeVolume(ean, _volumeMl!);
    }
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text('„${treffer.name}" übernommen 🍺'),
    ));
    // Ohne Barcode zum eben uebernommenen Bier weiter — aus demselben
    // Grund wie oben: Im Formular zu bleiben hiesse, ein „Speichern"
    // anzubieten, das denselben Eintrag ein zweites Mal anlegt.
    if (ean == null) {
      unawaited(router.pushReplacement('/beer/$id'));
      return;
    }
    navigator.pop();
  }

  /// Die Vorschlagsliste zum aktuellen Stand des Marke-Feldes.
  ///
  /// Lokale Treffer zuerst, danach die vom Server — und was lokal schon
  /// dasteht, wird vom Server nicht doppelt angeboten.
  List<SuggestEntry> _vorschlaege() {
    final begriff = _markeSuche.trim();
    if (begriff.length < 2) return const [];

    final lokal = ref
            .watch(beersProvider((search: begriff, style: null)))
            .valueOrNull ??
        const <BeerWithBrewery>[];
    final bekannt = {for (final t in lokal) t.beer.name.toLowerCase()};

    return [
      for (final t in lokal)
        SuggestEntry(
          titel: t.beer.name,
          untertitel: '${t.brewery.name} · ${t.beer.style}',
          bild: BeerThumbnail(
            imageUrl: t.beer.imageUrl,
            isAlcoholFree: t.beer.isAlcoholFree,
            size: 32,
          ),
          onTap: () => _uebernehmen(t),
        ),
      for (final t in _serverTreffer)
        if (!bekannt.contains(t.name.toLowerCase()))
          SuggestEntry(
            titel: t.name,
            untertitel: [t.breweryName, t.style]
                .where((e) => e != null && e.isNotEmpty)
                .join(' · '),
            // `labelUrl` ist beim Server-Treffer das Etikettfoto des
            // Nutzers, der das Bier angelegt hat — dieselbe Rolle wie
            // `imageUrl` beim lokalen Datensatz.
            bild: BeerThumbnail(
              imageUrl: t.labelUrl,
              isAlcoholFree: t.isAlcoholFree,
              size: 32,
            ),
            vomServer: true,
            onTap: () => _uebernehmenVomServer(t),
          ),
    ];
  }

  /// Vorhandenes Bier suchen und den gescannten Barcode dort nachtragen.
  ///
  /// Der haeufigste Grund fuer eine unbekannte EAN ist nicht ein neues
  /// Bier, sondern ein bekanntes **ohne diesen Barcode** — eine EAN
  /// bezeichnet die Handelseinheit, nicht das Getraenk. Ein Duplikat
  /// anzulegen waere hier der teuerste Fehler: Zwei Eintraege fuer
  /// dasselbe Bier trennen Bewertungen, Abzeichen und Statistik.
  Future<void> _sucheVorhandenes() async {
    final gewaehlt = await showBeerPicker(context);
    if (gewaehlt == null || !mounted) return;
    await _uebernehmen(gewaehlt);
  }

  /// Ein vorhandenes Bier übernehmen — aus der Lupe oder aus einem
  /// Live-Vorschlag. Beide Wege enden hier, damit sie sich nicht
  /// auseinanderentwickeln.
  Future<void> _uebernehmen(BeerWithBrewery gewaehlt) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final router = GoRouter.of(context);
    final ean = widget.initialBarcode;
    if (ean == null) {
      // Ohne Barcode gibt es nichts nachzutragen — also zum vorhandenen
      // Bier weiter, statt im Anlegen-Formular zu bleiben.
      //
      // Vorher wurden hier die Felder gefuellt „damit man weiterarbeiten
      // kann". Das war eine Falle: Sie standen danach auf einem Bier,
      // das es exakt so schon gibt, und „Speichern" blieb scharf. Ein
      // Druck darauf legte es lokal ein zweites Mal an und schickte es
      // ausserdem als neuen Eintrag an den Server — genau das Duplikat,
      // das diese Auswahl verhindern soll.
      messenger.showSnackBar(SnackBar(
        content: Text('„${gewaehlt.beer.name}" gibt es schon.'),
      ));
      unawaited(router.pushReplacement('/beer/${gewaehlt.beer.id}'));
      return;
    }

    final geaendert =
        await ref.read(databaseProvider).addBarcodeToBeer(gewaehlt.beer.id, ean);
    if (_volumeMl != null) {
      await ref.read(databaseProvider).setBarcodeVolume(ean, _volumeMl!);
    }
    // Auch für andere hinterlegen — ein nachgetragener Code ist der
    // häufigste und nützlichste Community-Beitrag überhaupt.
    final online = await ref.read(onlineServiceProvider.future);
    await online?.upsertBeerBarcode(ean, gewaehlt.beer.id,
        volumeMl: _volumeMl);
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
        // Barcode und Größe für alle hinterlegen (0028). Getrennt vom
        // Bier, weil eine EAN die Handelseinheit bezeichnet — dasselbe
        // Bier in 0,33 und 0,5 hat zwei Nummern.
        if (ean != null) {
          await online.upsertBeerBarcode(ean, id, volumeMl: _volumeMl);
        }
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
              onChanged: _markeGetippt,
            ),
            // Live-Vorschläge direkt unter der Zeile: Wer „Baumg" tippt,
            // sieht „Baumgartner Märzen" und „Baumgartner Pils", bevor er
            // sie zu Ende geschrieben — oder ein Duplikat angelegt — hat.
            SuggestList(eintraege: _vorschlaege()),
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
