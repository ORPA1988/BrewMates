import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/beers/add_beer_screen.dart';
import '../features/beers/beer_detail_screen.dart';
import '../features/beers/beers_screen.dart';
import '../features/checkin/checkin_screen.dart';
import '../features/feed/feed_screen.dart';
import '../features/map/map_screen.dart';
import '../features/profile/badges_screen.dart';
import '../features/profile/diary_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/wishlist_screen.dart';
import '../features/session/session_detail_screen.dart';
import '../features/session/start_session_screen.dart';
import '../features/shell/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/feed',
    routes: [
      // Haupt-Tabs innerhalb der adaptiven Shell
      // (Tab-Bar auf Mobilgeräten, Navigation-Rail auf Windows/Desktop).
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/feed', builder: (_, __) => const FeedScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/map', builder: (_, __) => const MapScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/beers', builder: (_, __) => const BeersScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/profile', builder: (_, __) => const ProfileScreen()),
          ]),
        ],
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
        builder: (_, state) =>
            CheckinScreen(preselectedBeerId: state.uri.queryParameters['beer']),
      ),
      GoRoute(
        path: '/beer/:id',
        builder: (_, state) =>
            BeerDetailScreen(beerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/beers/add',
        builder: (_, __) => const AddBeerScreen(),
      ),
      GoRoute(
        path: '/profile/badges',
        builder: (_, __) => const BadgesScreen(),
      ),
      GoRoute(
        path: '/profile/diary',
        builder: (_, __) => const DiaryScreen(),
      ),
      GoRoute(
        path: '/profile/wishlist',
        builder: (_, __) => const WishlistScreen(),
      ),
    ],
  );
});
