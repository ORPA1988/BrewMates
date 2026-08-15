import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';

/// „Update erforderlich" — der Bildschirm, der statt unerklärlicher
/// Fehler erscheint.
///
/// Ohne ihn muss jede Migration ewig rücksichtsvoll bleiben: Wer eine
/// Spalte entzieht, bricht ältere Clients, und der Nutzer sieht bloß eine
/// leere Freundesliste ohne zu ahnen, dass seine App zu alt ist.
///
/// Der Text nennt deshalb **beides** — dass es an der Version liegt und
/// was zu tun ist. „Etwas ist schiefgelaufen" wäre hier die schlechteste
/// aller Meldungen.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key});

  /// Wo die aktuelle Fassung liegt. Die Beta wird als APK über die
  /// GitHub-Releases verteilt (siehe Funktion 17).
  static final _releases =
      Uri.parse('https://github.com/ORPA1988/BrewMates/releases/latest');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🍺', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 24),
              Text(
                'Update erforderlich',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Diese Version von BrewMates wird nicht mehr unterstützt. '
                'Der Server hat sich weiterentwickelt, und die App würde '
                'dir sonst Daten falsch oder gar nicht anzeigen.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Deine Check-ins auf diesem Gerät bleiben erhalten.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () =>
                    launchUrl(_releases, mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.download),
                label: const Text('Neue Version holen'),
              ),
              const SizedBox(height: 16),
              Text(
                'Installiert: ${AppConfig.appVersion}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
