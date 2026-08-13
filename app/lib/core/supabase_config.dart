/// Verbindung zum BrewMates-Supabase-Projekt (Online-Beta).
///
/// Der anon/publishable Key ist per Design öffentlich (er steckt in jeder
/// ausgelieferten App); der Schutz der Daten passiert serverseitig über
/// Row Level Security. Werte können per --dart-define überschrieben werden.
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    // BrewMates-Projekt (wird beim Beta-Setup eingetragen).
    defaultValue: '',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Ohne Konfiguration läuft die App vollständig lokal (wie bisher).
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
