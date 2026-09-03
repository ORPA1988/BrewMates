import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show Geolocator;
import 'package:mobile_scanner/mobile_scanner.dart'
    show MobileScannerErrorCode, MobileScannerException;

/// Warum die Kamera kein Bild liefert — in den drei Fällen, die für den
/// Menschen davor unterschiedliche Auswege haben.
///
/// `mobile_scanner` kennt sechs Fehlercodes, aber drei davon sind
/// Programmierfehler (Controller doppelt gestartet, benutzt nach
/// `dispose`, benutzt vor `start`). Die gehören nicht in eine
/// Nutzermeldung: Wer sie liest, kann nichts tun. Sie landen deshalb
/// zusammen mit `genericError` in [KameraProblem.unbekannt].
enum KameraProblem {
  /// Die Berechtigung fehlt — das ist der häufige Fall und der einzige,
  /// den der Mensch selbst beheben kann.
  verweigert,

  /// Das Gerät oder der Browser kann keinen Kamera-Scan.
  nichtVerfuegbar,

  /// Alles andere. Ehrlich als „unklar" benennen statt zu raten.
  unbekannt,
}

KameraProblem kameraProblemFuer(MobileScannerErrorCode code) =>
    switch (code) {
      MobileScannerErrorCode.permissionDenied => KameraProblem.verweigert,
      MobileScannerErrorCode.unsupported => KameraProblem.nichtVerfuegbar,
      _ => KameraProblem.unbekannt,
    };

String kameraTitel(KameraProblem problem) => switch (problem) {
      KameraProblem.verweigert => 'Kamera ist nicht freigegeben',
      KameraProblem.nichtVerfuegbar => 'Kein Kamera-Scan möglich',
      KameraProblem.unbekannt => 'Die Kamera macht gerade nicht mit',
    };

/// Der Weg zurück zu einem funktionierenden Scanner, in ganzen Sätzen und
/// ohne Fachwort. `imBrowser` unterscheidet zwei völlig verschiedene
/// Orte: Android verwaltet die Freigabe in den App-Einstellungen, der
/// Browser im Schloss-Symbol neben der Adresse.
String kameraErklaerung(KameraProblem problem, {required bool imBrowser}) =>
    switch (problem) {
      KameraProblem.verweigert => imBrowser
          ? 'Dein Browser lässt BrewMates nicht an die Kamera. Tipp auf das '
              'Schloss-Symbol links neben der Adresse, erlaube dort die '
              'Kamera und lade die Seite neu.'
          : 'BrewMates darf die Kamera nicht benutzen. Du kannst das in den '
              'App-Einstellungen unter „Berechtigungen" ändern.',
      KameraProblem.nichtVerfuegbar => imBrowser
          ? 'Dieser Browser gibt keine Kamera her. Am zuverlässigsten läuft '
              'der Scan in Chrome oder Safari — und immer nur über https.'
          : 'Dieses Gerät hat keine Kamera, die der Scanner nutzen kann.',
      KameraProblem.unbekannt =>
        'Die Kamera hat sich nicht öffnen lassen. Meist hilft es, eine '
            'andere App zu schließen, die gerade die Kamera benutzt, und den '
            'Scanner noch einmal aufzurufen.',
    };

/// Erklärung statt schwarzem Bild.
///
/// `mobile_scanner` zeigt ohne eigenen `errorBuilder` ein schwarzes
/// Rechteck mit weißem Warndreieck — ununterscheidbar von „Kamera hängt",
/// „kein Licht" und „du hast beim Installieren auf Ablehnen getippt".
/// Genau das war der Befund aus dem Test mit echten Leuten.
///
/// Der [ausweg] ist Pflicht und kein Beiwerk: Jeder Scanner der App hat
/// einen zweiten Weg (EAN tippen, Namenssuche, Code abtippen). Ein
/// Hinweis, der nur erklärt, warum etwas nicht geht, lässt den Menschen
/// dort stehen, wo er steht.
class KameraHinweis extends StatelessWidget {
  const KameraHinweis({
    super.key,
    required this.problem,
    required this.ausweg,
    this.imBrowser = kIsWeb,
    this.einstellungenOeffnen,
  });

  KameraHinweis.ausFehler(
    MobileScannerException fehler, {
    super.key,
    required this.ausweg,
    this.imBrowser = kIsWeb,
    this.einstellungenOeffnen,
  }) : problem = kameraProblemFuer(fehler.errorCode);

  final KameraProblem problem;

  /// Was stattdessen zum Ziel führt, in der Sprache des jeweiligen
  /// Bildschirms („Tipp den Barcode unten ein.").
  final String ausweg;

  final bool imBrowser;

  /// Nur für Tests überschreibbar — sonst führt der Knopf in die
  /// Systemeinstellungen der App.
  final Future<bool> Function()? einstellungenOeffnen;

  /// Der Knopf lohnt sich nur, wo er auch irgendwo hinführt: Auf Android
  /// und iOS öffnet das System die Seite der App. Im Browser gibt es
  /// keine solche Seite (die Erklärung nennt dort das Schloss-Symbol),
  /// auf Desktop kommt dieser Bildschirm ohnehin nicht vor.
  bool get _einstellungenMoeglich =>
      problem == KameraProblem.verweigert &&
      !imBrowser &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📷', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                kameraTitel(problem),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                kameraErklaerung(problem, imBrowser: imBrowser),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                ausweg,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (_einstellungenMoeglich) ...[
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  // `Geolocator` ist hier kein Versehen: Das Paket ist
                  // ohnehin an Bord, und `openAppSettings` öffnet die
                  // Systemseite DER APP — nicht die des Standorts. Ein
                  // zweites Berechtigungs-Paket nur für diesen einen
                  // Knopf wäre der teurere Weg (die Toolchain ist auf
                  // Flutter 3.24 gepinnt, jedes Paket mehr ein Risiko).
                  onPressed: () =>
                      (einstellungenOeffnen ?? Geolocator.openAppSettings)(),
                  icon: const Icon(Icons.settings),
                  label: const Text('Einstellungen öffnen'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
