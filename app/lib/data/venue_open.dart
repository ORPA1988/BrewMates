/// „Jetzt geöffnet" — geteilt zwischen Gasthausliste und Karte.
///
/// Stand bis 2026-08-15 in `features/venues/venues_list_screen.dart` und
/// wurde von `features/map/` importiert. Das war ein Cross-Feature-Import
/// und damit ein Verstoß gegen eine der nicht verhandelbaren Regeln — er
/// blieb unbemerkt, weil der Architektur-Test nur absolute Pfade prüfte
/// und dieser relativ geschrieben war (`../venues/…`).
///
/// Hier statt in `domain/`, weil die Funktion auf dem Drift-Typ [Venue]
/// arbeitet. Die eigentliche Öffnungszeiten-Logik liegt weiterhin
/// datenbankfrei in `domain/opening_hours.dart`.
library;

import '../domain/opening_hours.dart';
import 'db/database.dart';

/// Nur die Gasthäuser, die zu [now] geöffnet haben.
List<Venue> openNow(List<Venue> venues, DateTime now) => [
      for (final v in venues)
        if (isOpenAt(parseOpeningHours(v.openingHoursJson), now)) v,
    ];
