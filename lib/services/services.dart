import 'dart:math';

import '../models/booking_draft.dart';
import '../models/catalog.dart';
import '../models/cinema.dart';
import '../models/movie.dart';
import '../models/reservation.dart';
import '../models/seat_layout.dart';
import '../models/showtime.dart';
import '../models/user_profile.dart';

/// Read-only catalog: movies, cinemas, layouts, showtimes and live seat maps.
abstract interface class CatalogService {
  Future<CatalogConfig> fetchConfig();
  Future<List<Movie>> fetchMovies();
  Future<List<Cinema>> fetchCinemas();
  Future<Map<String, SeatLayout>> fetchLayouts();

  /// Showtimes for [movieId] between two `yyyy-MM-dd` dates (inclusive).
  Future<List<Showtime>> fetchShowtimes(String movieId, {required String fromDate, required String toDate});

  /// Realtime set of occupied seat ids for a showtime.
  Stream<Set<String>> watchOccupiedSeats(String showtimeId);
}

abstract interface class AuthService {
  Stream<AppUser?> authStateChanges();
  AppUser? get currentUser;
  Future<AppUser> signIn({required String email, required String password});
  Future<AppUser> signUp({required String name, required String email, required String password, String? city});
  Future<void> sendPasswordReset(String email);
  Future<void> updateDisplayName(String name);
  Future<void> signOut();
}

abstract interface class ProfileService {
  Stream<UserProfile?> watchProfile(String uid);
  Future<void> saveProfile(UserProfile profile);
  Future<void> updateProfile(String uid, {String? displayName, String? city});
}

abstract interface class ReservationService {
  Stream<List<Reservation>> watchReservations(String uid);

  /// Atomically books every seat in [draft] and stores the reservation.
  /// Throws [SeatConflictException] if any seat was taken in the meantime.
  Future<Reservation> confirm({required AppUser user, required BookingDraft draft, required PriceBreakdown price});
}

/// Short, unambiguous booking reference: CN-XXXXXX (no 0/O/1/I).
String generateBookingRef([Random? random]) {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rng = random ?? Random.secure();
  return 'CN-${List.generate(6, (_) => alphabet[rng.nextInt(alphabet.length)]).join()}';
}

/// Builds the reservation snapshot stored with a booking.
Reservation buildReservation({
  required String id,
  required String ref,
  required BookingDraft draft,
  required PriceBreakdown price,
  required DateTime createdAt,
  bool isDemo = false,
}) {
  final movie = draft.movie!;
  final cinema = draft.cinema!;
  final showtime = draft.showtime!;
  return Reservation(
    id: id,
    ref: ref,
    movieId: movie.id,
    movieTitle: movie.title,
    posterUrl: movie.posterUrl,
    backdropUrl: movie.backdropUrl,
    cinemaId: cinema.id,
    cinemaName: cinema.name,
    cinemaAddress: cinema.address,
    hallName: showtime.hallName,
    format: showtime.format,
    showtimeId: showtime.id,
    date: showtime.date,
    time: showtime.time,
    startsAt: showtime.startsAt,
    seats: [...draft.seats],
    standardCount: price.standardCount,
    deluxeCount: price.deluxeCount,
    priceStandard: price.priceStandard,
    priceDeluxe: price.priceDeluxe,
    bookingFee: price.bookingFee,
    total: price.total,
    createdAt: createdAt,
    isDemo: isDemo,
  );
}
