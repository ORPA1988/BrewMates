/// Build-Zeit-Konfiguration via --dart-define.
class AppConfig {
  /// Laufende App-Version — MUSS mit `version:` in pubspec.yaml
  /// übereinstimmen (Test pubspec_version_sync_test.dart erzwingt das).
  /// Grundlage für den automatischen Update-Check gegen GitHub-Releases.
  static const appVersion = '0.9.9-beta+13';

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Ohne Zugangsdaten läuft die App im Offline-Demo-Modus mit Platzhalterdaten.
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Standard-Dauer bis zum Auto-Ende einer Session.
  static const defaultSessionDuration = Duration(hours: 3);
}
