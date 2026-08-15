import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/db/database.dart';
import '../../core/format.dart' show volumeChoicesMl, formatVolume;
import '../../data/providers.dart';
import '../../domain/statistics.dart' show estimatedVolumeMl;
import '../../widgets/badge_celebration.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/venue_picker.dart';

/// Bier einchecken: Auswahl → Bewertung → Geschmack/Serving/Ort/Notiz.
class CheckinScreen extends ConsumerStatefulWidget {
  const CheckinScreen({super.key, this.preselectedBeerId});

  final String? preselectedBeerId;

  @override
  ConsumerState<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends ConsumerState<CheckinScreen> {
  BeerWithBrewery? _selected;
  bool _searchMode = false;
  String _search = '';
  double _rating = 3.5;
  final Set<String> _tags = {};
  ServingStyle? _serving;

  /// Füllmenge in ml. Wird vom Gebinde vorbelegt, bis der Mensch selbst
  /// wählt — danach bleibt seine Wahl stehen.
  int? _volumeMl;
  bool _volumeTouched = false;
  final _venueController = TextEditingController();
  final _noteController = TextEditingController();
  bool _venuePrefilled = false;
  bool _saving = false;

  /// Gewähltes Foto (JPEG-Bytes); Upload passiert beim Speichern.
  Uint8List? _photoBytes;

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
      final bytes = await file.readAsBytes();
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
            : await online.uploadCheckinPhoto(_photoBytes!);
        photoFailed = photoUrl == null;
      }
      final venue = _venueController.text.trim();
      final earned = await ref.read(actionsProvider).createCheckin(
            beerId: selected.beer.id,
            rating: _rating,
            note: _noteController.text,
            venueName: venue.isEmpty ? null : venue,
            venueId: venue.isEmpty ? null : _venueId,
            flavorTags: _tags.toList(),
            servingStyle: _serving,
            volumeMl: _volumeMl,
            photoUrl: photoUrl,
          );
      if (!mounted) return;
      if (photoFailed) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Foto-Upload hat nicht geklappt (offline?) – '
                'Check-in wurde ohne Bild gespeichert.')));
      }
      final messenger = ScaffoldMessenger.of(context);
      if (earned.isNotEmpty) {
        await showCelebration(context, earned);
        if (!mounted) return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Check-in gespeichert 🍺')),
      );
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
                leading: selected.beer.imageUrl == null
                    ? Text(
                        selected.beer.isAlcoholFree ? '💧' : '🍺',
                        style: const TextStyle(fontSize: 28),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          selected.beer.imageUrl!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Text(
                            selected.beer.isAlcoholFree ? '💧' : '🍺',
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
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
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _rating,
                  min: 0,
                  max: 5,
                  divisions: 20,
                  label: _rating.toStringAsFixed(2),
                  onChanged: (value) => setState(() => _rating = value),
                ),
              ),
              RatingStars(rating: _rating, size: 20),
              const SizedBox(width: 8),
              Text(_rating.toStringAsFixed(2)),
            ],
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

  List<Widget> _buildSearch() {
    final results =
        ref.watch(beersProvider((search: _search, style: null))).valueOrNull ??
            const <BeerWithBrewery>[];
    return [
      TextField(
        onChanged: (value) => setState(() => _search = value),
        decoration: const InputDecoration(
          labelText: 'Bier suchen',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 8),
      for (final item in results.take(15))
        ListTile(
          dense: true,
          leading: Text(item.beer.isAlcoholFree ? '💧' : '🍺'),
          title: Text(item.beer.name),
          subtitle: Text('${item.brewery.name} · ${item.beer.style}'),
          onTap: () => setState(() {
            _selected = item;
            _searchMode = false;
          }),
        ),
    ];
  }
}
