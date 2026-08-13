/// Verbindung zum BrewMates-Supabase-Projekt (Online-Beta).
///
/// Der anon/publishable Key ist per Design öffentlich (er steckt in jeder
/// ausgelieferten App); der Schutz der Daten passiert serverseitig über
/// Row Level Security. Werte können per --dart-define überschrieben werden.
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    // BrewMates-Projekt (EU, eu-central-1).
    defaultValue: 'https://swlqkwlpnxwthbneblww.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN3bHFrd2xwbnh3dGhibmVibHd3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1NzA2MTAsImV4cCI6MjEwMjE0NjYxMH0.7FQ6YBzamFbln86LP9PeX-UFYNcUCkncpd9j1-MyTlc',
  );

  /// Ohne Konfiguration läuft die App vollständig lokal (wie bisher).
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
