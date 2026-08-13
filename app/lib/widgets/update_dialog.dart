import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_update.dart';

/// Update-Dialog: Release-Notes (gekürzt) + 1-Tap-Download der APK.
/// Der Browser lädt die Datei, Android öffnet danach den Installer.
Future<void> showUpdateDialog(BuildContext context, UpdateInfo update) {
  final notes = update.notes.trim();
  final shortNotes =
      notes.length > 600 ? '${notes.substring(0, 600)} …' : notes;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('🔄 BrewMates ${update.version}'),
      content: SingleChildScrollView(
        child: Text(
          shortNotes.isEmpty
              ? 'Eine neue Version ist verfügbar.'
              : shortNotes,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Später'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Jetzt herunterladen'),
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            await launchUrl(Uri.parse(update.apkUrl),
                mode: LaunchMode.externalApplication);
          },
        ),
      ],
    ),
  );
}
