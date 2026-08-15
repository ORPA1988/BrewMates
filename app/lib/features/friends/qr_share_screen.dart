import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/providers.dart';
import 'friend_code.dart';

/// „Mein Code": der eigene QR-Code, groß genug fürs Wirtshaus.
///
/// Der Moment, in dem man sich vernetzt, ist fast immer derselbe: zwei
/// Menschen am selben Tisch. Genau dort ist Tippen der falsche Weg.
class QrShareScreen extends ConsumerWidget {
  const QrShareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final me = ref.watch(onlineUserProvider).valueOrNull;
    final profile = ref.watch(meProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Mein Code')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: me == null
              ? Text(
                  'Melde dich an, damit dich andere über deinen Code '
                  'finden können.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Weißer Grund unabhängig vom Farbschema: Ein
                    // QR-Code auf dunklem Hintergrund wird von vielen
                    // Kameras nicht erkannt.
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: QrImageView(
                        data: buildFriendCode(me.id),
                        version: QrVersions.auto,
                        size: 260,
                        // Etwas Fehlerkorrektur, damit ein Fingerabdruck
                        // auf dem Display nicht gleich alles verdirbt.
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      profile?.displayName ?? '',
                      style: theme.textTheme.titleLarge,
                    ),
                    if (profile != null)
                      Text(
                        '@${profile.username}',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Scannen lassen — und ihr seid verbunden, sobald der '
                      'andere die Anfrage annimmt.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
