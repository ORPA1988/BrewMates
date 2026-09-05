/// Eine Verabredung in den Kalender bringen.
///
/// Reine Zeichenketten-Arbeit: hier entsteht der Text einer
/// `.ics`-Datei und die Adresse, mit der ein Web-Kalender denselben
/// Termin vorausgefüllt öffnet. **Wohin** das geht, entscheidet die
/// Oberfläche (`core/export/`), wie beim CSV-Export.
library;

/// Ein Zeitpunkt in der Form, die iCalendar verlangt: UTC, ohne
/// Trennzeichen, mit `Z`.
///
/// Absichtlich UTC und nicht Ortszeit: Eine Ortszeit ohne
/// `VTIMEZONE`-Block ist mehrdeutig, und einen solchen Block richtig
/// hinzuschreiben ist deutlich mehr Arbeit als er wert ist — der
/// Kalender rechnet die UTC-Zeit ohnehin in die Zone des Menschen
/// zurück.
String _icsZeit(DateTime t) {
  final u = t.toUtc();
  String z(int v, [int stellen = 2]) => v.toString().padLeft(stellen, '0');
  return '${z(u.year, 4)}${z(u.month)}${z(u.day)}T'
      '${z(u.hour)}${z(u.minute)}${z(u.second)}Z';
}

/// Text so einpacken, dass er eine `.ics`-Zeile nicht zerreißt.
///
/// Komma, Semikolon und Backslash haben dort Bedeutung, und ein
/// Zeilenumbruch beendet das Feld. Dieselbe Sorte Falle wie beim CSV,
/// nur mit anderen Zeichen (RFC 5545).
String _icsText(String wert) => wert
    .replaceAll('\\', '\\\\')
    .replaceAll(';', '\\;')
    .replaceAll(',', '\\,')
    .replaceAll('\r\n', '\\n')
    .replaceAll('\n', '\\n');

/// Der Inhalt einer `.ics`-Datei für **eine** Verabredung.
///
/// [dauer] ist eine Annahme, keine Angabe: Eine Verabredung hat einen
/// Anfang und kein Ende — niemand sagt beim Ausmachen, wie lange er
/// bleibt. Zwei Stunden sind die freundliche Vermutung; im Kalender
/// lässt sich das mit einem Griff ändern.
String verabredungAlsIcs({
  required String id,
  required DateTime termin,
  required String gastgeber,
  String? ort,
  String? nachricht,
  Duration dauer = const Duration(hours: 2),
}) {
  final zeilen = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    // Pflichtfeld. Der Name sagt, wer die Datei erzeugt hat — nicht,
    // welches Programm sie öffnen soll.
    'PRODID:-//BrewMates//DE',
    'BEGIN:VEVENT',
    // Weltweit eindeutig, und **stabil**: Wer denselben Termin zweimal
    // exportiert, bekommt im Kalender einen aktualisierten Eintrag statt
    // eines zweiten.
    'UID:$id@brewmates',
    'DTSTAMP:${_icsZeit(DateTime.now())}',
    'DTSTART:${_icsZeit(termin)}',
    'DTEND:${_icsZeit(termin.add(dauer))}',
    'SUMMARY:${_icsText('🍻 $gastgeber')}',
    if (ort != null && ort.trim().isNotEmpty)
      'LOCATION:${_icsText(ort.trim())}',
    if (nachricht != null && nachricht.trim().isNotEmpty)
      'DESCRIPTION:${_icsText(nachricht.trim())}',
    'END:VEVENT',
    'END:VCALENDAR',
  ];
  // CRLF ist in iCalendar vorgeschrieben, nicht Geschmackssache.
  return '${zeilen.join('\r\n')}\r\n';
}

/// Adresse, unter der ein Web-Kalender denselben Termin vorausgefüllt
/// öffnet.
///
/// **Warum es das zusätzlich gibt:** Eine `.ics`-Datei ist der neutrale
/// Weg und funktioniert mit jedem Kalender — aber nur, wo eine Datei
/// ankommt. Auf dem Telefon bräuchte es dafür ein weiteres Plugin, und
/// ein neues Plugin ist in dieser Toolchain die teuerste Änderung, die
/// es gibt. Ein Link öffnet dort den Kalender direkt.
///
/// Der Dienst ist damit die Zweitlösung und nicht die erste: Wer die
/// Datei nehmen kann, bekommt sie.
String verabredungAlsKalenderLink({
  required DateTime termin,
  required String gastgeber,
  String? ort,
  String? nachricht,
  Duration dauer = const Duration(hours: 2),
}) {
  final von = _icsZeit(termin);
  final bis = _icsZeit(termin.add(dauer));
  final p = <String, String>{
    'action': 'TEMPLATE',
    'text': '🍻 $gastgeber',
    'dates': '$von/$bis',
    if (ort != null && ort.trim().isNotEmpty) 'location': ort.trim(),
    if (nachricht != null && nachricht.trim().isNotEmpty)
      'details': nachricht.trim(),
  };
  final query = p.entries
      .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
      .join('&');
  return 'https://calendar.google.com/calendar/render?$query';
}
