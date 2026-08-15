/// Nutzlast der Freundes-QR-Codes.
///
/// Bewusst simpel: `brewmates:friend:<uuid>` — die Profil-ID, die Freunde
/// ohnehin sehen. Kein Geheimnis, kein Zeitstempel, keine Signatur. Ein
/// abfotografierter Code erlaubt nur, eine Anfrage zu stellen, die der
/// andere ablehnen kann; mehr Schutz würde nur Komplexität ohne Gewinn
/// bringen.
///
/// Das Präfix trägt die eigentliche Arbeit: Ohne es würde jeder beliebige
/// fremde QR-Code — WLAN-Zugang, Speisekarte, Paketaufkleber — als
/// Freundesanfrage missverstanden.
library;

const _prefix = 'brewmates:friend:';

/// Baut den Code für ein eigenes Profil.
String buildFriendCode(String profileId) => '$_prefix$profileId';

/// Liest eine Profil-ID aus einem gescannten Code.
///
/// Rückgabe: die ID, oder null wenn der Code nicht von BrewMates stammt
/// bzw. verstümmelt ist. Whitespace am Rand wird verziehen — manche
/// Scanner hängen Zeilenumbrüche an.
String? parseFriendCode(String? raw) {
  if (raw == null) return null;
  final value = raw.trim();
  if (!value.startsWith(_prefix)) return null;
  final id = value.substring(_prefix.length).trim();
  return id.isEmpty ? null : id;
}
