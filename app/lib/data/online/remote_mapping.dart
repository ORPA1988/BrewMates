import '../db/database.dart';
import 'online_service.dart';

/// Übersetzt Online-Daten in die lokalen Anzeige-Typen, damit alle
/// bestehenden Widgets (SessionCard, CheckinCard, Karte …) unverändert
/// funktionieren. Remote-IDs tragen das Präfix `remote-`, damit Aktionen
/// (Toast, Beitreten, Navigation) sie unterscheiden können.

const String remotePrefix = 'remote-';

bool isRemoteId(String id) => id.startsWith(remotePrefix);

String stripRemote(String id) =>
    isRemoteId(id) ? id.substring(remotePrefix.length) : id;

Profile remoteProfileToLocal(RemoteProfile p) => Profile(
      id: '$remotePrefix${p.id}',
      username: p.username,
      displayName: p.displayName,
      avatarEmoji: p.avatarEmoji,
      bio: null,
      favoriteStyles: '',
      isMe: false,
    );

SessionDetails remoteSessionToDetails(RemoteSession s) => SessionDetails(
      session: Session(
        id: '$remotePrefix${s.id}',
        hostId: '$remotePrefix${s.host.id}',
        venueName: s.venueName,
        message: s.message,
        visibility: SessionVisibility.friends,
        status: SessionStatus.active,
        startedAt: s.startedAt,
        endedAt: null,
        expiresAt: s.expiresAt,
        latitude: s.latitude,
        longitude: s.longitude,
      ),
      host: remoteProfileToLocal(s.host),
      participants: const [],
    );

CheckinDetails remoteCheckinToDetails(RemoteCheckin c) {
  final brewery = Brewery(
    id: '$remotePrefix-brewery',
    name: c.breweryName ?? 'Unbekannte Brauerei',
    country: '',
    city: '',
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
  return CheckinDetails(
    checkin: Checkin(
      id: '$remotePrefix${c.id}',
      profileId: '$remotePrefix${c.author.id}',
      // Fremde Check-ins kommen vom Server — nichts nachzureichen.
      dirty: false,
      beerId: '$remotePrefix-beer',
      sessionId: c.sessionId,
      venueName: c.venueName,
      rating: c.rating,
      note: c.note,
      flavorTags: '',
      servingStyle: null,
      photoUrl: c.photoUrl,
      createdAt: c.createdAt,
    ),
    beer: Beer(
      id: '$remotePrefix-beer',
      breweryId: brewery.id,
      name: c.beerName,
      style: c.beerStyle ?? 'Bier',
      abv: null,
      ibu: null,
      description: null,
      isAlcoholFree: c.isAlcoholFree,
      isUserSubmitted: false,
      descriptionCommunity: null,
      communityRating: null,
      barcodes: '',
    ),
    brewery: brewery,
    author: remoteProfileToLocal(c.author),
  );
}
