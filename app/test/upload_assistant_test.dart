import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/online/online_service.dart';

CheckinDetails _details({
  required String checkinId,
  double? rating,
  String? sessionId,
}) {
  const brewery = Brewery(
    id: 'at-stiegl',
    name: 'Stieglbrauerei zu Salzburg',
    country: 'Österreich',
    city: 'Salzburg',
    address: null,
    latitude: null,
    longitude: null,
    founded: null,
    website: null,
    ownership: null,
    employees: null,
    annualOutputHl: null,
    revenueEur: null,
    notes: null,
    dataStatus: null,
  );
  const beer = Beer(
    id: 'at-stiegl-goldbraeu',
    breweryId: 'at-stiegl',
    name: 'Stiegl-Goldbräu',
    style: 'Märzen',
    abv: 4.9,
    ibu: null,
    description: null,
    isAlcoholFree: false,
    isUserSubmitted: false,
    descriptionCommunity: null,
    communityRating: null,
    barcodes: '90034107',
  );
  return CheckinDetails(
    checkin: Checkin(
      id: checkinId,
      profileId: 'me',
      dirty: false,
      beerId: beer.id,
      sessionId: sessionId,
      venueName: 'Bierlokal',
      rating: rating,
      note: 'Prost!',
      flavorTags: '',
      servingStyle: null,
      visibility: SessionVisibility.friends,
      createdAt: DateTime.utc(2026, 8, 1, 18, 30),
    ),
    beer: beer,
    brewery: brewery,
    author: const Profile(
      id: 'me',
      username: 'ich',
      displayName: 'Ich',
      avatarEmoji: '🍺',
      defaultVisibility: SessionVisibility.friends,
      bio: null,
      favoriteStyles: '',
      isMe: true,
    ),
  );
}

void main() {
  test('uploadRow bildet einen lokalen Check-in denormalisiert ab', () {
    final row = CheckinsApi.uploadRow(
      _details(
          checkinId: '4fa4b620-9f1c-4e2b-8f63-1c2d3e4f5a6b', rating: 4.25),
      'profil-uuid',
    );
    expect(row, isNotNull);
    expect(row!['id'], '4fa4b620-9f1c-4e2b-8f63-1c2d3e4f5a6b');
    expect(row['profile_id'], 'profil-uuid');
    expect(row['beer_name'], 'Stiegl-Goldbräu');
    expect(row['brewery_name'], 'Stieglbrauerei zu Salzburg');
    expect(row['beer_style'], 'Märzen');
    expect(row['is_alcohol_free'], false);
    expect(row['rating'], 4.25);
    expect(row['note'], 'Prost!');
    expect(row['venue_name'], 'Bierlokal');
    expect(row['visibility'], 'friends');
    expect(row['session_id'], isNull, reason: 'ohne Runde bleibt es leer');
    expect(row['created_at'], '2026-08-01T18:30:00.000Z');
  });

  group('Die Runde geht mit hoch', () {
    // Bis 0.10.14 stand hier `'session_id': null`, hart verdrahtet. Damit
    // kam die Zuordnung **nie** am Server an — auch die zur eigenen Runde
    // nicht. Alles, was darauf aufbaut, lief ins Leere: die Crew-Bilanz
    // fand nichts, und der Runden-Zweig in `checkins_select` (0050) griff
    // nie, weil `session_id is not null` nie zutraf.
    test('Die eigene Runde trägt am Server dieselbe UUID', () {
      final row = CheckinsApi.uploadRow(
        _details(
          checkinId: '4fa4b620-9f1c-4e2b-8f63-1c2d3e4f5a6b',
          sessionId: '7c9e6679-7425-40de-944b-e07fc1f90ae7',
        ),
        'profil-uuid',
      );
      expect(row!['session_id'], '7c9e6679-7425-40de-944b-e07fc1f90ae7');
    });

    test('Eine fremde Runde verliert ihr remote-Präfix', () {
      // Lokal tragen fremde IDs ein Präfix; der Server kennt nur die
      // blanke UUID.
      final row = CheckinsApi.uploadRow(
        _details(
          checkinId: '4fa4b620-9f1c-4e2b-8f63-1c2d3e4f5a6b',
          sessionId: 'remote-7c9e6679-7425-40de-944b-e07fc1f90ae7',
        ),
        'profil-uuid',
      );
      expect(row!['session_id'], '7c9e6679-7425-40de-944b-e07fc1f90ae7');
    });

    test('Eine sprechende Demo-ID geht NICHT mit', () {
      // Sie existiert am Server nicht und verlöre über den Fremdschlüssel
      // den ganzen Check-in — nicht nur seine Zuordnung.
      final row = CheckinsApi.uploadRow(
        _details(
          checkinId: '4fa4b620-9f1c-4e2b-8f63-1c2d3e4f5a6b',
          sessionId: 'demo-session-1',
        ),
        'profil-uuid',
      );
      expect(row!['session_id'], isNull);
    });

    test('serverSessionId beantwortet alle drei Fälle einzeln', () {
      expect(CheckinsApi.serverSessionId(null), isNull);
      expect(
        CheckinsApi.serverSessionId('7c9e6679-7425-40de-944b-e07fc1f90ae7'),
        '7c9e6679-7425-40de-944b-e07fc1f90ae7',
      );
      expect(
        CheckinsApi.serverSessionId(
            'remote-7c9e6679-7425-40de-944b-e07fc1f90ae7'),
        '7c9e6679-7425-40de-944b-e07fc1f90ae7',
      );
      expect(CheckinsApi.serverSessionId('local-abc'), isNull);
    });
  });

  test('Demo-/Seed-Check-ins ohne UUID werden nicht übertragen', () {
    final demo = _details(checkinId: 'demo-checkin-1');
    expect(CheckinsApi.isUploadable(demo), isFalse);
    expect(CheckinsApi.uploadRow(demo, 'profil-uuid'), isNull);

    final echt =
        _details(checkinId: '4fa4b620-9f1c-4e2b-8f63-1c2d3e4f5a6b');
    expect(CheckinsApi.isUploadable(echt), isTrue);
  });
}
