// Renders key screens to PNG for visual review (phone size, real fonts).
//
//   flutter test test_screens --update-goldens
//
// Output: test_screens/goldens/*.png. Network images aren't available in
// tests, so posters show their branded fallback artwork.
import 'dart:convert';
import 'dart:io';

import 'package:cinenow/core/config/backend_mode.dart';
import 'package:cinenow/core/theme/app_theme.dart';
import 'package:cinenow/models/booking_draft.dart';
import 'package:cinenow/models/catalog.dart';
import 'package:cinenow/models/movie.dart';
import 'package:cinenow/models/user_profile.dart';
import 'package:cinenow/screens/booking/confirmation_screen.dart';
import 'package:cinenow/screens/booking/review_screen.dart';
import 'package:cinenow/screens/booking/seat_selection_screen.dart';
import 'package:cinenow/screens/explore/explore_screen.dart';
import 'package:cinenow/screens/movie_details/movie_details_screen.dart';
import 'package:cinenow/screens/profile/profile_screen.dart';
import 'package:cinenow/screens/tickets/my_tickets_screen.dart';
import 'package:cinenow/screens/tickets/ticket_detail_screen.dart';
import 'package:cinenow/services/seed/showtime_generator.dart';
import 'package:cinenow/services/services.dart';
import 'package:cinenow/state/booking_controller.dart';
import 'package:cinenow/state/providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

final catalog = Catalog.fromJson(
  jsonDecode(File('assets/seed/catalog.json').readAsStringSync()) as Map<String, dynamic>,
);

final movies = [
  for (final m in catalog.movies.values)
    Movie.fromMap(m.id, {
      ...m.toMap(),
      'posterUrl': '',
      'backdropUrl': '',
      'cast': [
        for (final c in m.cast) {'name': c.name, 'character': c.character},
      ],
    }),
];

class _Preset extends BookingController {
  _Preset(this.initial);
  final BookingDraft initial;
  @override
  BookingDraft build() => initial;
}

const user = AppUser(uid: 'u1', email: 'mali.test@cinenow.test', displayName: 'Mali Test');

Future<void> loadFonts() async {
  final icons = File(
    '${Platform.environment['FLUTTER_ROOT'] ?? 'C:/src/flutter'}'
    '/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  ).readAsBytesSync();
  await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(icons.buffer)))).load();
}

Future<void> shoot(WidgetTester tester, String name, Widget screen, {List overrides = const []}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        backendStatusProvider.overrideWithValue(const BackendStatus(BackendMode.firebase)),
        prefsProvider.overrideWithValue(prefs),
        configProvider.overrideWith((ref) async => const CatalogConfig()),
        isOnlineProvider.overrideWithValue(true),
        moviesProvider.overrideWith((ref) async => movies),
        cinemasProvider.overrideWith((ref) async => catalog.cinemas.values.toList()),
        layoutsProvider.overrideWith((ref) async => catalog.layouts),
        currentUserProvider.overrideWithValue(user),
        ...overrides,
      ],
      child: MaterialApp(debugShowCheckedModeBanner: false, theme: AppTheme.dark(), home: screen),
    ),
  );
  await tester.runAsync(() async {
    await GoogleFonts.pendingFonts();
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadFonts();
  });

  final tomorrow = DateTime.now().add(const Duration(days: 1));
  final show = ShowtimeGenerator(catalog)
      .forDay(DateTime(tomorrow.year, tomorrow.month, tomorrow.day), movieId: 'dune-part-two')
      .firstWhere((s) => s.format == 'IMAX' && s.time == '18:20');
  final dune = movies.firstWhere((m) => m.id == 'dune-part-two');
  final draft = BookingDraft(
    movie: dune,
    date: DateTime.parse(show.date),
    cinema: catalog.cinemas[show.cinemaId],
    showtime: show,
    layout: catalog.layouts[show.layoutId],
    seats: const ['F8', 'F9', 'L6'],
  );
  final presold = ShowtimeGenerator(catalog).presoldSeats(show)..removeAll(draft.seats);
  final reservation = buildReservation(
    id: 'r1',
    ref: 'CN-7K4Q2X',
    draft: draft,
    price: draft.price(bookingFeePerTicket: 10),
    createdAt: DateTime.now(),
  );
  final pastDraft = BookingDraft(
    movie: movies.firstWhere((m) => m.id == 'your-name'),
    cinema: catalog.cinemas['cn-sukhumvit'],
    showtime: ShowtimeGenerator(catalog).forDay(DateTime(2026, 9, 20), movieId: 'your-name').first,
    layout: catalog.layouts['studio'],
    seats: const ['D4', 'D5'],
  );
  final past = buildReservation(
    id: 'r0',
    ref: 'CN-H8PZ3M',
    draft: pastDraft,
    price: pastDraft.price(bookingFeePerTicket: 10),
    createdAt: DateTime(2026, 9, 18),
  );

  testWidgets('movie details', (t) => shoot(t, 'details', const MovieDetailsScreen(movieId: 'dune-part-two')));

  testWidgets('explore', (t) => shoot(t, 'explore', const ExploreScreen()));

  testWidgets(
    'seat selection',
    (t) => shoot(
      t,
      'seats',
      const SeatSelectionScreen(),
      overrides: [
        bookingProvider.overrideWith(() => _Preset(draft)),
        occupiedSeatsProvider(show.id).overrideWith((ref) => Stream.value(presold)),
      ],
    ),
  );

  testWidgets(
    'review',
    (t) => shoot(t, 'review', const ReviewScreen(), overrides: [bookingProvider.overrideWith(() => _Preset(draft))]),
  );

  testWidgets('confirmation', (t) => shoot(t, 'confirmation', ConfirmationScreen(reservation: reservation)));

  testWidgets(
    'my tickets',
    (t) => shoot(
      t,
      'tickets',
      const MyTicketsScreen(),
      overrides: [
        reservationsProvider.overrideWith((ref) => Stream.value([reservation, past])),
      ],
    ),
  );

  testWidgets(
    'ticket detail',
    (t) => shoot(
      t,
      'ticket_detail',
      TicketDetailScreen(reservationId: 'r1', initial: reservation),
      overrides: [
        reservationsProvider.overrideWith((ref) => Stream.value([reservation])),
      ],
    ),
  );

  testWidgets(
    'profile',
    (t) => shoot(
      t,
      'profile',
      const ProfileScreen(),
      overrides: [
        reservationsProvider.overrideWith((ref) => Stream.value([reservation, past])),
        profileProvider.overrideWith(
          (ref) => Stream.value(
            UserProfile(
              uid: 'u1',
              displayName: 'Mali Test',
              email: user.email,
              createdAt: DateTime(2026, 10, 4),
              city: 'Bangkok',
            ),
          ),
        ),
      ],
    ),
  );
}
