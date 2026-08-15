/// Gemeinsame Basis der thematischen Server-Zugriffe.
///
/// **Warum es diese Aufteilung gibt (Backlog B-3):** `online_service.dart`
/// war auf über 1.800 Zeilen gewachsen und enthielt alles vom Anmelden bis
/// zur Wunschliste. Jede noch so kleine Änderung musste die ganze Datei
/// öffnen — für Menschen unübersichtlich, für Werkzeuge teuer, und bei der
/// Fehlersuche musste man Unbeteiligtes mitlesen.
///
/// Jeder Bereich bekommt jetzt eine eigene Klasse mit eigener Datei.
/// `OnlineService` bleibt der Einstieg und reicht sie als Felder heraus
/// (`online.sessions.end(...)`).
///
/// **Warum Klassen und keine Extensions:** Extension-Methoden sind
/// statisch gebunden — ein Test-Doppel könnte sie nicht überschreiben, und
/// der Aufruf ginge still an der Attrappe vorbei. Genau solche lautlosen
/// Wirkungslosigkeiten haben in diesem Projekt schon zweimal Fehler
/// verdeckt. Normale Klassen lassen sich überschreiben, und ein
/// vergessener Aufruf ist ein Compilerfehler statt eines stillen Fehlers.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

abstract class OnlineApi {
  const OnlineApi(this.client, this.nutzer);

  /// Der Supabase-Client. Absichtlich nicht privat: Die Bereiche liegen in
  /// eigenen Dateien und damit in eigenen Bibliotheken.
  final SupabaseClient client;

  /// Liefert den angemeldeten Nutzer. Als Funktion und nicht als Wert,
  /// weil sich die Anmeldung zur Laufzeit ändert — ein einmal kopierter
  /// Wert wäre nach dem nächsten Login falsch.
  final User? Function() nutzer;

  User? get currentUser => nutzer();

  /// Spalten, die ein Profil öffentlich preisgibt.
  ///
  /// `thirsty_until` fehlt hier bewusst: Seit Migration 0026 ist das
  /// Spaltenrecht entzogen, gelesen wird über `my_thirsty_until()` und
  /// `thirsty_friends()`. Wer die Spalte hier ergänzt, bekommt vom Server
  /// einen Berechtigungsfehler auf die **gesamte** Abfrage.
  static const profileCols =
      'id, username, display_name, avatar_emoji, account_no';

  /// Erkennt eine UUID. Client-erzeugte Check-in-IDs sind UUIDs, ältere
  /// lokale IDs nicht — daran hängt, was hochgeladen werden darf. Wird
  /// auch beim Einlösen eines Freundes-Codes gebraucht.
  static final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
}
