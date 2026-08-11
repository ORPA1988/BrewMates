import 'package:drift/drift.dart';

import 'db/database.dart';

/// Befüllt die frisch erstellte Datenbank mit Demo-Daten.
///
/// Wird genau einmal in [MigrationStrategy.onCreate] aufgerufen.
Future<void> seedDatabase(AppDatabase db) async {
  final now = DateTime.now();

  await db.batch((b) {
    // ------------------------------------------------------------------------
    // Profile
    // ------------------------------------------------------------------------
    b.insertAll(db.profiles, [
      ProfilesCompanion.insert(
        id: 'me',
        username: 'du',
        displayName: 'Du',
        avatarEmoji: const Value('🍻'),
        isMe: const Value(true),
      ),
      ProfilesCompanion.insert(
        id: 'anna',
        username: 'anna_hops',
        displayName: 'Anna',
        avatarEmoji: const Value('🍺'),
        bio: const Value('Immer auf der Jagd nach dem perfekten IPA.'),
        favoriteStyles: const Value('IPA,Pale Ale'),
      ),
      ProfilesCompanion.insert(
        id: 'ben',
        username: 'ben_braut',
        displayName: 'Ben',
        avatarEmoji: const Value('🧔'),
        bio: const Value('Hobbybrauer mit Faible für belgische Klassiker.'),
        favoriteStyles: const Value('Tripel,Dubbel,Stout'),
      ),
      ProfilesCompanion.insert(
        id: 'clara',
        username: 'clara_craft',
        displayName: 'Clara',
        avatarEmoji: const Value('🥨'),
        bio: const Value('Biergarten-Fan – am liebsten Helles unter Kastanien.'),
        favoriteStyles: const Value('Helles,Weissbier'),
      ),
    ]);

    // ------------------------------------------------------------------------
    // Brauereien
    // ------------------------------------------------------------------------
    b.insertAll(db.breweries, [
      BreweriesCompanion.insert(
        id: 'brewery-augustiner',
        name: 'Augustiner-Bräu',
        country: 'Deutschland',
        city: 'München',
      ),
      BreweriesCompanion.insert(
        id: 'brewery-schlenkerla',
        name: 'Schlenkerla',
        country: 'Deutschland',
        city: 'Bamberg',
      ),
      BreweriesCompanion.insert(
        id: 'brewery-brlo',
        name: 'BRLO',
        country: 'Deutschland',
        city: 'Berlin',
      ),
      BreweriesCompanion.insert(
        id: 'brewery-westmalle',
        name: 'Brouwerij Westmalle',
        country: 'Belgien',
        city: 'Westmalle',
      ),
      BreweriesCompanion.insert(
        id: 'brewery-duvel',
        name: 'Duvel Moortgat',
        country: 'Belgien',
        city: 'Puurs',
      ),
      BreweriesCompanion.insert(
        id: 'brewery-pilsner-urquell',
        name: 'Pilsner Urquell',
        country: 'Tschechien',
        city: 'Pilsen',
      ),
      BreweriesCompanion.insert(
        id: 'brewery-fullers',
        name: "Fuller's",
        country: 'Vereinigtes Königreich',
        city: 'London',
      ),
      BreweriesCompanion.insert(
        id: 'brewery-guinness',
        name: 'Guinness',
        country: 'Irland',
        city: 'Dublin',
      ),
      BreweriesCompanion.insert(
        id: 'brewery-sierra-nevada',
        name: 'Sierra Nevada Brewing Co.',
        country: 'USA',
        city: 'Chico',
      ),
      BreweriesCompanion.insert(
        id: 'brewery-founders',
        name: 'Founders Brewing Co.',
        country: 'USA',
        city: 'Grand Rapids',
      ),
      BreweriesCompanion.insert(
        id: 'brewery-modelo',
        name: 'Grupo Modelo',
        country: 'Mexiko',
        city: 'Mexiko-Stadt',
      ),
      BreweriesCompanion.insert(
        id: 'brewery-asahi',
        name: 'Asahi Breweries',
        country: 'Japan',
        city: 'Tokio',
      ),
      BreweriesCompanion.insert(
        id: 'brewery-la-trappe',
        name: 'La Trappe',
        country: 'Niederlande',
        city: 'Berkel-Enschot',
      ),
      BreweriesCompanion.insert(
        id: 'brewery-stiegl',
        name: 'Stiegl',
        country: 'Österreich',
        city: 'Salzburg',
      ),
    ]);

    // ------------------------------------------------------------------------
    // Biere
    // ------------------------------------------------------------------------
    b.insertAll(db.beers, [
      // Augustiner
      BeersCompanion.insert(
        id: 'beer-augustiner-helles',
        breweryId: 'brewery-augustiner',
        name: 'Lagerbier Hell',
        style: 'Helles',
        abv: const Value(5.2),
        ibu: const Value(18),
        description: const Value(
            'Münchner Klassiker – mild, süffig und wunderbar ausgewogen.'),
      ),
      BeersCompanion.insert(
        id: 'beer-augustiner-edelstoff',
        breweryId: 'brewery-augustiner',
        name: 'Edelstoff',
        style: 'Helles',
        abv: const Value(5.6),
        ibu: const Value(20),
        description: const Value(
            'Der feine Export aus München mit leicht süßlicher Malznote.'),
      ),
      BeersCompanion.insert(
        id: 'beer-augustiner-weissbier',
        breweryId: 'brewery-augustiner',
        name: 'Weissbier',
        style: 'Weissbier',
        abv: const Value(5.4),
        ibu: const Value(14),
        description: const Value(
            'Fruchtiges Weissbier mit Banane und einem Hauch Nelke.'),
      ),
      // Schlenkerla
      BeersCompanion.insert(
        id: 'beer-schlenkerla-maerzen',
        breweryId: 'brewery-schlenkerla',
        name: 'Aecht Schlenkerla Rauchbier Märzen',
        style: 'Rauchbier',
        abv: const Value(5.1),
        ibu: const Value(30),
        description: const Value(
            'Das Bamberger Original – intensiv rauchig wie geräucherter Schinken.'),
      ),
      BeersCompanion.insert(
        id: 'beer-schlenkerla-urbock',
        breweryId: 'brewery-schlenkerla',
        name: 'Aecht Schlenkerla Urbock',
        style: 'Rauchbier',
        abv: const Value(6.5),
        ibu: const Value(32),
        description: const Value(
            'Kräftiger Rauchbock mit tiefem Malzkörper und langem Abgang.'),
      ),
      // BRLO
      BeersCompanion.insert(
        id: 'beer-brlo-german-ipa',
        breweryId: 'brewery-brlo',
        name: 'German IPA',
        style: 'IPA',
        abv: const Value(6.0),
        ibu: const Value(55),
        description: const Value(
            'Berliner IPA mit deutschen Aromahopfen – zitrusfrisch und trocken.'),
      ),
      BeersCompanion.insert(
        id: 'beer-brlo-pale-ale',
        breweryId: 'brewery-brlo',
        name: 'Pale Ale',
        style: 'Pale Ale',
        abv: const Value(5.0),
        ibu: const Value(38),
        description: const Value(
            'Zugängliches Pale Ale mit fruchtiger Hopfennote und schlankem Körper.'),
      ),
      BeersCompanion.insert(
        id: 'beer-brlo-naked',
        breweryId: 'brewery-brlo',
        name: 'Naked',
        style: 'Pale Ale',
        abv: const Value(0.5),
        ibu: const Value(30),
        description: const Value(
            'Alkoholfreies Pale Ale mit voller Hopfenblume und knackiger Bittere.'),
        isAlcoholFree: const Value(true),
      ),
      // Westmalle
      BeersCompanion.insert(
        id: 'beer-westmalle-tripel',
        breweryId: 'brewery-westmalle',
        name: 'Westmalle Tripel',
        style: 'Tripel',
        abv: const Value(9.5),
        ibu: const Value(36),
        description: const Value(
            'Die Mutter aller Tripel – goldgelb, komplex und gefährlich trinkbar.'),
      ),
      BeersCompanion.insert(
        id: 'beer-westmalle-dubbel',
        breweryId: 'brewery-westmalle',
        name: 'Westmalle Dubbel',
        style: 'Dubbel',
        abv: const Value(7.0),
        ibu: const Value(24),
        description: const Value(
            'Dunkles Trappistenbier mit Aromen von Dörrobst und Karamell.'),
      ),
      // Duvel Moortgat
      BeersCompanion.insert(
        id: 'beer-duvel',
        breweryId: 'brewery-duvel',
        name: 'Duvel',
        style: 'Belgian Strong Golden Ale',
        abv: const Value(8.5),
        ibu: const Value(32),
        description: const Value(
            'Der Teufel im Glas – hell, spritzig und mit trügerischer Leichtigkeit.'),
      ),
      BeersCompanion.insert(
        id: 'beer-duvel-tripel-hop',
        breweryId: 'brewery-duvel',
        name: 'Duvel Tripel Hop Citra',
        style: 'Belgian IPA',
        abv: const Value(9.5),
        ibu: const Value(40),
        description: const Value(
            'Duvel mit Citra-Hopfen veredelt – tropisch, herb und kraftvoll.'),
      ),
      // Pilsner Urquell
      BeersCompanion.insert(
        id: 'beer-pilsner-urquell',
        breweryId: 'brewery-pilsner-urquell',
        name: 'Pilsner Urquell',
        style: 'Pilsner',
        abv: const Value(4.4),
        ibu: const Value(40),
        description: const Value(
            'Das Urpilsner aus Pilsen mit würzigem Saazer Hopfen.'),
      ),
      BeersCompanion.insert(
        id: 'beer-pilsner-urquell-nealko',
        breweryId: 'brewery-pilsner-urquell',
        name: 'Pilsner Urquell Nealko',
        style: 'Pilsner',
        abv: const Value(0.5),
        ibu: const Value(35),
        description: const Value(
            'Alkoholfreie Variante des Originals – hopfig-herb und erfrischend.'),
        isAlcoholFree: const Value(true),
      ),
      // Fuller's
      BeersCompanion.insert(
        id: 'beer-fullers-esb',
        breweryId: 'brewery-fullers',
        name: 'Fuller\'s ESB',
        style: 'ESB',
        abv: const Value(5.9),
        ibu: const Value(35),
        description: const Value(
            'Britischer Bitter-Klassiker mit Marmeladen- und Toffee-Noten.'),
      ),
      BeersCompanion.insert(
        id: 'beer-fullers-london-pride',
        breweryId: 'brewery-fullers',
        name: 'London Pride',
        style: 'Pale Ale',
        abv: const Value(4.7),
        ibu: const Value(30),
        description: const Value(
            'Ausgewogenes Amber Ale und der Stolz jeder Londoner Pub-Theke.'),
      ),
      // Guinness
      BeersCompanion.insert(
        id: 'beer-guinness-draught',
        breweryId: 'brewery-guinness',
        name: 'Guinness Draught',
        style: 'Stout',
        abv: const Value(4.2),
        ibu: const Value(45),
        description: const Value(
            'Cremiges irisches Stout mit Röstaromen und samtiger Stickstoff-Krone.'),
      ),
      BeersCompanion.insert(
        id: 'beer-guinness-fes',
        breweryId: 'brewery-guinness',
        name: 'Foreign Extra Stout',
        style: 'Stout',
        abv: const Value(7.5),
        ibu: const Value(65),
        description: const Value(
            'Das kräftige Export-Stout mit dunkler Schokolade und Bitterkaffee.'),
      ),
      BeersCompanion.insert(
        id: 'beer-guinness-zero',
        breweryId: 'brewery-guinness',
        name: 'Guinness 0.0',
        style: 'Stout',
        abv: const Value(0.0),
        ibu: const Value(40),
        description: const Value(
            'Alkoholfreies Guinness, das dem Original erstaunlich nahekommt.'),
        isAlcoholFree: const Value(true),
      ),
      // Sierra Nevada
      BeersCompanion.insert(
        id: 'beer-sierra-nevada-pale-ale',
        breweryId: 'brewery-sierra-nevada',
        name: 'Sierra Nevada Pale Ale',
        style: 'Pale Ale',
        abv: const Value(5.6),
        ibu: const Value(38),
        description: const Value(
            'Der Craft-Beer-Pionier mit piniger Cascade-Hopfennote.'),
      ),
      BeersCompanion.insert(
        id: 'beer-sierra-nevada-torpedo',
        breweryId: 'brewery-sierra-nevada',
        name: 'Torpedo Extra IPA',
        style: 'IPA',
        abv: const Value(7.2),
        ibu: const Value(65),
        description: const Value(
            'Hopfenbombe aus dem Torpedo-Verfahren – harzig, herb, zitrisch.'),
      ),
      BeersCompanion.insert(
        id: 'beer-sierra-nevada-hazy',
        breweryId: 'brewery-sierra-nevada',
        name: 'Hazy Little Thing',
        style: 'Hazy IPA',
        abv: const Value(6.7),
        ibu: const Value(35),
        description: const Value(
            'Trübes, saftiges IPA mit tropischen Fruchtaromen und weichem Mundgefühl.'),
      ),
      // Founders
      BeersCompanion.insert(
        id: 'beer-founders-breakfast-stout',
        breweryId: 'brewery-founders',
        name: 'Breakfast Stout',
        style: 'Stout',
        abv: const Value(8.3),
        ibu: const Value(60),
        description: const Value(
            'Imperial Stout mit Kaffee, Schokolade und Haferflocken – Frühstück deluxe.'),
      ),
      BeersCompanion.insert(
        id: 'beer-founders-all-day-ipa',
        breweryId: 'brewery-founders',
        name: 'All Day IPA',
        style: 'Session IPA',
        abv: const Value(4.7),
        ibu: const Value(42),
        description: const Value(
            'Leichtes Session-IPA, das den ganzen Tag trinkbar bleibt.'),
      ),
      // Grupo Modelo
      BeersCompanion.insert(
        id: 'beer-modelo-negra',
        breweryId: 'brewery-modelo',
        name: 'Negra Modelo',
        style: 'Lager',
        abv: const Value(5.4),
        ibu: const Value(20),
        description: const Value(
            'Dunkles mexikanisches Lager nach Wiener Art mit sanfter Karamellnote.'),
      ),
      BeersCompanion.insert(
        id: 'beer-modelo-especial',
        breweryId: 'brewery-modelo',
        name: 'Modelo Especial',
        style: 'Lager',
        abv: const Value(4.4),
        ibu: const Value(18),
        description: const Value(
            'Helles, unkompliziertes Lager – perfekt für heiße Tage.'),
      ),
      // Asahi
      BeersCompanion.insert(
        id: 'beer-asahi-super-dry',
        breweryId: 'brewery-asahi',
        name: 'Asahi Super Dry',
        style: 'Lager',
        abv: const Value(5.0),
        ibu: const Value(16),
        description: const Value(
            'Knochentrockenes japanisches Lager mit knackig-kurzem Abgang.'),
      ),
      // La Trappe
      BeersCompanion.insert(
        id: 'beer-la-trappe-quadrupel',
        breweryId: 'brewery-la-trappe',
        name: 'La Trappe Quadrupel',
        style: 'Quadrupel',
        abv: const Value(10.0),
        ibu: const Value(20),
        description: const Value(
            'Bernsteinfarbener Trappisten-Quadrupel mit Rosinen, Feige und Wärme.'),
      ),
      BeersCompanion.insert(
        id: 'beer-la-trappe-witte',
        breweryId: 'brewery-la-trappe',
        name: 'La Trappe Witte Trappist',
        style: 'Witbier',
        abv: const Value(5.5),
        ibu: const Value(14),
        description: const Value(
            'Das einzige Trappisten-Witbier – frisch, hefig und leicht zitronig.'),
      ),
      // Stiegl
      BeersCompanion.insert(
        id: 'beer-stiegl-goldbraeu',
        breweryId: 'brewery-stiegl',
        name: 'Stiegl-Goldbräu',
        style: 'Märzen',
        abv: const Value(4.9),
        ibu: const Value(20),
        description: const Value(
            'Salzburger Märzen mit mildem Hopfen und sauberem Malzkörper.'),
      ),
      BeersCompanion.insert(
        id: 'beer-stiegl-freibier',
        breweryId: 'brewery-stiegl',
        name: 'Stiegl Freibier',
        style: 'Lager',
        abv: const Value(0.4),
        ibu: const Value(18),
        description: const Value(
            'Alkoholfreies Lager aus Salzburg – vollmundig statt wässrig.'),
        isAlcoholFree: const Value(true),
      ),
    ]);

    // ------------------------------------------------------------------------
    // Sessions
    // ------------------------------------------------------------------------
    b.insertAll(db.sessions, [
      // Aktive Session von Anna.
      SessionsCompanion.insert(
        id: 'session-anna-1',
        hostId: 'anna',
        venueName: const Value('Hopfengarten'),
        message: const Value('Hinten im Garten, Tisch 12 🌳'),
        visibility: SessionVisibility.friends,
        status: SessionStatus.active,
        startedAt: now.subtract(const Duration(minutes: 40)),
        expiresAt: now.add(const Duration(hours: 2)),
        latitude: const Value(48.1374),
        longitude: const Value(11.5755),
      ),
      // Beendete Session von Ben (gestern).
      SessionsCompanion.insert(
        id: 'session-ben-1',
        hostId: 'ben',
        venueName: const Value('Craft Corner'),
        message: const Value('Spontane Verkostungsrunde 🍻'),
        visibility: SessionVisibility.friends,
        status: SessionStatus.ended,
        startedAt: now.subtract(const Duration(hours: 26)),
        endedAt: Value(now.subtract(const Duration(hours: 23))),
        expiresAt: now.subtract(const Duration(hours: 23)),
        latitude: const Value(48.1421),
        longitude: const Value(11.5810),
      ),
    ]);

    b.insertAll(db.sessionParticipants, [
      SessionParticipantsCompanion.insert(
        sessionId: 'session-anna-1',
        profileId: 'ben',
        kind: ParticipantKind.joined,
      ),
      SessionParticipantsCompanion.insert(
        sessionId: 'session-ben-1',
        profileId: 'clara',
        kind: ParticipantKind.joined,
      ),
    ]);

    // ------------------------------------------------------------------------
    // Check-ins der Freunde (letzte 14 Tage)
    // ------------------------------------------------------------------------
    b.insertAll(db.checkins, [
      // Anna – in der aktiven Session.
      CheckinsCompanion.insert(
        id: 'checkin-anna-1',
        profileId: 'anna',
        beerId: 'beer-brlo-german-ipa',
        sessionId: const Value('session-anna-1'),
        venueName: const Value('Hopfengarten'),
        rating: const Value(4.25),
        note: const Value('Herrlich zitrisch, genau mein Ding heute Abend.'),
        flavorTags: const Value('hopfig,fruchtig'),
        servingStyle: const Value(ServingStyle.draft),
        createdAt: now.subtract(const Duration(minutes: 30)),
      ),
      CheckinsCompanion.insert(
        id: 'checkin-anna-2',
        profileId: 'anna',
        beerId: 'beer-sierra-nevada-hazy',
        sessionId: const Value('session-anna-1'),
        venueName: const Value('Hopfengarten'),
        rating: const Value(4.5),
        note: const Value('Saftig wie Maracujasaft – der Abend kann kommen!'),
        flavorTags: const Value('fruchtig,blumig'),
        servingStyle: const Value(ServingStyle.can),
        createdAt: now.subtract(const Duration(minutes: 10)),
      ),
      // Ben & Clara – in Bens beendeter Session.
      CheckinsCompanion.insert(
        id: 'checkin-ben-1',
        profileId: 'ben',
        beerId: 'beer-westmalle-tripel',
        sessionId: const Value('session-ben-1'),
        venueName: const Value('Craft Corner'),
        rating: const Value(4.75),
        note: const Value('Immer noch der Maßstab für Tripel. Perfektion.'),
        flavorTags: const Value('würzig,fruchtig,blumig'),
        servingStyle: const Value(ServingStyle.bottle),
        createdAt: now.subtract(const Duration(hours: 25, minutes: 30)),
      ),
      CheckinsCompanion.insert(
        id: 'checkin-clara-1',
        profileId: 'clara',
        beerId: 'beer-duvel',
        sessionId: const Value('session-ben-1'),
        venueName: const Value('Craft Corner'),
        rating: const Value(4.0),
        note: const Value('Man merkt die 8,5 % wirklich nicht – Vorsicht!'),
        flavorTags: const Value('würzig,fruchtig'),
        servingStyle: const Value(ServingStyle.bottle),
        createdAt: now.subtract(const Duration(hours: 24, minutes: 45)),
      ),
      // Weitere Check-ins der letzten zwei Wochen.
      CheckinsCompanion.insert(
        id: 'checkin-ben-2',
        profileId: 'ben',
        beerId: 'beer-schlenkerla-maerzen',
        venueName: const Value('Zum Goldenen Fass'),
        rating: const Value(4.5),
        note: const Value('Wie ein Lagerfeuer im Glas – ich liebe es.'),
        flavorTags: const Value('rauchig,malzig'),
        servingStyle: const Value(ServingStyle.draft),
        createdAt: now.subtract(const Duration(days: 2, hours: 5)),
      ),
      CheckinsCompanion.insert(
        id: 'checkin-clara-2',
        profileId: 'clara',
        beerId: 'beer-augustiner-helles',
        venueName: const Value('Biergarten am See'),
        rating: const Value(4.5),
        note: const Value('Süffiger wird es nicht. Sommer, See, Augustiner.'),
        flavorTags: const Value('süffig,malzig'),
        servingStyle: const Value(ServingStyle.draft),
        createdAt: now.subtract(const Duration(days: 3, hours: 7)),
      ),
      CheckinsCompanion.insert(
        id: 'checkin-anna-3',
        profileId: 'anna',
        beerId: 'beer-founders-all-day-ipa',
        rating: const Value(3.75),
        note: const Value('Leicht und lecker – ideal für den Feierabend.'),
        flavorTags: const Value('hopfig,süffig'),
        servingStyle: const Value(ServingStyle.can),
        createdAt: now.subtract(const Duration(days: 5, hours: 3)),
      ),
      CheckinsCompanion.insert(
        id: 'checkin-ben-3',
        profileId: 'ben',
        beerId: 'beer-guinness-fes',
        venueName: const Value('Craft Corner'),
        rating: const Value(4.25),
        note: const Value('Bitterschokolade und Espresso – großes Kino.'),
        flavorTags: const Value('schokoladig,malzig'),
        servingStyle: const Value(ServingStyle.bottle),
        createdAt: now.subtract(const Duration(days: 7, hours: 2)),
      ),
      CheckinsCompanion.insert(
        id: 'checkin-clara-3',
        profileId: 'clara',
        beerId: 'beer-la-trappe-witte',
        venueName: const Value('Biergarten am See'),
        rating: const Value(3.5),
        note: const Value('Schön frisch, ein Hauch Zitrone – passt zum Wetter.'),
        flavorTags: const Value('fruchtig,blumig,sauer'),
        servingStyle: const Value(ServingStyle.bottle),
        createdAt: now.subtract(const Duration(days: 9, hours: 6)),
      ),
      CheckinsCompanion.insert(
        id: 'checkin-anna-4',
        profileId: 'anna',
        beerId: 'beer-pilsner-urquell',
        venueName: const Value('Zum Goldenen Fass'),
        rating: const Value(4.0),
        note: const Value('Vom Fass eine ganz andere Liga als aus der Flasche.'),
        flavorTags: const Value('hopfig,würzig'),
        servingStyle: const Value(ServingStyle.draft),
        createdAt: now.subtract(const Duration(days: 12, hours: 4)),
      ),
      CheckinsCompanion.insert(
        id: 'checkin-ben-4',
        profileId: 'ben',
        beerId: 'beer-la-trappe-quadrupel',
        rating: const Value(4.5),
        note: const Value('Rosinen, Feigen, Karamell – ein Dessert im Glas.'),
        flavorTags: const Value('malzig,karamellig,fruchtig'),
        servingStyle: const Value(ServingStyle.bottle),
        createdAt: now.subtract(const Duration(days: 13, hours: 8)),
      ),
      CheckinsCompanion.insert(
        id: 'checkin-clara-4',
        profileId: 'clara',
        beerId: 'beer-stiegl-goldbraeu',
        rating: const Value(3.0),
        note: const Value('Solide, aber haut mich nicht vom Hocker.'),
        flavorTags: const Value('süffig,malzig'),
        createdAt: now.subtract(const Duration(days: 14, hours: 1)),
      ),
    ]);

    // ------------------------------------------------------------------------
    // Toasts
    // ------------------------------------------------------------------------
    b.insertAll(db.toasts, [
      ToastsCompanion.insert(checkinId: 'checkin-anna-1', profileId: 'ben'),
      ToastsCompanion.insert(checkinId: 'checkin-anna-2', profileId: 'clara'),
      ToastsCompanion.insert(checkinId: 'checkin-ben-1', profileId: 'anna'),
      ToastsCompanion.insert(checkinId: 'checkin-ben-2', profileId: 'clara'),
    ]);

    // ------------------------------------------------------------------------
    // Kommentare
    // ------------------------------------------------------------------------
    b.insertAll(db.comments, [
      CommentsCompanion.insert(
        id: 'comment-1',
        checkinId: 'checkin-anna-1',
        profileId: 'ben',
        body: 'Bin gleich da, bestell mir schon mal eins mit! 🍺',
        createdAt: now.subtract(const Duration(minutes: 25)),
      ),
      CommentsCompanion.insert(
        id: 'comment-2',
        checkinId: 'checkin-ben-1',
        profileId: 'clara',
        body: 'Das war wirklich ein großartiger Abschluss des Abends.',
        createdAt: now.subtract(const Duration(hours: 23, minutes: 30)),
      ),
      CommentsCompanion.insert(
        id: 'comment-3',
        checkinId: 'checkin-ben-2',
        profileId: 'anna',
        body: 'Rauchbier muss ich auch endlich mal probieren!',
        createdAt: now.subtract(const Duration(days: 2, hours: 3)),
      ),
    ]);
  });
}
