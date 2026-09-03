/// Die QR-Sprache von BrewMates: `brewmates:<art>:<uuid>`.
///
/// Bewusst simpel — kein Geheimnis, kein Zeitstempel, keine Signatur. Was
/// im Code steht, ist eine ID, die der andere ohnehin sehen darf, und was
/// ein abfotografierter Code erlaubt, kann jeder zurückweisen: Eine
/// Freundschaftsanfrage lässt sich ablehnen, ein Crew-Beitritt hängt am
/// Einladungscode, den die Crew ohnehin herumreicht. Mehr Schutz brächte
/// nur Komplexität ohne Gewinn.
///
/// Das Präfix trägt die eigentliche Arbeit: Ohne es würde jeder fremde
/// QR-Code — WLAN-Zugang, Speisekarte, Paketaufkleber — als Einladung
/// missverstanden.
///
/// **Warum in `core/` und nicht bei den Freunden:** Es gibt zwei Arten
/// und drei Bildschirme, die scannen. Ein Scanner, der einen Crew-Code
/// stumm als „kein BrewMates-Code" abtut, ist die schlechtere Antwort —
/// er weiß ja, was er da hat. Dafür müssen beide Features dieselbe
/// Sprache lesen, und Features dürfen einander nicht importieren.
library;

/// Wofür ein Code steht.
enum BrewMatesCodeArt {
  freund('friend'),
  crew('crew');

  const BrewMatesCodeArt(this.marke);

  /// Der Teil zwischen den Doppelpunkten. Fest verdrahtet, nicht aus dem
  /// Enum-Namen abgeleitet: Ein umbenannter Enum-Wert würde sonst alle
  /// gedruckten Codes ungültig machen.
  final String marke;
}

const _prefix = 'brewmates:';

/// Ein gelesener Code.
class BrewMatesCode {
  const BrewMatesCode(this.art, this.id);

  final BrewMatesCodeArt art;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is BrewMatesCode && other.art == art && other.id == id;

  @override
  int get hashCode => Object.hash(art, id);

  @override
  String toString() => buildBrewMatesCode(art, id);
}

String buildBrewMatesCode(BrewMatesCodeArt art, String id) =>
    '$_prefix${art.marke}:$id';

/// Der eigene Profil-Code (Funktion 22).
String buildFriendCode(String profileId) =>
    buildBrewMatesCode(BrewMatesCodeArt.freund, profileId);

/// Der Einladungscode einer Crew (Funktion 09).
String buildCrewCode(String crewId) =>
    buildBrewMatesCode(BrewMatesCodeArt.crew, crewId);

/// Liest einen gescannten Code.
///
/// Rückgabe: `null`, wenn der Code nicht von BrewMates stammt, eine
/// unbekannte Art trägt oder verstümmelt ist. Whitespace am Rand wird
/// verziehen — manche Scanner hängen Zeilenumbrüche an.
BrewMatesCode? parseBrewMatesCode(String? raw) {
  if (raw == null) return null;
  final value = raw.trim();
  if (!value.startsWith(_prefix)) return null;
  final rest = value.substring(_prefix.length);
  final trenner = rest.indexOf(':');
  if (trenner <= 0) return null;
  final marke = rest.substring(0, trenner);
  final id = rest.substring(trenner + 1).trim();
  if (id.isEmpty) return null;
  for (final art in BrewMatesCodeArt.values) {
    if (art.marke == marke) return BrewMatesCode(art, id);
  }
  return null;
}

/// Die Profil-ID aus einem Freundes-Code — oder `null`, auch wenn es ein
/// gültiger Code einer anderen Art ist.
String? parseFriendCode(String? raw) {
  final code = parseBrewMatesCode(raw);
  return code?.art == BrewMatesCodeArt.freund ? code!.id : null;
}

/// Die Crew-ID aus einem Crew-Code.
String? parseCrewCode(String? raw) {
  final code = parseBrewMatesCode(raw);
  return code?.art == BrewMatesCodeArt.crew ? code!.id : null;
}

/// Was ein Scanner sagt, wenn er die richtige Art nicht bekommen hat.
///
/// Der Fall ist häufiger, als er klingt: Beide Codes sehen gleich aus,
/// und wer am Tisch schnell scannt, erwischt leicht den falschen. „Das
/// ist kein BrewMates-Code" wäre dann schlicht gelogen.
String codeArtVerwechselt({
  required BrewMatesCodeArt erwartet,
  required BrewMatesCodeArt bekommen,
}) =>
    switch ((erwartet, bekommen)) {
      (BrewMatesCodeArt.freund, BrewMatesCodeArt.crew) =>
        'Das ist ein Crew-Code. Geh auf „Crews" und tipp dort oben auf '
            '„Code scannen".',
      (BrewMatesCodeArt.crew, BrewMatesCodeArt.freund) =>
        'Das ist der persönliche Code eines Mates, keine Crew-Einladung. '
            'Scanne ihn unter „Freunde".',
      _ => 'Das ist kein BrewMates-Code.',
    };
