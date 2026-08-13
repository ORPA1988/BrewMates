import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../widgets/rating_stars.dart';
import 'barcode_lookup.dart';

/// Hero-Funktion „🍺 Bier scannen": Kamera-Scan auf Android/iOS,
/// manuelle EAN-Eingabe überall (und als einziger Weg auf Desktop).
/// Die Lookup-Logik lebt in [BarcodeLookup] — dieser Screen ist nur UI.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final _eanController = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _cameraSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void dispose() {
    _eanController.dispose();
    super.dispose();
  }

  Future<void> _handleEan(String rawEan) async {
    final ean = rawEan.replaceAll(RegExp(r'\D'), '');
    if (!BarcodeLookup.isValidEan(ean)) {
      setState(
          () => _error = 'Ein Barcode hat 8 oder 13 Ziffern ($ean erkannt).');
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Sicherstellen, dass die gebündelte Community-DB importiert ist
      // (relevant direkt nach der Installation); nie länger als kurz
      // blockieren – der Lookup funktioniert notfalls auch ohne.
      await ref
          .read(communityBootstrapProvider.future)
          .timeout(const Duration(seconds: 5), onTimeout: () {});
      final result = await ref.read(barcodeLookupProvider).lookup(ean);
      if (!mounted) return;
      switch (result) {
        case LocalBeerFound(:final beer):
          await _showFoundSheet(beer);
        case OffProductFound(:final ean, :final name, :final brand):
          context.pushReplacement(Uri(
            path: '/beers/add',
            queryParameters: {
              'ean': ean,
              if (name != null) 'name': name,
              if (brand != null) 'brewery': brand,
            },
          ).toString());
        case BarcodeUnknown(:final ean):
          context.pushReplacement(
              Uri(path: '/beers/add', queryParameters: {'ean': ean})
                  .toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Treffer-Bestätigung: zeigt das erkannte Bier (mit Etikett-Foto,
  /// falls vorhanden), bevor es weitergeht — so sieht man sofort, ob der
  /// Scan das richtige Produkt erwischt hat. „Weiter scannen" bleibt hier.
  Future<void> _showFoundSheet(BeerWithBrewery found) async {
    final beer = found.beer;
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Gefunden! 🎯', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (beer.imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        beer.imageUrl!,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Text(
                          beer.isAlcoholFree ? '💧' : '🍺',
                          style: const TextStyle(fontSize: 40),
                        ),
                      ),
                    )
                  else
                    Text(
                      beer.isAlcoholFree ? '💧' : '🍺',
                      style: const TextStyle(fontSize: 40),
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(beer.name,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Text(
                          '${found.brewery.name} · ${beer.style}'
                          '${beer.abv != null ? ' · ${beer.abv} %' : ''}',
                          style: theme.textTheme.bodySmall,
                        ),
                        if (beer.communityRating != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: RatingStars(
                                rating: beer.communityRating!, size: 16),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  context.pushReplacement('/checkin?beer=${beer.id}');
                },
                icon: const Text('✅'),
                label: const Text('Einchecken'),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      context.pushReplacement('/beer/${beer.id}');
                    },
                    child: const Text('Details ansehen'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Weiter scannen'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('🍺 Bier scannen')),
      body: Column(
        children: [
          if (_cameraSupported)
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: MobileScannerController(
                      formats: const [
                        BarcodeFormat.ean13,
                        BarcodeFormat.ean8,
                      ],
                    ),
                    onDetect: (capture) {
                      final value = capture.barcodes.firstOrNull?.rawValue;
                      if (value != null && !_busy) {
                        _handleEan(value);
                      }
                    },
                  ),
                  // Ziel-Rahmen
                  Center(
                    child: Container(
                      width: 260,
                      height: 140,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: theme.colorScheme.primary, width: 3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                            'Barcode der Flasche/Dose in den Rahmen halten'),
                      ),
                    ),
                  ),
                  if (_busy) const Center(child: CircularProgressIndicator()),
                ],
              ),
            )
          else
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('📷', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 8),
                      Text(
                        'Kamera-Scan gibt es auf dem Handy.\n'
                        'Hier kannst du den Barcode eintippen:',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Manuelle Eingabe — auf Desktop der Hauptweg, mobil der Fallback.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_error!,
                          style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _eanController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'EAN eintippen (8 oder 13 Ziffern)',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: _handleEan,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _handleEan(_eanController.text),
                        child: const Text('Suchen'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
