import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/brewmates_code.dart';
import '../../data/providers.dart';
import '../../widgets/kamera_hinweis.dart';

/// „Crew-Code scannen": beitreten, indem man den Code am Tisch scannt.
///
/// Der Einladungscode ist eine UUID — 36 Zeichen, die niemand abtippt,
/// ohne sich zu vertippen. Bisher blieb nur „kopieren und schicken", was
/// genau dort scheitert, wo eine Crew entsteht: am Tisch, zwischen
/// Menschen, die nebeneinander sitzen.
///
/// Anders als beim Freundes-Scan gibt es hier **keine Zustimmung des
/// anderen**: Wer den Code hat, ist drin. Das ist Absicht und war schon
/// beim getippten Code so — der Code IST die Einladung.
///
/// Welcher Crew man beitritt, steht **nicht** vorher da: Im Code steckt
/// nur die UUID, und den Namen dazu kennt der Server erst, wenn man
/// Mitglied ist (die RLS zeigt fremde Crews nicht). Ein Vorschau-Schritt
/// wäre also entweder gelogen oder ein neues Leseloch. Die Bestätigung
/// hinterher nennt dafür klar, dass es geklappt hat, und die Crew steht
/// sofort in der Liste.
class CrewScanScreen extends ConsumerStatefulWidget {
  const CrewScanScreen({super.key});

  @override
  ConsumerState<CrewScanScreen> createState() => _CrewScanScreenState();
}

class _CrewScanScreenState extends ConsumerState<CrewScanScreen> {
  bool _busy = false;
  String? _message;

  /// Beigetreten — dann bleibt der Scanner aus, damit derselbe Code nicht
  /// gleich noch einmal gelesen wird.
  bool _fertig = false;

  bool get _cameraSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    // Gleiche Falle wie bei den anderen beiden Scannern: zxing aus dem
    // eigenen Bundle statt von unpkg.com.
    MobileScannerPlatform.instance.setBarcodeLibraryScriptUrl('zxing.js');
  }

  /// Einstieg für Tests: Die Kamera lässt sich im Widget-Test nicht
  /// betreiben, der Weg dahinter schon.
  @visibleForTesting
  Future<void> handleCodeForTest(String? raw) => _handleCode(raw);

  Future<void> _handleCode(String? raw) async {
    if (_busy || _fertig) return;
    final code = parseBrewMatesCode(raw);
    if (code == null || code.art != BrewMatesCodeArt.crew) {
      setState(() => _message = code == null
          ? 'Das ist kein BrewMates-Code.'
          : codeArtVerwechselt(
              erwartet: BrewMatesCodeArt.crew, bekommen: code.art));
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });
    final online = await ref.read(onlineServiceProvider.future);
    if (online == null) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = 'Dafür musst du angemeldet sein.';
      });
      return;
    }

    final fehler = await online.joinCrew(code.id);
    ref.invalidate(myCrewsProvider);
    if (!mounted) return;
    setState(() {
      _busy = false;
      // Nur bei Erfolg ist Schluss. Ein „Diesen Einladungscode gibt es
      // nicht" darf den Scanner nicht abschalten — der nächste Versuch
      // ist ja genau das, was jetzt ansteht.
      _fertig = fehler == null;
      _message = fehler ?? 'Willkommen in der Crew! 🍻';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Crew-Code scannen')),
      body: Column(
        children: [
          // Reihenfolge zählt: Der Erfolg steht vor jeder
          // Plattformfrage. Stünde die Desktop-Ausrede zuerst, bekäme
          // dort niemand je die Bestätigung zu sehen — auch nicht, wenn
          // der Beitritt geklappt hat.
          if (_fertig)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🍻', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text('Du bist dabei!',
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(
                        'Die Crew steht jetzt in deiner Liste.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Zu meinen Crews'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_cameraSupported)
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: MobileScannerController(
                      formats: const [BarcodeFormat.qrCode],
                    ),
                    errorBuilder: (context, fehler, _) =>
                        KameraHinweis.ausFehler(
                      fehler,
                      ausweg: 'Ohne Kamera geht es auch: Lass dir den '
                          'Einladungscode schicken und füge ihn unter '
                          '„Mit Code beitreten" ein.',
                    ),
                    onDetect: (capture) =>
                        _handleCode(capture.barcodes.firstOrNull?.rawValue),
                  ),
                  Center(
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: theme.colorScheme.primary, width: 3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  if (_busy) const Center(child: CircularProgressIndicator()),
                ],
              ),
            )
          else
            // Ohne Kamera keine tote Schaltfläche: Auf Desktop bleibt der
            // getippte Code der Weg.
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Auf diesem Gerät gibt es keine Kamera für den Scanner. '
                    'Lass dir den Einladungscode schicken und füge ihn unter '
                    '„Mit Code beitreten" ein.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
            ),
          if (_message != null && !_fertig)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}
