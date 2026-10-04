import 'dart:convert';
import 'dart:io';

import 'package:cinenow/core/config/backend_mode.dart';
import 'package:cinenow/core/theme/app_theme.dart';
import 'package:cinenow/models/booking_draft.dart';
import 'package:cinenow/models/catalog.dart';
import 'package:cinenow/models/movie.dart';
import 'package:cinenow/models/user_profile.dart';
import 'package:cinenow/screens/booking/review_screen.dart';
import 'package:cinenow/screens/explore/explore_screen.dart';
import 'package:cinenow/services/seed/showtime_generator.dart';
import 'package:cinenow/state/booking_controller.dart';
import 'package:cinenow/state/providers.dart';
import 'package:cinenow/widgets/seat_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

Catalog loadCatalog() =>
    Catalog.fromJson(jsonDecode(File('assets/seed/catalog.json').readAsStringSync()) as Map<String, dynamic>);

/// Same movies, minus network images (tests have no network).
List<Movie> offlineMovies(Catalog c) => [
  for (final m in c.movies.values)
    Movie.fromMap(m.id, {...m.toMap(), 'posterUrl': '', 'backdropUrl': '', 'cast': const []}),
];

class _PresetBooking extends BookingController {
  _PresetBooking(this.initial);
  final BookingDraft initial;

  @override
  BookingDraft build() => initial;
}

Widget wrap(Widget child, {List overrides = const []}) => ProviderScope(
  overrides: [
    backendStatusProvider.overrideWithValue(const BackendStatus(BackendMode.firebase)),
    configProvider.overrideWith((ref) async => const CatalogConfig()),
    isOnlineProvider.overrideWithValue(true),
    ...overrides,
  ],
  child: MaterialApp(theme: AppTheme.dark(), home: child),
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  final catalog = loadCatalog();

  testWidgets('Seat map: tapping seats reports them; states are announced', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: SeatMap(
              layout: catalog.layouts['studio']!,
              occupied: const {'B3'},
              selected: const ['C4'],
              onSeatTap: tapped.add,
              priceStandard: 220,
              priceDeluxe: 320,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp(r'^Seat B3, Standard .*occupied$')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Seat C4, Standard .*selected$')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Seat G1, Deluxe .*available$')), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp(r'^Seat A1,')), warnIfMissed: false);
    expect(tapped, ['A1']);
  });

  testWidgets('Explore: helpful empty state when nothing matches', (tester) async {
    await tester.pumpWidget(
      wrap(const ExploreScreen(), overrides: [moviesProvider.overrideWith((ref) async => offlineMovies(catalog))]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Interstellar'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'zzzz no such film');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('No matches'), findsOneWidget);

    await tester.tap(find.widgetWithText(GestureDetector, 'Clear filters').first);
    await tester.pumpAndSettle();
    expect(find.text('No matches'), findsNothing);
  });

  testWidgets('Review: guests are asked to sign in, signed-in users can confirm', (tester) async {
    final movie = offlineMovies(catalog).firstWhere((m) => m.id == 'dune-part-two');
    final show = ShowtimeGenerator(
      catalog,
    ).forDay(DateTime.now().add(const Duration(days: 2)), movieId: movie.id).first;
    final draft = BookingDraft(
      movie: movie,
      date: DateTime.parse(show.date),
      cinema: catalog.cinemas[show.cinemaId],
      showtime: show,
      layout: catalog.layouts[show.layoutId],
      seats: const ['E7', 'E8'],
    );

    await tester.pumpWidget(
      wrap(
        const ReviewScreen(),
        overrides: [
          bookingProvider.overrideWith(() => _PresetBooking(draft)),
          currentUserProvider.overrideWithValue(null),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign in to confirm'), findsOneWidget);
    expect(find.text('Confirm Reservation'), findsNothing);
    expect(find.textContaining('no payment is taken'), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        const ReviewScreen(),
        overrides: [
          bookingProvider.overrideWith(() => _PresetBooking(draft)),
          currentUserProvider.overrideWithValue(
            const AppUser(uid: 'u1', email: 'alex@example.com', displayName: 'Alex'),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Confirm Reservation'), findsOneWidget);
  });
}
