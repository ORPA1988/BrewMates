/// Die Anmeldewege, die BrewMates kennt.
///
/// **Warum eine Liste vom Server und nicht einfach Knöpfe im Code.**
/// Jeder dieser Wege braucht am Server ein eingerichtetes Konto beim
/// jeweiligen Anbieter — Client-ID, Geheimnis, hinterlegte Rück-URL. Ist
/// das nicht eingerichtet, antwortet Supabase mit „provider is not
/// enabled", und der Mensch steht vor einem Knopf, der ein Versprechen
/// bricht. Genau das ist der teuerste Fehler auf einem Anmeldebildschirm:
/// Wer sich nicht anmelden kann, kommt nicht wieder.
///
/// Deshalb steht in `app_config` unter `auth_providers`, was wirklich
/// eingerichtet ist. Die App zeigt genau das — und keinen Knopf mehr.
/// Nebenwirkung, die den Ausschlag gab: Wird Apple freigeschaltet,
/// erscheint der Knopf **ohne neues Release**, auch auf Geräten, die
/// nie wieder aktualisiert werden.
///
/// Reines Dart, damit die Auswertung ohne Netz und ohne Supabase
/// testbar bleibt.
enum Anmeldeverfahren {
  google('google', 'Google'),
  apple('apple', 'Apple'),
  microsoft('azure', 'Microsoft'),
  facebook('facebook', 'Facebook'),
  discord('discord', 'Discord'),
  github('github', 'GitHub');

  const Anmeldeverfahren(this.schluessel, this.name);

  /// So heißt der Anbieter bei Supabase — und so steht er in
  /// `app_config.auth_providers`. Microsoft heißt dort `azure`; der
  /// Mensch sagt „Microsoft", die Schnittstelle sagt „azure", und die
  /// Übersetzung gehört hierher und nicht in den Bildschirm.
  final String schluessel;

  /// So heißt er auf dem Knopf.
  final String name;

  /// „Mit Google anmelden"
  String get knopfText => 'Mit $name anmelden';
}

/// Was in `app_config.auth_providers` steht, in eine Liste übersetzen.
///
/// Erwartet wird eine Aufzählung mit Komma: `google,apple`. Unbekannte
/// Einträge werden **still übergangen** statt zu scheitern: Der Server
/// darf einen Anbieter nennen, den diese App-Fassung noch nicht kennt —
/// eine alte Installation zeigt ihn dann eben nicht, statt gar keinen
/// Anmeldeknopf mehr zu haben.
///
/// Doppelte Einträge fliegen raus, die Reihenfolge bleibt die des
/// Servers: Wer die Liste pflegt, bestimmt damit auch, was oben steht.
List<Anmeldeverfahren> anmeldeverfahrenAus(String? konfiguration) {
  final roh = (konfiguration ?? '').split(',');
  final gefunden = <Anmeldeverfahren>[];
  for (final teil in roh) {
    final schluessel = teil.trim().toLowerCase();
    if (schluessel.isEmpty) continue;
    for (final verfahren in Anmeldeverfahren.values) {
      if (verfahren.schluessel == schluessel &&
          !gefunden.contains(verfahren)) {
        gefunden.add(verfahren);
      }
    }
  }
  return gefunden;
}
