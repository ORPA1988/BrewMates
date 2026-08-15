import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/online/online_service.dart';
import '../../data/providers.dart';
import 'friend_code.dart';

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

  Future<void> _handleCode(String? raw) async {
    if (_busy || _found != null) return;
    final profileId = parseFriendCode(raw);
    if (profileId == null) {
      setState(() => _message = 'Das ist kein BrewMates-Code.');
      return;
    }
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

    final profile = await online.profileById(profileId);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _found = profile;
      _message = profile == null
          ? 'Dieses Profil konnten wir nicht finden.'
          : null;
    });
  }

  Future<void> _sendRequest() async {
    final profile = _found;
    if (profile == null || _busy) return;
    setState(() => _busy = true);
    final online = await ref.read(onlineServiceProvider.future);
    final error = await online?.sendFriendRequest(profile.id);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = error ?? 'Anfrage an ${profile.displayName} ist raus 🍻';
      if (error == null) _found = null;
    });
    ref.invalidate(onlineFriendsProvider);
  }

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
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _busy ? null : _sendRequest,
                          icon: const Icon(Icons.person_add_alt),
                          label: const Text('Freundschaft anfragen'),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() => _found = null),
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
