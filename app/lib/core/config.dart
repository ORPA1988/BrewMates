/// Build-Zeit-Konfiguration via --dart-define.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Ohne Zugangsdaten läuft die App im Offline-Demo-Modus mit Platzhalterdaten.
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Standard-Dauer bis zum Auto-Ende einer Session.
  static const defaultSessionDuration = Duration(hours: 3);
}
