/// Vertrauensstufen (Anzeige-Seite). Die Wahrheit lebt serverseitig in
/// `account_level()` (Migration 0013) — diese Datei bildet Stufen und
/// Punkteschwellen nur für die UI ab und ist pur testbar.
library;

class AccountLevelInfo {
  const AccountLevelInfo({required this.level, required this.points});

  final int level;
  final int points;
}

const int stammgastPoints = 25;
const int bierkennerPoints = 100;

String levelEmoji(int level) => switch (level) {
      0 => '🔒',
      1 => '🌱',
      2 => '🍺',
      3 => '🎓',
      4 => '🛠',
      _ => '👑',
    };

String levelName(int level) => switch (level) {
      0 => 'Gesperrt',
      1 => 'Neuling',
      2 => 'Stammgast',
      3 => 'Bierkenner',
      4 => 'Moderator',
      _ => 'Admin',
    };

/// „noch X Punkte bis 🍺 Stammgast" – null, wenn es nichts zu erreichen
/// gibt (ab Bierkenner bzw. bei gesperrten Konten).
String? nextLevelHint(AccountLevelInfo info) {
  if (info.level == 1 && info.points < stammgastPoints) {
    return 'noch ${stammgastPoints - info.points} Punkte bis '
        '${levelEmoji(2)} ${levelName(2)}';
  }
  if (info.level == 2 && info.points < bierkennerPoints) {
    return 'noch ${bierkennerPoints - info.points} Punkte bis '
        '${levelEmoji(3)} ${levelName(3)}';
  }
  return null;
}

/// Was die aktuelle Stufe darf – für den Erklär-Dialog.
List<String> levelPerks(int level) => switch (level) {
      0 => const ['Nur lesen (von einem Admin gesperrt)'],
      1 => const [
          'Biere anlegen und eigene unverifizierte Biere bearbeiten',
          'Gasthäuser anlegen und eigene Gasthäuser pflegen',
        ],
      2 => const [
          'Alle unverifizierten Community-Biere bearbeiten',
          'Alle Gasthäuser pflegen (Preise, Öffnungszeiten, Adresse)',
        ],
      3 => const [
          'Gasthäuser verifizieren',
          'Name/Position verifizierter Gasthäuser ändern',
        ],
      4 => const ['Meldungen bearbeiten, Inhalte moderieren'],
      _ => const ['Alles – inklusive Rollen, Rechte und Challenges'],
    };
