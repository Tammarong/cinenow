import 'package:cinenow/core/utils/app_exceptions.dart';
import 'package:cinenow/models/booking_draft.dart';
import 'package:cinenow/services/demo/demo_services.dart';
import 'package:cinenow/services/demo/demo_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DemoStore store;
  late DemoCatalogService catalog;
  late DemoAuthService auth;
  late DemoReservationService reservations;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = DemoStore(await SharedPreferences.getInstance());
    catalog = DemoCatalogService(store);
    auth = DemoAuthService(store);
    reservations = DemoReservationService(store, catalog);
  });

  Future<BookingDraft> draftFor(List<String> seats) async {
    final c = await catalog.catalog;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final from =
        '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
    final shows = await catalog.fetchShowtimes('interstellar', fromDate: from, toDate: from);
    final show = shows.first;
    return BookingDraft(
      movie: c.movies['interstellar'],
      cinema: c.cinemas[show.cinemaId],
      showtime: show,
      layout: c.layouts[show.layoutId],
      seats: seats,
    );
  }

  test('demo sign-up, booking, and ticket list stay on the device', () async {
    final user = await auth.signUp(name: 'Demo Viewer', email: 'demo@cinenow.test', password: 'Popcorn2026');
    expect(auth.currentUser?.uid, user.uid);

    final draft = await draftFor(const ['A1', 'A2']);
    final occupied = await catalog.occupiedNow(draft.showtime!.id);
    final free = draft.layout!.allSeatIds.where((s) => !occupied.contains(s)).take(2).toList();
    final booking = BookingDraft(
      movie: draft.movie,
      cinema: draft.cinema,
      showtime: draft.showtime,
      layout: draft.layout,
      seats: free,
    );

    final res = await reservations.confirm(user: user, draft: booking, price: booking.price(bookingFeePerTicket: 10));
    expect(res.isDemo, isTrue);
    expect(res.seats, free);

    final mine = await reservations.watchReservations(user.uid).first;
    expect(mine.single.ref, res.ref);
    expect(await catalog.occupiedNow(booking.showtime!.id), containsAll(free));

    // Booking the same seats again is a conflict, not a silent double-booking.
    await expectLater(
      reservations.confirm(user: user, draft: booking, price: booking.price(bookingFeePerTicket: 10)),
      throwsA(isA<SeatConflictException>()),
    );
  });
}
