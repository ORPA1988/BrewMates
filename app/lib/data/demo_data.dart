import '../domain/models.dart';

/// Platzhalterdaten für den Offline-Demo-Modus (ohne Supabase-Zugangsdaten).
/// Die echten Repositories (Supabase + Drift) ersetzen dieses Modul.
class DemoData {
  static const anna = Profile(
    id: 'demo-anna',
    username: 'anna_hops',
    displayName: 'Anna',
  );
  static const ben = Profile(
    id: 'demo-ben',
    username: 'ben_braut',
    displayName: 'Ben',
  );

  static const hopfengold = Beer(
    id: 'demo-beer-1',
    name: 'Hopfengold',
    style: 'Helles',
    abv: 5.2,
    ibu: 22,
    brewery: Brewery(
      id: 'demo-brew-1',
      name: 'Brauhaus am See',
      country: 'DE',
      city: 'München',
    ),
  );
  static const nebelwerfer = Beer(
    id: 'demo-beer-2',
    name: 'Nebelwerfer NEIPA',
    style: 'New England IPA',
    abv: 6.8,
    ibu: 45,
    brewery: Brewery(
      id: 'demo-brew-2',
      name: 'Kellerkind Craft',
      country: 'DE',
      city: 'Berlin',
    ),
  );

  static List<Session> activeSessions() => [
        Session(
          id: 'demo-session-1',
          host: anna,
          visibility: SessionVisibility.friends,
          status: SessionStatus.active,
          startedAt: DateTime.now().subtract(const Duration(minutes: 40)),
          expiresAt: DateTime.now().add(const Duration(hours: 2)),
          venueName: 'Hopfengarten',
          message: 'Hinten im Garten, Tisch 12 🌳',
          latitude: 48.1374,
          longitude: 11.5755,
        ),
      ];

  static List<CheckIn> feed() => [
        CheckIn(
          id: 'demo-checkin-1',
          author: anna,
          beer: hopfengold,
          rating: 4.25,
          note: 'Perfekt für den Sommerabend!',
          venueName: 'Hopfengarten',
          sessionId: 'demo-session-1',
          flavorTags: const ['süffig', 'malzig'],
          createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
        ),
        CheckIn(
          id: 'demo-checkin-2',
          author: ben,
          beer: nebelwerfer,
          rating: 4.75,
          note: 'Tropische Bombe 🍍',
          flavorTags: const ['fruchtig', 'hopfig'],
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
      ];
}
