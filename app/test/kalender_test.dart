// Verabredung in den Kalender (#165).
//
// Reine Zeichenketten-Logik: Geprüft wird vor allem, was eine
// .ics-Datei zerreißt — Komma, Semikolon, Backslash, Zeilenumbruch —
// und dass die Zeit als UTC dasteht.

import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/core/kalender.dart';

void main() {
  final termin = DateTime.utc(2026, 9, 11, 17, 0);

  group('ICS', () {
    test('Gerüst und Pflichtfelder', () {
      final ics = verabredungAlsIcs(
          id: 'abc', termin: termin, gastgeber: 'Mit Anna');
      final zeilen = ics.split('\r\n');

      expect(zeilen.first, 'BEGIN:VCALENDAR');
      expect(zeilen, contains('VERSION:2.0'));
      expect(zeilen, contains('BEGIN:VEVENT'));
      expect(zeilen, contains('END:VCALENDAR'));
      // CRLF ist vorgeschrieben, nicht Geschmackssache.
      expect(ics, contains('\r\n'));
    });

    test('Zeiten stehen als UTC mit Z', () {
      final ics = verabredungAlsIcs(
          id: 'abc', termin: termin, gastgeber: 'Mit Anna');
      expect(ics, contains('DTSTART:20260911T170000Z'));
      // Zwei Stunden ist die freundliche Annahme, kein Wissen.
      expect(ics, contains('DTEND:20260911T190000Z'));
    });

    test('Dieselbe Verabredung hat dieselbe UID', () {
      final a = verabredungAlsIcs(
          id: 'gleich', termin: termin, gastgeber: 'Mit Anna');
      final b = verabredungAlsIcs(
          id: 'gleich', termin: termin, gastgeber: 'Mit Anna');
      final uid = RegExp(r'UID:(.+)').firstMatch(a)!.group(1);
      expect(b, contains('UID:$uid'),
          reason: 'sonst entsteht beim zweiten Export ein zweiter Termin');
    });

    test('Komma und Semikolon zerreißen die Zeile nicht', () {
      final ics = verabredungAlsIcs(
        id: 'abc',
        termin: termin,
        gastgeber: 'Mit Anna',
        ort: 'Wirtshaus zum Hirschen, Wien; 1. Stock',
      );
      expect(ics, contains(r'LOCATION:Wirtshaus zum Hirschen\, Wien\; 1. Stock'));
    });

    test('Ein Zeilenumbruch in der Nachricht wird zu \n', () {
      final ics = verabredungAlsIcs(
        id: 'abc',
        termin: termin,
        gastgeber: 'Mit Anna',
        nachricht: 'Erste Zeile\nZweite Zeile',
      );
      expect(ics, contains(r'DESCRIPTION:Erste Zeile\nZweite Zeile'));
      // Und es bleibt bei einer DESCRIPTION-Zeile.
      expect('\r\n$ics'.split('\r\nDESCRIPTION:').length, 2);
    });

    test('Was fehlt, steht gar nicht drin', () {
      final ics = verabredungAlsIcs(
          id: 'abc', termin: termin, gastgeber: 'Mit Anna', ort: '   ');
      expect(ics, isNot(contains('LOCATION')));
      expect(ics, isNot(contains('DESCRIPTION')));
    });
  });

  group('Kalender-Link', () {
    test('Zeitraum und Titel stehen in der Adresse', () {
      final url = verabredungAlsKalenderLink(
          termin: termin, gastgeber: 'Mit Anna');
      expect(url, contains('dates=20260911T170000Z%2F20260911T190000Z'));
      expect(url, contains('action=TEMPLATE'));
    });

    test('Sonderzeichen werden kodiert', () {
      final url = verabredungAlsKalenderLink(
        termin: termin,
        gastgeber: 'Mit Anna',
        ort: 'Gasthaus & Bar',
      );
      expect(url, contains('Gasthaus+%26+Bar'));
      // Das & des Ortes darf die Parameter nicht zerlegen.
      expect(url.split('&').length, 4);
    });
  });
}
