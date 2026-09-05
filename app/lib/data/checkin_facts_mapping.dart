/// Drift-Zeile → [CheckinFacts].
///
/// Die eine Stelle, an der die Datenbankform in die Form übersetzt wird,
/// mit der Statistiken, Abzeichen und Challenges rechnen. Vorher gab es
/// diese Übersetzung gar nicht — die Logik in `domain/` arbeitete direkt
/// auf `CheckinDetails` und importierte dafür die Datenbank.
library;

import '../core/checkin_facts.dart';
import 'db/database.dart';

extension CheckinDetailsFacts on CheckinDetails {
  CheckinFacts get facts => CheckinFacts(
        createdAt: checkin.createdAt,
        beerId: beer.id,
        beerName: beer.name,
        beerStyle: beer.style,
        isAlcoholFree: beer.isAlcoholFree,
        breweryId: brewery.id,
        breweryName: brewery.name,
        breweryCountry: brewery.country,
        abv: beer.abv,
        breweryCity: brewery.city,
        sessionId: checkin.sessionId,
        venueId: checkin.venueId,
        venueName: checkin.venueName,
        note: checkin.note,
        volumeMl: checkin.volumeMl,
        serving: checkin.servingStyle,
        rating: checkin.rating,
      );
}

extension CheckinDetailsListFacts on List<CheckinDetails> {
  List<CheckinFacts> get facts => [for (final d in this) d.facts];
}
