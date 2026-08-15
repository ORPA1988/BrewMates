import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers.dart';

import '../features/account/account_screen.dart';
import '../features/admin/admin_screen.dart';
import '../features/admin/challenge_editor_screen.dart';
import '../features/beers/add_beer_screen.dart';
import '../features/beers/beer_edit_screen.dart';
import '../features/beers/brewery_edit_screen.dart';
import '../features/venues/venue_edit_screen.dart';
import '../features/discover/discover_screen.dart';
import '../features/venues/venues_list_screen.dart';
import '../features/beers/beer_detail_screen.dart';
import '../features/beers/brewery_detail_screen.dart';
import '../features/checkin/checkin_screen.dart';
import '../features/crews/crew_detail_screen.dart';
import '../features/crews/crews_screen.dart';
import '../features/feed/feed_screen.dart';
import '../features/friends/friends_screen.dart';
import '../features/friends/qr_scan_screen.dart';
import '../features/friends/qr_share_screen.dart';
import '../features/home/home_screen.dart';
import '../features/map/map_screen.dart';
import '../features/profile/badges_screen.dart';
import '../features/profile/challenges_screen.dart';
import '../features/profile/leaderboard_screen.dart';
import '../features/profile/diary_screen.dart';
import '../features/stats/stats_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/wishlist_screen.dart';
import '../features/scan/scan_screen.dart';
import '../features/session/beacon_screen.dart';
import '../features/session/session_detail_screen.dart';
import '../features/session/start_session_screen.dart';
import '../features/shell/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Meldet Auth-Änderungen an den Router, damit das Anmelde-Gate
  // sofort greift bzw. sich sofort öffnet.
  final refresh = ValueNotifier(0);
  ref.onDispose(refresh.dispose);
  ref.listen(onlineServiceProvider, (_, __) => refresh.value++);
  ref.listen(onlineUserProvider, (_, __) => refresh.value++);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    // Konto-Pflicht (Beta): Ist der Online-Modus konfiguriert und niemand
    // angemeldet, führt jeder Weg zuerst zum Konto-Screen. Einmal
    // anmelden genügt – die Sitzung bleibt dauerhaft bestehen.
    redirect: (context, state) {
      final online = ref.read(onlineServiceProvider);
      final user = ref.read(onlineUserProvider);
      final configured = online.valueOrNull != null;
      final resolved = online.hasValue && (user.hasValue || user.hasError);
      final signedIn = user.valueOrNull != null;
      if (configured && resolved && !signedIn) {
        return state.matchedLocation == '/account' ? null : '/account';
      }
      return null;
    },
    routes: [
      // Haupt-Tabs innerhalb der adaptiven Shell
      // (Tab-Bar auf Mobilgeräten, Navigation-Rail auf Windows/Desktop).
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/feed', builder: (_, __) => const FeedScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/map', builder: (_, __) => const MapScreen()),
          ]),
          StatefulShellBranch(routes: [
            // Entdecken: seit 2026-08-15 Biere, Brauereien UND
            // Gasthaeuser an einer Stelle. Die Gasthausliste war vorher
            // ein eigener Bildschirm hinter einem Knopf auf der Karte —
            // man musste wissen, dass es sie gibt.
            GoRoute(
                path: '/beers', builder: (_, __) => const DiscoverScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/profile', builder: (_, __) => const ProfileScreen()),
          ]),
        ],
      ),
      // Hero-Aktionen
      GoRoute(
        path: '/scan',
        builder: (_, __) => const ScanScreen(),
      ),
      GoRoute(
        path: '/beacon',
        builder: (_, __) => const BeaconScreen(),
      ),
      // Flows und Detailseiten außerhalb der Shell
      GoRoute(
        path: '/session/start',
        builder: (_, __) => const StartSessionScreen(),
      ),
      GoRoute(
        path: '/session/:id',
        builder: (_, state) =>
            SessionDetailScreen(sessionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/checkin',
        builder: (_, state) => CheckinScreen(
          preselectedBeerId: state.uri.queryParameters['beer'],
          // Nach einem Scan bekannt: Der Barcode sagt die Gebindegröße.
          preselectedVolumeMl:
              int.tryParse(state.uri.queryParameters['ml'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/beer/:id',
        builder: (_, state) =>
            BeerDetailScreen(beerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/beer/:id/edit',
        builder: (_, state) =>
            BeerEditScreen(beerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/brewery/:id/edit',
        builder: (_, state) =>
            BreweryEditScreen(breweryId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/beers/add',
        builder: (_, state) => AddBeerScreen(
          initialBarcode: state.uri.queryParameters['ean'],
          initialName: state.uri.queryParameters['name'],
          initialBrewery: state.uri.queryParameters['brewery'],
        ),
      ),
      GoRoute(
        path: '/brewery/:id',
        builder: (_, state) =>
            BreweryDetailScreen(breweryId: state.pathParameters['id']!),
      ),
      // Gasthäuser (gemeinsame Datenbank)
      GoRoute(
        path: '/venues',
        builder: (_, __) => const VenuesListScreen(),
      ),
      GoRoute(
        path: '/venues/add',
        builder: (_, state) => VenueEditScreen(
          initialName: state.uri.queryParameters['name'],
        ),
      ),
      GoRoute(
        path: '/venue/:id/edit',
        builder: (_, state) =>
            VenueEditScreen(venueId: state.pathParameters['id']!),
      ),
      // Online-Beta
      GoRoute(
        path: '/account',
        builder: (_, __) => const AccountScreen(),
      ),
      GoRoute(
        path: '/friends',
        builder: (_, __) => const FriendsScreen(),
      ),
      GoRoute(
        path: '/friends/code',
        builder: (_, __) => const QrShareScreen(),
      ),
      GoRoute(
        path: '/friends/scan',
        builder: (_, __) => const QrScanScreen(),
      ),
      GoRoute(
        path: '/crews',
        builder: (_, __) => const CrewsScreen(),
      ),
      GoRoute(
        path: '/crew/:id',
        builder: (_, state) =>
            CrewDetailScreen(crewId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/admin',
        builder: (_, __) => const AdminScreen(),
      ),
      GoRoute(
        path: '/profile/badges',
        builder: (_, __) => const BadgesScreen(),
      ),
      GoRoute(
        path: '/profile/challenges',
        builder: (_, __) => const ChallengesScreen(),
      ),
      GoRoute(
        path: '/profile/leaderboard',
        builder: (_, __) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: '/admin/challenges',
        builder: (_, __) => const ChallengeEditorScreen(),
      ),
      GoRoute(
        path: '/profile/diary',
        builder: (_, __) => const DiaryScreen(),
      ),
      GoRoute(
        path: '/profile/wishlist',
        builder: (_, __) => const WishlistScreen(),
      ),
      GoRoute(
        path: '/profile/stats',
        builder: (_, __) => const StatsScreen(),
      ),
    ],
  );
});
