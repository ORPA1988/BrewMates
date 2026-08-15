import 'package:flutter/material.dart';

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
