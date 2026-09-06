import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/providers.dart';

import 'fake_browserfenster.dart';

/// Welcher Browser-Hinweis auf der Startseite erscheint (Funktion 38).
///
/// **Warum das eigene Tests verdient.** Die Entscheidung hat fünf
/// Ausgänge und hängt an drei Merkmalen, die sich gegenseitig ausschließen
/// können. Der teuerste Fehler wäre nicht ein fehlender Hinweis, sondern
/// ein falscher: „Installiere die App, dann bekommst du Meldungen" auf
/// einem Gerät, das danach immer noch keine bekommt.
void main() {
  late FakesFenster fenster;

  setUp(() {
    fenster = FakesFenster();
  });

  tearDown(() => fenster.dispose());

  test('außerhalb des Browsers gibt es keinen Hinweis', () {
    // Die Android-App: Sie hat echten Push und braucht weder Installation
    // noch Browsererlaubnis.
    fenster
      ..imBrowser = false
      ..erlaubnis = Browserfenster.nichtVerfuegbar;

    expect(webHinweisFuer(fenster), WebHinweis.keiner);
  });

  test('Browser ohne Notification und nicht installiert: installieren', () {
    // Der iPhone-Fall — Safari stellt `Notification` außerhalb einer
    // installierten Web-App gar nicht bereit.
    fenster.erlaubnis = Browserfenster.nichtVerfuegbar;

    expect(webHinweisFuer(fenster), WebHinweis.installieren);
  });

  test('installiert und trotzdem keine Notification: schweigen', () {
    // Hier wäre der Hinweis ein Versprechen, das die Installation nicht
    // einlösen kann — sie ist ja schon geschehen.
    fenster
      ..erlaubnis = Browserfenster.nichtVerfuegbar
      ..alsAppInstalliert = true;

    expect(webHinweisFuer(fenster), WebHinweis.keiner);
  });

  test('Meldungen möglich, noch nicht gefragt: erlauben', () {
    fenster.erlaubnis = 'default';

    expect(webHinweisFuer(fenster), WebHinweis.erlauben);
  });

  test('schon erlaubt oder schon abgelehnt: kein Hinweis', () {
    fenster.erlaubnis = 'granted';
    expect(webHinweisFuer(fenster), WebHinweis.keiner);

    // Abgelehnt ist ebenso erledigt: Die App darf nicht erneut fragen,
    // der Weg über das Schloss-Symbol steht im Konto.
    fenster.erlaubnis = 'denied';
    expect(webHinweisFuer(fenster), WebHinweis.keiner);
  });

  test('weggewischt bleibt weg — je Hinweis getrennt', () {
    fenster
      ..erlaubnis = Browserfenster.nichtVerfuegbar
      ..hinweisWegwischen(webHinweisSchluessel(WebHinweis.installieren));

    expect(webHinweisFuer(fenster), WebHinweis.keiner);

    // Nach der Installation ist der zweite Hinweis ein anderer und darf
    // nicht mitverschwinden — sonst erführe niemand vom Erlaubnis-Knopf.
    fenster.erlaubnis = 'default';
    expect(webHinweisFuer(fenster), WebHinweis.erlauben);
  });

  test('die stumme Fassung schweigt', () {
    // Kein Doppelgänger, sondern die Fassung, die auf Android und Windows
    // wirklich läuft: Sie darf nie einen Hinweis auslösen.
    expect(webHinweisFuer(Browserfenster()), WebHinweis.keiner);
  });
}
