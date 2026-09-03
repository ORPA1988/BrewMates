import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/core/brewmates_code.dart';

/// Die QR-Sprache der App: `brewmates:<art>:<uuid>`.
///
/// Seit die Crews eigene Codes haben (Roadmap-Punkt „Crews per QR-Code",
/// Issue #62), gibt es zwei Arten — und damit einen neuen Fehlerfall, den
/// es vorher nicht gab: den **richtigen Code am falschen Scanner**. Die
/// alte Antwort „Das ist kein BrewMates-Code" wäre dort schlicht gelogen.
void main() {
  const id = '3f2a91c4-5b6d-4e7f-8a90-1b2c3d4e5f60';

  group('Bauen und Lesen', () {
    test('ergeben wieder dieselbe ID, je Art', () {
      expect(parseFriendCode(buildFriendCode(id)), id);
      expect(parseCrewCode(buildCrewCode(id)), id);
    });

    test('die Marken im Code sind fest, nicht aus dem Enum abgeleitet', () {
      // Ein umbenannter Enum-Wert würde sonst alle gedruckten Codes
      // ungültig machen — und der Fehler fiele erst am Tisch auf.
      expect(buildFriendCode(id), 'brewmates:friend:$id');
      expect(buildCrewCode(id), 'brewmates:crew:$id');
    });

    test('parse liefert die Art mit', () {
      expect(parseBrewMatesCode(buildCrewCode(id)),
          const BrewMatesCode(BrewMatesCodeArt.crew, id));
    });
  });

  group('Fremde und kaputte Codes', () {
    test('werden nicht als Einladung missverstanden', () {
      // Genau dafür gibt es das Präfix: WLAN-Zugänge, Speisekarten und
      // Paketaufkleber sind auch QR-Codes.
      for (final fremd in [
        'https://example.org',
        'WIFI:S=Gasthaus;T=WPA;P=bier;;',
        id, // nackte UUID ohne Präfix
        'brewmates:venue:$id', // Art gibt es nicht
        'BREWMATES:FRIEND:$id', // Groß/Klein zählt
        'brewmates:$id', // Art fehlt ganz
        'brewmates::$id', // leere Art
      ]) {
        expect(parseBrewMatesCode(fremd), isNull, reason: fremd);
        expect(parseFriendCode(fremd), isNull, reason: fremd);
        expect(parseCrewCode(fremd), isNull, reason: fremd);
      }
    });

    test('Leeres und Verstümmeltes ergibt null', () {
      for (final kaputt in [
        null,
        '',
        'brewmates:friend:',
        'brewmates:friend:   ',
        'brewmates:crew:',
      ]) {
        expect(parseBrewMatesCode(kaputt), isNull, reason: '$kaputt');
      }
    });

    test('Whitespace am Rand wird verziehen', () {
      // Manche Scanner hängen Zeilenumbrüche an.
      expect(parseFriendCode('  ${buildFriendCode(id)}\n'), id);
      expect(parseCrewCode('\t${buildCrewCode(id)}  '), id);
    });
  });

  group('Der richtige Code am falschen Scanner', () {
    test('ein Crew-Code ist für den Freundes-Scanner kein Freundes-Code', () {
      expect(parseFriendCode(buildCrewCode(id)), isNull);
      expect(parseCrewCode(buildFriendCode(id)), isNull);
    });

    test('die Meldung sagt, wo der Code hingehört', () {
      final anCrew = codeArtVerwechselt(
          erwartet: BrewMatesCodeArt.freund,
          bekommen: BrewMatesCodeArt.crew);
      expect(anCrew, contains('Crew'));
      expect(anCrew, contains('Code scannen'),
          reason: 'Der Hinweis muss den Weg nennen, nicht nur den Fehler.');

      final anFreund = codeArtVerwechselt(
          erwartet: BrewMatesCodeArt.crew,
          bekommen: BrewMatesCodeArt.freund);
      expect(anFreund, contains('Freunde'));
    });
  });
}
