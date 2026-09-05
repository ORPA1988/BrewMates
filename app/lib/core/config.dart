/// Build-Zeit-Konfiguration via --dart-define.
class AppConfig {
  /// Laufende App-Version — MUSS mit `version:` in pubspec.yaml
  /// übereinstimmen (Test pubspec_version_sync_test.dart erzwingt das).
  /// Grundlage für den automatischen Update-Check gegen GitHub-Releases.
  static const appVersion = '0.10.16-beta+34';

  // Die Supabase-Zugangsdaten stehen **nicht** hier, sondern in
  // `core/supabase_config.dart` — dort mit `defaultValue`, weshalb die App
  // auch ohne `--dart-define` verbunden ist. Bis 2026-09-04 standen sie
  // zusätzlich hier, ohne Vorgabewert und von niemandem benutzt: Ein
  // `AppConfig.hasSupabase` hätte in jedem normalen Build `false` gemeldet,
  // während die App längst online war. Wer „ist das Backend da?" fragen
  // will, fragt `SupabaseConfig.isConfigured`.

  /// Standard-Dauer bis zum Auto-Ende einer Session.
  static const defaultSessionDuration = Duration(hours: 3);
}
