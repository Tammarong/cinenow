import 'package:animations/animations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/reservation.dart';
import '../../screens/auth/auth_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/booking/confirmation_screen.dart';
import '../../screens/booking/review_screen.dart';
import '../../screens/booking/seat_selection_screen.dart';
import '../../screens/booking/showtimes_screen.dart';
import '../../screens/explore/explore_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/movie_details/movie_details_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/shell/main_shell.dart';
import '../../screens/tickets/my_tickets_screen.dart';
import '../../screens/tickets/ticket_detail_screen.dart';
import '../../screens/welcome/welcome_screen.dart';
import '../../state/preferences.dart';
import '../theme/app_colors.dart';

abstract final class Routes {
  static const welcome = '/welcome';
  static const home = '/home';
  static const explore = '/explore';
  static const tickets = '/tickets';
  static const profile = '/profile';
  static const auth = '/auth';
  static const forgotPassword = '/forgot-password';
  static const seats = '/book/seats';
  static const review = '/book/review';
  static const confirmation = '/book/confirmation';

  static String movie(String id) => '/movie/$id';
  static String showtimes(String movieId) => '/book/$movieId/showtimes';
  static String ticket(String id) => '/ticket/$id';
  static String signIn({bool forBooking = false}) => '$auth?mode=signin${forBooking ? '&reason=booking' : ''}';
  static String signUp({bool forBooking = false}) => '$auth?mode=signup${forBooking ? '&reason=booking' : ''}';
  static String exploreWith({String? genre, bool focusSearch = false}) =>
      Uri(path: explore, queryParameters: {'genre': ?genre, if (focusSearch) 'focus': '1'}).toString();
}

enum _Transition { sharedAxis, fadeThrough, vertical }

CustomTransitionPage<T> _page<T>(GoRouterState state, Widget child, [_Transition type = _Transition.sharedAxis]) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondary, child) => switch (type) {
      _Transition.sharedAxis => SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondary,
        transitionType: SharedAxisTransitionType.horizontal,
        fillColor: AppColors.background,
        child: child,
      ),
      _Transition.fadeThrough => FadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondary,
        fillColor: AppColors.background,
        child: child,
      ),
      _Transition.vertical => SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondary,
        transitionType: SharedAxisTransitionType.vertical,
        fillColor: AppColors.background,
        child: child,
      ),
    },
  );
}

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.home,
    redirect: (context, state) {
      final seen = ref.read(welcomeSeenProvider);
      if (!seen && state.matchedLocation == Routes.home && state.uri.queryParameters.isEmpty) {
        return Routes.welcome;
      }
      return null;
    },
    routes: [
      GoRoute(path: Routes.welcome, pageBuilder: (c, s) => _page(s, const WelcomeScreen(), _Transition.fadeThrough)),
      GoRoute(
        path: Routes.auth,
        pageBuilder: (c, s) => _page<bool>(
          s,
          AuthScreen(
            startWithSignUp: s.uri.queryParameters['mode'] == 'signup',
            forBooking: s.uri.queryParameters['reason'] == 'booking',
          ),
          _Transition.vertical,
        ),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        pageBuilder: (c, s) => _page(s, ForgotPasswordScreen(initialEmail: s.uri.queryParameters['email'])),
      ),
      StatefulShellRoute(
        builder: (context, state, shell) => MainShell(shell: shell),
        navigatorContainerBuilder: (context, shell, children) =>
            FadeIndexedStack(index: shell.currentIndex, children: children),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                pageBuilder: (c, s) => NoTransitionPage(key: s.pageKey, child: const HomeScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.explore,
                pageBuilder: (c, s) => NoTransitionPage(
                  key: s.pageKey,
                  child: ExploreScreen(
                    initialGenre: s.uri.queryParameters['genre'],
                    focusSearch: s.uri.queryParameters['focus'] == '1',
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.tickets,
                pageBuilder: (c, s) => NoTransitionPage(key: s.pageKey, child: const MyTicketsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                pageBuilder: (c, s) => NoTransitionPage(key: s.pageKey, child: const ProfileScreen()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/movie/:id',
        pageBuilder: (c, s) => _page(
          s,
          MovieDetailsScreen(movieId: s.pathParameters['id']!, heroPrefix: s.uri.queryParameters['hero'] ?? 'card'),
          _Transition.fadeThrough,
        ),
      ),
      GoRoute(
        path: '/book/:movieId/showtimes',
        pageBuilder: (c, s) => _page(s, ShowtimesScreen(movieId: s.pathParameters['movieId']!)),
      ),
      GoRoute(path: Routes.seats, pageBuilder: (c, s) => _page(s, const SeatSelectionScreen())),
      GoRoute(path: Routes.review, pageBuilder: (c, s) => _page(s, const ReviewScreen())),
      GoRoute(
        path: Routes.confirmation,
        pageBuilder: (c, s) =>
            _page(s, ConfirmationScreen(reservation: s.extra as Reservation?), _Transition.fadeThrough),
      ),
      GoRoute(
        path: '/ticket/:id',
        pageBuilder: (c, s) =>
            _page(s, TicketDetailScreen(reservationId: s.pathParameters['id']!, initial: s.extra as Reservation?)),
      ),
    ],
  );
});
