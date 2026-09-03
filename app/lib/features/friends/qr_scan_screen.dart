import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/brewmates_code.dart';
import '../../data/online/online_service.dart';
import '../../data/providers.dart';
import '../../widgets/kamera_hinweis.dart';

/// „Code scannen": Freundschaft per QR statt über die Namenssuche.
///
/// Ein Scan ist eine Absicht, keine beidseitige Zustimmung — es entsteht
/// deshalb immer nur eine Anfrage, die der andere annehmen muss.
class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key});

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  bool _busy = false;
  String? _message;
  RemoteProfile? _found;

  /// Die soeben gestellte Anfrage — Grundlage fuer „Rueckgaengig".
  String? _gestellteAnfrage;

  /// Ist die Anfrage tatsaechlich rausgegangen? Trennt „gefunden" von
  /// „gestellt": Frueher blieb es beim Finden stehen, und genau das sah
  /// aus wie eine reine Suche.
  bool _gestellt = false;

  bool get _cameraSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    // Gleiche Falle wie beim Bier-Scanner: zxing aus dem eigenen Bundle
    // statt von unpkg.com, sonst erkennt der Scanner hinter VPN oder
    // Werbeblocker schweigend nie einen Code.
    MobileScannerPlatform.instance.setBarcodeLibraryScriptUrl('zxing.js');
  }

  /// Einstieg fuer Tests: Die Kamera laesst sich im Widget-Test nicht
  /// betreiben, der Weg dahinter schon — und dort sass der Fehler, dass
  /// ein Scan gar keine Anfrage stellte.
  @visibleForTesting
  Future<void> handleCodeForTest(String? raw) => _handleCode(raw);

  Future<void> _handleCode(String? raw) async {
    if (_busy || _found != null) return;
    final code = parseBrewMatesCode(raw);
    if (code == null || code.art != BrewMatesCodeArt.freund) {
      // Beide Code-Arten sehen gleich aus, und wer am Tisch schnell
      // scannt, erwischt leicht den falschen. „Kein BrewMates-Code" wäre
      // dann schlicht gelogen — und hilft niemandem weiter.
      setState(() => _message = code == null
          ? 'Das ist kein BrewMates-Code.'
          : codeArtVerwechselt(
              erwartet: BrewMatesCodeArt.freund, bekommen: code.art));
      return;
    }
    final profileId = code.id;
    setState(() {
      _busy = true;
      _message = null;
    });

    final online = await ref.read(onlineServiceProvider.future);
    final me = online?.currentUser;
    if (online == null || me == null) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = 'Dafür musst du angemeldet sein.';
      });
      return;
    }
    if (profileId == me.id) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = 'Das bist du selbst 🍺';
      });
      return;
    }

    final profile = await online.friends.profileById(profileId);
    if (profile == null) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = 'Dieses Profil konnten wir nicht finden.';
      });
      return;
    }

    // Der Scan **ist** die Absicht — er stellt die Anfrage.
    //
    // Vorher endete der Scan beim Anzeigen des Profils und wartete auf
    // einen zweiten Tipp. Fuer den Menschen davor sah das aus, als haette
    // der Code nur gesucht: Er steckte das Telefon ein, und beim anderen
    // kam nie etwas an. Wer einen fremden QR-Code scannt, will genau
    // dieses eine.
    final fehler = await online.friends.sendFriendRequest(profile.id);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _found = profile;
      _gestellt = fehler == null;
      _message = fehler;
    });
    if (fehler == null) {
      // Fuer „Rueckgaengig" brauchen wir die Zeile. Sie kommt ueber die
      // Liste der eigenen offenen Anfragen zurueck — der Insert selbst
      // liefert unter RLS nicht zuverlaessig eine ID.
      final offen = await online.friends.outgoingRequests();
      if (!mounted) return;
      setState(() => _gestellteAnfrage = offen
          .where((a) => a.to.id == profile.id)
          .map((a) => a.friendshipId)
          .firstOrNull);
      ref.invalidate(outgoingRequestsProvider);
    }
    ref.invalidate(onlineFriendsProvider);
  }

  /// Anfrage zuruecknehmen — der Ausweg aus einem Fehlscan.
  Future<void> _zuruecknehmen() async {
    final id = _gestellteAnfrage;
    if (id == null || _busy) return;
    setState(() => _busy = true);
    final online = await ref.read(onlineServiceProvider.future);
    final ok = await online?.friends.withdrawRequest(id) ?? false;
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = ok
          ? 'Anfrage zurueckgenommen.'
          : 'Zuruecknehmen hat nicht geklappt — vielleicht ist sie schon '
              'angenommen.';
      if (ok) {
        _found = null;
        _gestellt = false;
        _gestellteAnfrage = null;
      }
    });
    ref.invalidate(outgoingRequestsProvider);
  }

  void _nochmal() => setState(() {
        _found = null;
        _gestellt = false;
        _gestellteAnfrage = null;
        _message = null;
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Code scannen')),
      body: Column(
        children: [
          if (_cameraSupported && _found == null)
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
                      ausweg: 'Ohne Kamera geht es auch: Such deinen Mate '
                          'über seinen Namen — oder lass ihn deinen Code '
                          'scannen.',
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
                ],
              ),
            )
          else if (!_cameraSupported)
            // Ohne Kamera keine tote Schaltfläche: Auf Desktop bleibt die
            // Namenssuche der Weg.
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Auf diesem Gerät gibt es keine Kamera für den Scanner. '
                    'Such deinen Mate stattdessen über seinen Namen — oder '
                    'lass ihn deinen Code scannen.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
            ),
          if (_found != null)
            Expanded(
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(24),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          child: Text(_found!.avatarEmoji,
                              style: const TextStyle(fontSize: 32)),
                        ),
                        const SizedBox(height: 12),
                        Text(_found!.displayName,
                            style: theme.textTheme.titleLarge),
                        Text('@${_found!.username}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 16),
                        if (_gestellt)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle,
                                  color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text('Anfrage ist raus 🍻',
                                    style: theme.textTheme.titleMedium),
                              ),
                            ],
                          ),
                        const SizedBox(height: 4),
                        if (_gestellt && _gestellteAnfrage != null)
                          TextButton.icon(
                            onPressed: _busy ? null : _zuruecknehmen,
                            icon: const Icon(Icons.undo),
                            label: const Text('Rückgängig'),
                          ),
                        TextButton(
                          onPressed: _busy ? null : _nochmal,
                          child: const Text('Nochmal scannen'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_message != null)
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
