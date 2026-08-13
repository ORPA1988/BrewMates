import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/db/database.dart';
import '../../data/location_service.dart';
import '../../data/providers.dart';
import '../../data/venue_sync.dart';
import '../../widgets/badge_celebration.dart';

/// Gasthaus anlegen bzw. bearbeiten. Online-first: gespeichert wird direkt
/// in der gemeinsamen Supabase-DB (RLS entscheidet, was erlaubt ist);
/// der lokale Cache wird sofort nachgezogen.
class VenueEditScreen extends ConsumerStatefulWidget {
  const VenueEditScreen({super.key, this.venueId, this.initialName});

  /// null = neues Gasthaus anlegen.
  final String? venueId;
  final String? initialName;

  @override
  ConsumerState<VenueEditScreen> createState() => _VenueEditScreenState();
}

class _VenueEditScreenState extends ConsumerState<VenueEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _hoursController = TextEditingController();
  final _priceHalfController = TextEditingController();
  final _priceThirdController = TextEditingController();
  String _category = 'gasthaus';
  double? _latitude;
  double? _longitude;
  bool _busy = false;
  bool _loaded = false;

  bool get _isNew => widget.venueId == null;

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) {
      _nameController.text = widget.initialName!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _hoursController.dispose();
    _priceHalfController.dispose();
    _priceThirdController.dispose();
    super.dispose();
  }

  void _prefill(Venue venue) {
    if (_loaded) return;
    _loaded = true;
    _nameController.text = venue.name;
    _cityController.text = venue.city ?? '';
    _addressController.text = venue.address ?? '';
    _hoursController.text = venue.openingHours ?? '';
    _priceHalfController.text =
        venue.priceHalfL?.toStringAsFixed(2).replaceAll('.', ',') ?? '';
    _priceThirdController.text =
        venue.priceThirdL?.toStringAsFixed(2).replaceAll('.', ',') ?? '';
    _category = venue.category;
    _latitude = venue.latitude;
    _longitude = venue.longitude;
  }

  static String _fieldLabel(String column) => switch (column) {
        'price_half_l' => 'den 0,5-l-Preis',
        'price_third_l' => 'den 0,3-l-Preis',
        'opening_hours' => 'die Öffnungszeiten',
        'address' => 'die Adresse',
        'city' => 'den Ort',
        'name' => 'den Namen',
        'category' => 'die Kategorie',
        'latitude' || 'longitude' => 'die Position',
        'verified' => 'den Verifiziert-Status',
        _ => column,
      };

  double? _parsePrice(String raw) {
    final text = raw.trim().replaceAll(',', '.').replaceAll('€', '').trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  String? _validatePrice(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = _parsePrice(value);
    if (parsed == null || parsed < 0 || parsed > 99) {
      return 'Bitte einen Preis wie 4,20 angeben';
    }
    return null;
  }

  Future<void> _useCurrentLocation() async {
    final result =
        await ref.read(locationServiceProvider).getCurrentPosition();
    if (!mounted) return;
    if (result is LocationGranted) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Position übernommen 📍 – das Gasthaus erscheint '
              'damit auf der Karte.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Kein Standort verfügbar – das Gasthaus wird ohne '
              'Kartenposition gespeichert.')));
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final online = await ref.read(onlineServiceProvider.future);
    if (online == null || online.currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Gasthaus-Pflege braucht ein Konto und Internet.')));
      return;
    }
    setState(() => _busy = true);
    try {
      String? error;
      if (_isNew) {
        final (_, err) = await online.createVenue(
          name: _nameController.text,
          category: _category,
          address: _addressController.text,
          city: _cityController.text,
          latitude: _latitude,
          longitude: _longitude,
          openingHours: _hoursController.text,
          priceHalfL: _parsePrice(_priceHalfController.text),
          priceThirdL: _parsePrice(_priceThirdController.text),
        );
        error = err;
      } else {
        error = await online.updateVenue(widget.venueId!, {
          'name': _nameController.text.trim(),
          'category': _category,
          'address': _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          'city': _cityController.text.trim().isEmpty
              ? null
              : _cityController.text.trim(),
          'latitude': _latitude,
          'longitude': _longitude,
          'opening_hours': _hoursController.text.trim().isEmpty
              ? null
              : _hoursController.text.trim(),
          'price_half_l': _parsePrice(_priceHalfController.text),
          'price_third_l': _parsePrice(_priceThirdController.text),
        });
      }
      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      // Cache sofort nachziehen, damit Picker/Karte den Stand zeigen.
      await ref.read(venueSyncServiceProvider).sync(online);
      ref.invalidate(venueSyncProvider);
      if (!mounted) return;
      if (_isNew) {
        // Datenpflege-Badges (z. B. 🗺 Kartograph) direkt würdigen.
        final earned = await ref.read(actionsProvider).evaluateBadges();
        if (!mounted) return;
        if (earned.isNotEmpty) {
          await showBadgeCelebration(context, earned);
          if (!mounted) return;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isNew
              ? 'Danke! Das Gasthaus ist für alle BrewMates da 🍻'
              : 'Gespeichert – danke für die Datenpflege! 🍻')));
      context.pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!_isNew) {
      final venue = ref.watch(venueProvider(widget.venueId!)).valueOrNull;
      if (venue != null) _prefill(venue);
    }
    // Duplikat-Schutz-UX: ähnliche bestehende Gasthäuser live anzeigen.
    final similar = _isNew && _nameController.text.trim().length >= 3
        ? (ref
                .watch(venueSearchProvider(_nameController.text))
                .valueOrNull ??
            const <Venue>[])
        : const <Venue>[];

    return Scaffold(
      appBar: AppBar(
          title: Text(_isNew ? 'Neues Gasthaus' : 'Gasthaus bearbeiten')),
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
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Bitte einen Namen angeben'
                  : null,
              onChanged: (_) => setState(() {}),
            ),
            if (similar.isNotEmpty) ...[
              const SizedBox(height: 8),
              Card(
                color: theme.colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gibt es das schon?',
                          style: theme.textTheme.titleSmall),
                      for (final v in similar.take(3))
                        Text(
                            '• ${v.name}'
                            '${v.city == null ? '' : ' (${v.city})'}',
                            style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final category in venueCategories)
                  ChoiceChip(
                    label: Text('${venueCategoryEmoji(category)} '
                        '${venueCategoryLabel(category)}'),
                    selected: _category == category,
                    onSelected: (_) => setState(() => _category = category),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Ort',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _addressController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Adresse',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _useCurrentLocation,
              icon: const Icon(Icons.my_location, size: 18),
              label: Text(_latitude == null
                  ? '📍 Aktuellen Standort übernehmen'
                  : '📍 Position gesetzt '
                      '(${_latitude!.toStringAsFixed(4)}, '
                      '${_longitude!.toStringAsFixed(4)})'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _hoursController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Öffnungszeiten',
                hintText: 'z. B. Mo–Sa 11–24 Uhr, So Ruhetag',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceHalfController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: '🍺 Preis 0,5 l (€)',
                      hintText: '4,20',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validatePrice,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _priceThirdController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Preis 0,3 l (€)',
                      hintText: '3,10',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validatePrice,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _busy ? null : _save,
              child: Text(_isNew ? 'Gasthaus anlegen' : 'Speichern'),
            ),
            // Änderungsverlauf (Audit-Log): wer hat zuletzt was gepflegt?
            if (!_isNew) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('Änderungsverlauf',
                    style: theme.textTheme.titleSmall),
                children: [
                  FutureBuilder(
                    future: ref
                        .read(onlineServiceProvider.future)
                        .then((online) => online == null
                            ? Future.value(const [])
                            : online.editHistory('venue', widget.venueId!)),
                    builder: (context, snapshot) {
                      final entries = snapshot.data ?? const [];
                      if (snapshot.connectionState !=
                          ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(
                              child: CircularProgressIndicator()),
                        );
                      }
                      if (entries.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Noch keine Einträge (oder offline).'),
                        );
                      }
                      return Column(
                        children: [
                          for (final e in entries)
                            ListTile(
                              dense: true,
                              leading: Icon(
                                  e.action == 'insert'
                                      ? Icons.add_circle_outline
                                      : Icons.edit_outlined,
                                  size: 18),
                              title: Text(
                                '${e.username == null ? 'Jemand' : '@${e.username}'} '
                                '${e.action == 'insert' ? 'hat den Eintrag angelegt' : 'hat ${e.changes.keys.map(_fieldLabel).join(', ')} geändert'}',
                              ),
                              subtitle:
                                  Text(timeAgo(e.createdAt)),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Änderungen sind für alle BrewMates sichtbar. Bitte nur '
              'echte Angaben eintragen – danke! 💛',
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
