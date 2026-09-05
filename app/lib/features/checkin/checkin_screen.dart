import 'dart:async' show unawaited;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/db/database.dart';
import '../../core/beer_suche.dart';
import '../../core/format.dart' show volumeChoicesMl, formatVolume;
import '../../core/foto_verkleinern.dart';
import '../../data/providers.dart';
import '../../domain/statistics.dart' show estimatedVolumeMl;
import '../../widgets/badge_celebration.dart';
import '../../widgets/beer_thumbnail.dart';
import '../../widgets/rating_input.dart';
import '../../widgets/venue_picker.dart';

/// Bier einchecken: Auswahl → Bewertung → Geschmack/Serving/Ort/Notiz.
class CheckinScreen extends ConsumerStatefulWidget {
  const CheckinScreen({
    super.key,
    this.preselectedBeerId,
    this.preselectedVolumeMl,
  });

  final String? preselectedBeerId;

  /// Aus dem Barcode erkannte Gebindegröße.
  ///
  /// Eine EAN bezeichnet die Handelseinheit — wer eine 0,33er scannt, soll
  /// nicht 0,5 antippen müssen. Übersteuerbar bleibt sie natürlich.
  final int? preselectedVolumeMl;

  @override
  ConsumerState<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends ConsumerState<CheckinScreen> {
  BeerWithBrewery? _selected;
  bool _searchMode = false;
  String _search = '';
  /// `null` = nicht bewertet. Das ist der Anfangszustand und ein
  /// gültiges Ergebnis: Vorher stand hier 3.5, und dieser Wert wurde bei
  /// jedem Check-in mitgeschrieben — auch bei denen, die niemand
  /// beurteilen wollte.
  double? _rating;
  final Set<String> _tags = {};
  ServingStyle? _serving;

  /// Füllmenge in ml. Wird vom Gebinde vorbelegt, bis der Mensch selbst
  /// wählt — danach bleibt seine Wahl stehen.
  late int? _volumeMl = widget.preselectedVolumeMl;

  /// Eine vom Barcode erkannte Menge gilt bereits als gesetzt — sonst
  /// überschriebe die Gebinde-Auswahl sie sofort wieder.
  late bool _volumeTouched = widget.preselectedVolumeMl != null;

  /// Bier, für das die eindeutige Gebindegröße schon nachgeschlagen
  /// wurde. Ohne das liefe die Abfrage bei jedem Neuzeichnen erneut.
  String? _gebindeGeprueftFuer;

  /// Kam die Menge aus der Datenbank statt vom Scan? Dann steht es
  /// unter der Auswahl — eine Zahl, die von selbst dasteht, soll sagen,
  /// woher sie kommt.
  bool _gebindeAusDatenbank = false;

  /// Schlägt die Gebindegröße nach, wenn sie für dieses Bier eindeutig
  /// ist — der Fall „ohne Scan eingecheckt" (Wunsch #144).
  ///
  /// Rührt nichts an, sobald der Mensch selbst gewählt hat: Seine Wahl
  /// gilt, auch wenn die Datenbank etwas anderes weiß.
  Future<void> _gebindeVorbelegen(String beerId) async {
    if (_gebindeGeprueftFuer == beerId || _volumeTouched) return;
    _gebindeGeprueftFuer = beerId;
    final ml =
        await ref.read(databaseProvider).eindeutigeGebindegroesse(beerId);
    if (!mounted || ml == null || _volumeTouched) return;
    setState(() {
      _volumeMl = ml;
      _gebindeAusDatenbank = true;
    });
  }
  final _venueController = TextEditingController();
  final _noteController = TextEditingController();
  bool _venuePrefilled = false;
  bool _saving = false;

  /// Gewähltes Foto (JPEG-Bytes); Upload passiert beim Speichern.
  Uint8List? _photoBytes;

  /// Wer den Check-in sehen darf. `null` heißt: noch nicht angefasst —
  /// dann gilt die Voreinstellung des Kontos, die erst aus der Datenbank
  /// kommt (Funktion 44).
  SessionVisibility? _sichtbarkeit;

  /// Gewähltes Gasthaus aus der gemeinsamen DB (null = Freitext).
  String? _venueId;

  Future<void> _pickVenue() async {
    final selection =
        await showVenuePicker(context, initialQuery: _venueController.text);
    if (selection == null || !mounted) return;
    setState(() {
      _venueId = selection.venueId;
      _venueController.text = selection.venueName;
    });
  }

  @override
  void dispose() {
    _venueController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 80,
      );
      if (file == null) return;
      // `image_picker` sagt Größe und Qualität nur zu — je nach Kamera-App
      // und Browser hält es sie nicht. Nachgerechnet wird hier, in einem
      // eigenen Isolat: Ein 12-Megapixel-Bild zu entschlüsseln dauert auf
      // dem Telefon lange genug, dass die Oberfläche sonst hakt.
      final roh = await file.readAsBytes();
      final bytes = await compute(verkleinereFoto, roh);
      if (!mounted) return;
      setState(() => _photoBytes = bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Foto konnte nicht geladen werden.')));
    }
  }

  Future<void> _save(BeerWithBrewery selected) async {
    setState(() => _saving = true);
    try {
      // Foto zuerst hochladen (braucht Konto + Internet); klappt es nicht,
      // wird der Check-in trotzdem gespeichert — nur ohne Bild.
      String? photoUrl;
      var photoFailed = false;
      if (_photoBytes != null) {
        final online = await ref.read(onlineServiceProvider.future);
        photoUrl = online == null
            ? null
            : await online.checkins.uploadCheckinPhoto(_photoBytes!);
        photoFailed = photoUrl == null;
      }
      final venue = _venueController.text.trim();
      final ergebnis = await ref.read(actionsProvider).createCheckin(
            beerId: selected.beer.id,
            rating: _rating,
            note: _noteController.text,
            venueName: venue.isEmpty ? null : venue,
            venueId: venue.isEmpty ? null : _venueId,
            flavorTags: _tags.toList(),
            servingStyle: _serving,
            volumeMl: _volumeMl,
            photoUrl: photoUrl,
            visibility: _sichtbarkeit,
          );
      if (!mounted) return;
      if (photoFailed) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Foto-Upload hat nicht geklappt (offline?) – '
                'Check-in wurde ohne Bild gespeichert.')));
      }
      final messenger = ScaffoldMessenger.of(context);
      if (ergebnis.celebrations.isNotEmpty) {
        await showCelebration(context, ergebnis.celebrations);
        if (!mounted) return;
      }
      // Angemeldet, aber nicht übertragen? Das sagt die App jetzt, statt
      // „gespeichert" zu melden und die Nachlieferung im Konto-Bildschirm
      // zu verstecken.
      messenger.showSnackBar(SnackBar(
        content: Text(ergebnis.synced
            ? 'Check-in gespeichert 🍺'
            : 'Check-in gespeichert – wird übertragen, sobald du online bist ⏳'),
        duration: Duration(seconds: ergebnis.synced ? 4 : 6),
      ));
      context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pre = widget.preselectedBeerId != null
        ? ref.watch(beerProvider(widget.preselectedBeerId!)).valueOrNull
        : null;
    final selected = _selected ?? (_searchMode ? null : pre);
    final session = ref.watch(myActiveSessionProvider).valueOrNull;

    // Gebindegröße nachschlagen, sobald ein Bier feststeht. Läuft
    // neben dem Aufbau, nicht davor: Der Bildschirm soll nicht auf eine
    // Datenbankabfrage warten, die vielleicht nichts findet.
    if (selected != null) {
      unawaited(_gebindeVorbelegen(selected.beer.id));
    }

    // Venue einmalig aus der aktiven Session vorbefüllen.
    if (session != null && !_venuePrefilled) {
      _venuePrefilled = true;
      if (_venueController.text.isEmpty && session.venueName != null) {
        _venueController.text = session.venueName!;
        _venueId = session.venueId;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Bier einchecken')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (selected == null)
            ..._buildSearch()
          else ...[
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: BeerThumbnail(
                  imageUrl: selected.beer.imageUrl,
                  isAlcoholFree: selected.beer.isAlcoholFree,
                  size: 44,
                ),
                title: Text(selected.beer.name),
                subtitle: Text(
                  '${selected.brewery.name} · ${selected.beer.style}'
                  '${selected.beer.abv != null ? ' · ${selected.beer.abv} %' : ''}',
                ),
                trailing: TextButton(
                  onPressed: () => setState(() {
                    _selected = null;
                    _searchMode = true;
                  }),
                  child: const Text('Ändern'),
                ),
              ),
            ),
          ],
          if (session != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '🍻 Wird deiner Session im '
                '${session.venueName ?? 'Unbekannt'} zugeordnet',
                style: TextStyle(color: theme.colorScheme.onSecondaryContainer),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text('Bewertung', style: theme.textTheme.titleSmall),
          RatingInput(
            rating: _rating,
            onChanged: (wert) => setState(() => _rating = wert),
          ),
          const SizedBox(height: 12),
          Text('Geschmack', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final tag in kFlavorTags)
                FilterChip(
                  label: Text(tag),
                  selected: _tags.contains(tag),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _tags.add(tag);
                    } else {
                      _tags.remove(tag);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Serviert aus (optional)', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<ServingStyle>(
            emptySelectionAllowed: true,
            multiSelectionEnabled: false,
            segments: const [
              ButtonSegment(value: ServingStyle.draft, label: Text('Fass')),
              ButtonSegment(value: ServingStyle.bottle, label: Text('Flasche')),
              ButtonSegment(value: ServingStyle.can, label: Text('Dose')),
              ButtonSegment(
                  value: ServingStyle.growler, label: Text('Growler')),
            ],
            selected: {if (_serving != null) _serving!},
            onSelectionChanged: (selection) => setState(() {
              _serving = selection.isEmpty ? null : selection.first;
              // Gebinde vorbelegen die Menge, solange nichts eigenes
              // gewählt wurde — Growler sind größer als alles andere.
              if (!_volumeTouched && _serving != null) {
                _volumeMl = estimatedVolumeMl[_serving];
              }
            }),
          ),
          const SizedBox(height: 16),
          Text('Wie viel? (optional)', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final ml in volumeChoicesMl)
                ChoiceChip(
                  label: Text(formatVolume(ml)),
                  selected: _volumeMl == ml,
                  onSelected: (selected) => setState(() {
                    _volumeTouched = true;
                    _volumeMl = selected ? ml : null;
                  }),
                ),
            ],
          ),
          if (_gebindeAusDatenbank && !_volumeTouched)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Größe aus der Bierdatenbank — dieses Bier gibt es nur in '
                'dieser Gebindegröße.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _venueController,
            decoration: InputDecoration(
              labelText: 'Wo trinkst du es? (optional)',
              prefixIcon: const Icon(Icons.place_outlined),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Gasthaus aus der Datenbank wählen',
                icon: const Icon(Icons.storefront_outlined),
                onPressed: () async => _pickVenue(),
              ),
            ),
            // Manuelle Eingabe löst die Verknüpfung zum DB-Gasthaus.
            onChanged: (_) => _venueId = null,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notiz (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ...() {
            // Die Voreinstellung steht am Konto; bis sie da ist, zeigt
            // die Auswahl `friends` — denselben Wert, den die App bis
            // 0.10.19 fest geschrieben hat.
            final vorgabe = ref.watch(meProvider).valueOrNull?.defaultVisibility ??
                SessionVisibility.friends;
            final gewaehlt = _sichtbarkeit ?? vorgabe;
            return [
              Text('Wer sieht das?', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<SessionVisibility>(
                segments: [
                  for (final v in SessionVisibility.values)
                    ButtonSegment(value: v, label: Text(visibilityLabel(v))),
                ],
                selected: {gewaehlt},
                onSelectionChanged: (auswahl) =>
                    setState(() => _sichtbarkeit = auswahl.first),
              ),
              const SizedBox(height: 4),
              Text(
                visibilityHint(gewaehlt),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ];
          }(),
          const SizedBox(height: 16),
          Text('Foto (optional)', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (_photoBytes == null)
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Kamera'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Galerie'),
                ),
              ],
            )
          else
            Stack(
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
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton.filledTonal(
                    tooltip: 'Foto entfernen',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _photoBytes = null),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed:
                selected == null || _saving ? null : () => _save(selected),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  /// Die Bier-Auswahl: Vorschläge, sobald das Feld leer ist, sonst
  /// Treffer in einer Reihenfolge, die im Wirtshaus etwas nützt.
  ///
  /// Der häufigste Fall hier ist das Bier **ohne Barcode** — vom Fass,
  /// im Glas serviert. Dann ist diese Suche der einzige Weg, und sie
  /// muss in Sekunden ans Ziel führen (Wunsch #139).
  List<Widget> _buildSearch() {
    final theme = Theme.of(context);
    final suche = _search.trim();
    final results =
        ref.watch(beersProvider((search: _search, style: null))).valueOrNull ??
            const <BeerWithBrewery>[];

    // Leeres Feld: nicht 660 Biere alphabetisch, sondern die eigenen
    // letzten. Wer im Wirtshaus eincheckt, trinkt meistens etwas, das
    // schon einmal im Tagebuch stand — das ist ein Tipp statt zehn.
    final vorschlaege = suche.isEmpty ? _zuletztGetrunken() : const <String>[];
    final liste = suche.isEmpty
        ? [
            for (final id in vorschlaege)
              ...results.where((b) => b.beer.id == id),
          ]
        : (results.toList()
          ..sort((a, b) {
            final rang = trefferRang(
                  name: a.beer.name,
                  brauerei: a.brewery.name,
                  stil: a.beer.style,
                  suche: suche,
                ).compareTo(trefferRang(
                  name: b.beer.name,
                  brauerei: b.brewery.name,
                  stil: b.beer.style,
                  suche: suche,
                ));
            // Bei gleichem Rang bleibt es alphabetisch: Die Datenbank
            // liefert schon so, und `sort` ist in Dart nicht stabil.
            return rang != 0 ? rang : a.beer.name.compareTo(b.beer.name);
          }));

    return [
      TextField(
        // Ohne Autofokus kostet das Nachschlagen einen Tipp mehr, und
        // zwar genau den, den niemand erwartet: Der Bildschirm ist ja
        // aufgegangen, um ein Bier zu suchen.
        autofocus: true,
        onChanged: (value) => setState(() => _search = value),
        decoration: const InputDecoration(
          labelText: 'Bier suchen',
          hintText: 'Anfangsbuchstaben genügen',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 8),
      if (suche.isEmpty && liste.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text('Zuletzt getrunken', style: theme.textTheme.labelMedium),
        ),
      for (final item in liste.take(15))
        ListTile(
          dense: true,
          leading: BeerThumbnail(
            imageUrl: item.beer.imageUrl,
            isAlcoholFree: item.beer.isAlcoholFree,
            size: 32,
          ),
          title: Text(item.beer.name),
          subtitle: Text('${item.brewery.name} · ${item.beer.style}'),
          onTap: () => setState(() {
            _selected = item;
            _searchMode = false;
          }),
        ),
      // Kein Treffer heißt nicht „Pech gehabt": Das Bier fehlt dann
      // wirklich, und der Weg dorthin gehört an diese Stelle — sonst
      // endet das Einchecken hier.
      if (suche.length >= 2 && liste.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nichts gefunden zu „$suche".',
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    context.push('/beers/add?name=${Uri.encodeComponent(suche)}'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Bier anlegen'),
              ),
            ],
          ),
        ),
      if (liste.length > 15)
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Text(
            'Noch ${liste.length - 15} weitere — tippe mehr Buchstaben.',
            style: theme.textTheme.bodySmall,
          ),
        ),
    ];
  }

  /// Bier-IDs des eigenen Tagebuchs, jüngste zuerst, ohne Wiederholung.
  List<String> _zuletztGetrunken() {
    final diary =
        ref.watch(myDiaryProvider).valueOrNull ?? const <CheckinDetails>[];
    final gesehen = <String>{};
    for (final eintrag in diary) {
      gesehen.add(eintrag.checkin.beerId);
      if (gesehen.length == 6) break;
    }
    return gesehen.toList();
  }
}
