import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';

/// Hinweis, wenn das Beenden des Beacons den Server nicht erreicht hat.
///
/// Liegt in `widgets/`, weil vier Bildschirme den Beacon beenden können
/// (Startseite, Beacon-Ansicht, Session-Detail, Banner in der Hülle) und
/// Features einander nicht importieren dürfen. Vier Kopien desselben
/// Satzes würden auseinanderlaufen.
///
/// Der Text sagt bewusst, was **auf dem Server** gilt, nicht was die App
/// anzeigt: Lokal ist der Beacon aus, aber gesehen wird er über den
/// Server. Wer glaubt, er sei unsichtbar, trifft sonst Entscheidungen auf
/// falscher Grundlage.
const beaconEndFailedSnackBar = SnackBar(
  content: Text('Beacon lokal beendet, aber der Server hat es nicht '
      'mitbekommen. Deine Freunde sehen dich eventuell noch — die App '
      'holt es beim nächsten Abgleich nach.'),
  duration: Duration(seconds: 6),
);

/// Der Beacon laeuft lokal, aber der Server hat ihn nicht — offline oder
/// Fehler. Der Mensch muss das wissen, sonst sitzt er sichtbar-geglaubt
/// und unsichtbar im Wirtshaus.
const beaconStartNotSyncedText =
    'Beacon läuft nur auf deinem Gerät – ohne Verbindung sehen dich deine '
    'Freunde noch nicht.';

/// Prost/„Bin dabei" ist beim Server nicht angekommen.
const reactionNotSentSnackBar = SnackBar(
  content: Text('Konnte nicht gesendet werden – keine Verbindung? '
      'Der Gastgeber hat nichts davon mitbekommen.'),
  duration: Duration(seconds: 5),
);

const toastSentSnackBar =
    SnackBar(content: Text('Prost geschickt! 🍻'));
const joinedSnackBar =
    SnackBar(content: Text('Du bist dabei! 🍻'));

/// Beacon beenden — sofort, aber für ein paar Sekunden zurückholbar.
///
/// „Beenden" steht auf vier Bildschirmen, dreimal als schmuckloser
/// Textknopf direkt neben „Verlängern". Ein Fehltipp war bisher endgültig:
/// Die Runde war weg, und wer weitermachen wollte, musste einen neuen
/// Beacon starten — mit neuer ID, neuer Laufzeit und ohne die Leute, die
/// den alten schon gesehen hatten.
///
/// **Warum kein „Wirklich beenden?"**: Die Rückfrage bestraft die 99 %,
/// die es so gemeint haben, für den einen Fehltipp. Umgekehrt herum
/// kostet es niemanden etwas.
///
/// **Warum trotzdem sofort beendet wird** (und nicht wie beim Ablehnen
/// einer Anfrage nur aufgeschoben): Ein laufender Beacon zeigt Freunden
/// den Aufenthaltsort. Wer „Beenden" tippt, will in dieser Sekunde
/// unsichtbar sein, nicht in fünf.
Future<void> beaconBeendenMitRueckgaengig(
  BuildContext context,
  WidgetRef ref,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final ergebnis = await ref.read(actionsProvider).endMySession();
  if (ergebnis == null) return;

  if (!ergebnis.synced) {
    // Kein „Rückgängig" anbieten, solange unklar ist, ob überhaupt etwas
    // passiert ist. Zuerst die ehrliche Meldung — sie ist die wichtigere.
    messenger.showSnackBar(beaconEndFailedSnackBar);
    return;
  }

  messenger.showSnackBar(SnackBar(
    content: const Text('Beacon beendet'),
    duration: const Duration(seconds: 5),
    action: SnackBarAction(
      label: 'Rückgängig',
      onPressed: () async {
        final wieder =
            await ref.read(actionsProvider).undoEndMySession(ergebnis.beendet);
        messenger.showSnackBar(switch (wieder) {
          null => const SnackBar(
              content: Text('Der Beacon wäre inzwischen ohnehin abgelaufen — '
                  'starte einfach einen neuen.'),
            ),
          true => const SnackBar(content: Text('Beacon läuft wieder 🍻')),
          false => const SnackBar(
              content: Text('Beacon läuft wieder auf deinem Gerät, aber der '
                  'Server hat es nicht mitbekommen — deine Freunde sehen ihn '
                  'noch nicht.'),
              duration: Duration(seconds: 6),
            ),
        });
      },
    ),
  ));
}
