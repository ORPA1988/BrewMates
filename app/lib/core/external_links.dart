/// Deeplinks zu externen Diensten. Bewusst nur URLs (url_launcher) –
/// kein Google-SDK, kein API-Key.
library;

/// Google-Maps-Suche: bevorzugt exakte Koordinaten, sonst Textsuche.
/// https://developers.google.com/maps/documentation/urls/get-started
Uri googleMapsSearchUri({double? lat, double? lng, String? query}) {
  assert((lat != null && lng != null) || query != null);
  final q = (lat != null && lng != null)
      ? '$lat,$lng'
      : Uri.encodeComponent(query!);
  return Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
}

/// Vorbefülltes GitHub-Issue für Korrekturen an Community-Datensätzen
/// (Biere/Brauereien aus den gebündelten JSON-Dateien sind in-app
/// read-only – Korrekturen laufen über die Community-Pipeline).
Uri communityIssueUri({required String subject, required String body}) =>
    Uri.https('github.com', '/ORPA1988/BrewMates/issues/new', {
      'title': 'Korrektur: $subject',
      'body': body,
    });

/// Ein GitHub-Issue — Fehler, Wunsch oder Roadmap-Punkt. Lesen geht ohne
/// Konto; das Repo ist öffentlich.
Uri githubIssueUri(int number) =>
    Uri.https('github.com', '/ORPA1988/BrewMates/issues/$number');

/// Alle Roadmap-Punkte auf GitHub (Label `roadmap`), offene zuerst.
Uri githubRoadmapUri() => Uri.https('github.com', '/ORPA1988/BrewMates/issues',
    {'q': 'is:issue label:roadmap sort:updated-desc'});
