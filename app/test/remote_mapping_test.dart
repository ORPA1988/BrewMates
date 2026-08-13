import 'package:flutter_test/flutter_test.dart';

import 'package:brewmates/data/db/database.dart';
import 'package:brewmates/data/online/online_service.dart';
import 'package:brewmates/data/online/remote_mapping.dart';

void main() {
  const anna = RemoteProfile(
    id: 'abc-123',
    username: 'anna_echt',
    displayName: 'Anna',
    avatarEmoji: '🍺',
  );

  test('Remote-IDs werden erkannt und sauber entpackt', () {
    expect(isRemoteId('remote-abc'), isTrue);
    expect(isRemoteId('local-abc'), isFalse);
    expect(stripRemote('remote-abc'), 'abc');
    expect(stripRemote('abc'), 'abc');
  });

  test('RemoteSession wird zu anzeigbaren SessionDetails', () {
    final now = DateTime.now();
    final details = remoteSessionToDetails(RemoteSession(
      id: 's1',
      host: anna,
      venueName: 'Hopfengarten',
      message: 'Alle willkommen! 🍻',
      latitude: 48.2,
      longitude: 16.37,
      startedAt: now,
      expiresAt: now.add(const Duration(hours: 3)),
    ));

    expect(details.session.id, 'remote-s1');
    expect(details.host.isMe, isFalse);
    expect(details.host.displayName, 'Anna');
    expect(details.session.status, SessionStatus.active);
    expect(details.isActiveAt(now), isTrue);
    expect(details.session.latitude, 48.2);
  });

  test('RemoteCheckin wird zu anzeigbaren CheckinDetails', () {
    final details = remoteCheckinToDetails(RemoteCheckin(
      id: 'c1',
      author: anna,
      beerName: 'Stiegl-Goldbräu',
      breweryName: 'Stiegl',
      beerStyle: 'Märzen',
      rating: 4.25,
      note: 'Prost!',
      venueName: 'Hopfengarten',
      createdAt: DateTime.now(),
    ));

    expect(details.checkin.id, 'remote-c1');
    expect(details.beer.name, 'Stiegl-Goldbräu');
    expect(details.brewery.name, 'Stiegl');
    expect(details.checkin.rating, 4.25);
    expect(details.author.username, 'anna_echt');
  });

  test('Fehlende Angaben bekommen sinnvolle Platzhalter', () {
    final details = remoteCheckinToDetails(RemoteCheckin(
      id: 'c2',
      author: anna,
      beerName: 'Mysteriöses Bier',
      createdAt: DateTime.now(),
    ));
    expect(details.brewery.name, 'Unbekannte Brauerei');
    expect(details.beer.style, 'Bier');
    expect(details.checkin.rating, isNull);
  });
}
