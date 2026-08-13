import 'dart:convert';

import 'package:http/http.dart' as http;

/// Automatischer Update-Check gegen die öffentlichen GitHub-Releases.
/// Bewusst ohne Plugin und ohne Sonderberechtigungen: Die App zeigt einen
/// Hinweis mit Release-Notes, der Download läuft über den Browser und
/// Android übernimmt die Installation (Beta-Verteilung per APK).
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.apkUrl,
    required this.notes,
  });

  /// Versions-Tag des Releases, z. B. `v0.9.7-beta`.
  final String version;
  final String apkUrl;
  final String notes;
}

/// Vergleicht zwei Versionsangaben anhand ihrer numerischen Segmente
/// (`0.9.7` > `0.9.6`, `0.10.0` > `0.9.9`); Präfix `v` sowie Suffixe wie
/// `-beta` oder `+10` werden ignoriert. Rückgabe wie [Comparable]:
/// negativ (a < b), 0 (gleich), positiv (a > b).
int compareAppVersions(String a, String b) {
  List<int> parse(String version) {
    var core = version.trim();
    if (core.startsWith('v') || core.startsWith('V')) {
      core = core.substring(1);
    }
    core = core.split('+').first.split('-').first;
    return [
      for (final part in core.split('.')) int.tryParse(part) ?? 0,
    ];
  }

  final left = parse(a);
  final right = parse(b);
  final length = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < length; i++) {
    final l = i < left.length ? left[i] : 0;
    final r = i < right.length ? right[i] : 0;
    if (l != r) return l.compareTo(r);
  }
  return 0;
}

const _latestReleaseUrl =
    'https://api.github.com/repos/ORPA1988/BrewMates/releases/latest';

/// Prüft, ob ein neueres Release existiert. Rückgabe null bei „aktuell",
/// Netz-/Parsefehlern oder wenn das Release keine APK trägt.
Future<UpdateInfo?> checkForUpdate(http.Client client,
    {required String currentVersion}) async {
  try {
    final response = await client.get(
      Uri.parse(_latestReleaseUrl),
      headers: {'Accept': 'application/vnd.github+json'},
    ).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    final data =
        json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final tag = data['tag_name'] as String?;
    if (tag == null || compareAppVersions(tag, currentVersion) <= 0) {
      return null;
    }
    String? apkUrl;
    for (final asset in (data['assets'] as List? ?? const [])) {
      final map = asset as Map<String, dynamic>;
      final name = (map['name'] as String?) ?? '';
      if (name.endsWith('.apk')) {
        apkUrl = map['browser_download_url'] as String?;
        break;
      }
    }
    if (apkUrl == null) return null;
    return UpdateInfo(
      version: tag,
      apkUrl: apkUrl,
      notes: (data['body'] as String?) ?? '',
    );
  } catch (_) {
    return null; // offline/Rate-Limit/kaputtes JSON → einfach kein Hinweis
  }
}
