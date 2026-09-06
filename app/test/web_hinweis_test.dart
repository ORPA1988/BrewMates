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

  // Die zwei folgenden Tests fassen **keinen Doppelgänger** an, sondern
  // die Fassung, die der Aufbau auf dieser Plattform wirklich liefert.
  // Sie stehen hier zu zweit, weil `Browserfenster()` je nach Ziel etwas
  // anderes baut — ein einzelner Test hätte auf einer der beiden Seiten
  // eine falsche Erwartung, und genau das ist er beim ersten CI-Lauf
  // auch gewesen.

  test('außerhalb des Browsers schweigt die echte Weiche', () {
    // Android und Windows: Dort gibt es echten Push, und ein Hinweis auf
    // Browsermeldungen wäre schlicht falsch.
    final echt = Browserfenster();
    expect(echt.imBrowser, isFalse);
    expect(webHinweisFuer(echt), WebHinweis.keiner);
  }, testOn: 'vm');

  test('im Browser erkennt sich die echte Weiche als Browser', () {
    final echt = Browserfenster();
    expect(echt.imBrowser, isTrue);
    // **Welcher** Hinweis daraus wird, hängt am Browser des Läufers:
    // Kennt er `Notification`? Wurde schon gefragt? Beides festzuschreiben
    // hieße, den Testrechner zur Anforderung zu machen. Geprüft ist, dass
    // die Frage beantwortbar ist, ohne zu werfen — der Zugriff auf
    // `Notification` und `localStorage` tut das in manchen Lagen nämlich.
    expect(() => webHinweisFuer(echt), returnsNormally);
  }, testOn: 'browser');
}
