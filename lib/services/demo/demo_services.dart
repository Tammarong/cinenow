import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/utils/app_exceptions.dart';
import '../../models/booking_draft.dart';
import '../../models/catalog.dart';
import '../../models/cinema.dart';
import '../../models/movie.dart';
import '../../models/reservation.dart';
import '../../models/seat_layout.dart';
import '../../models/showtime.dart';
import '../../models/user_profile.dart';
import '../seed/showtime_generator.dart';
import '../services.dart';
import 'demo_store.dart';

/// Loads `assets/seed/catalog.json` — the same content that seeds Firebase.
class DemoCatalogService implements CatalogService {
  DemoCatalogService(this._store);

  final DemoStore _store;
  Future<Catalog>? _catalog;

  Future<Catalog> get catalog => _catalog ??= rootBundle
      .loadString('assets/seed/catalog.json')
      .then((raw) => Catalog.fromJson(jsonDecode(raw) as Map<String, dynamic>));

  // A short pause so loading states are visible and feel natural.
  Future<void> _latency() => Future.delayed(const Duration(milliseconds: 450));

  @override
  Future<CatalogConfig> fetchConfig() async => (await catalog).config;

  @override
  Future<List<Movie>> fetchMovies() async {
    await _latency();
    return (await catalog).movies.values.toList();
  }

  @override
  Future<List<Cinema>> fetchCinemas() async => (await catalog).cinemas.values.toList();

  @override
  Future<Map<String, SeatLayout>> fetchLayouts() async => (await catalog).layouts;

  @override
  Future<List<Showtime>> fetchShowtimes(String movieId, {required String fromDate, required String toDate}) async {
    await _latency();
    final from = DateTime.parse(fromDate);
    final to = DateTime.parse(toDate);
    final days = to.difference(from).inDays + 1;
    return ShowtimeGenerator(await catalog).forRange(from, days, movieId: movieId);
  }

  Future<Set<String>> _occupied(String showtimeId) async {
    final c = await catalog;
    final parts = showtimeId.split('_');
    final booked = _store.bookedSeats(showtimeId);
    if (parts.length != 4) return booked;
    final date = DateTime.tryParse(
      '${parts[2].substring(0, 4)}-${parts[2].substring(4, 6)}-${parts[2].substring(6, 8)}',
    );
    if (date == null) return booked;
    final generator = ShowtimeGenerator(c);
    final matches = generator.forDay(date, movieId: parts[1]).where((s) => s.id == showtimeId);
    return {if (matches.isNotEmpty) ...generator.presoldSeats(matches.first), ...booked};
  }

  @override
  Stream<Set<String>> watchOccupiedSeats(String showtimeId) async* {
    yield await _occupied(showtimeId);
    await for (final _ in _store.changes) {
      yield await _occupied(showtimeId);
    }
  }

  Future<Set<String>> occupiedNow(String showtimeId) => _occupied(showtimeId);
}

/// Simulated sign-in. Accounts are remembered on this device only and
/// passwords are not stored or checked — the UI says so clearly.
class DemoAuthService implements AuthService {
  DemoAuthService(this._store);

  final DemoStore _store;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _store.session;
    await for (final _ in _store.changes) {
      yield _store.session;
    }
  }

  @override
  AppUser? get currentUser => _store.session;

  @override
  Future<AppUser> signIn({required String email, required String password}) async {
    await Future.delayed(const Duration(milliseconds: 700));
    final account = _store.accountFor(email.trim());
    if (account == null) {
      throw const AppException(
        'No demo account for this email on this device yet. Create one in a few seconds.',
        code: 'user-not-found',
      );
    }
    await _store.setSession(account);
    return account;
  }

  @override
  Future<AppUser> signUp({required String name, required String email, required String password, String? city}) async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (_store.accountFor(email.trim()) != null) {
      throw AppException(friendlyAuthMessage('email-already-in-use'), code: 'email-already-in-use');
    }
    final uid = 'demo-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${Random().nextInt(999)}';
    final user = AppUser(uid: uid, email: email.trim().toLowerCase(), displayName: name.trim());
    await _store.saveAccount(user);
    await _store.saveProfile(
      UserProfile(uid: uid, displayName: name.trim(), email: user.email, createdAt: DateTime.now(), city: city),
    );
    await _store.setSession(user);
    return user;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await Future.delayed(const Duration(milliseconds: 600));
  }

  @override
  Future<void> updateDisplayName(String name) async {
    final user = _store.session;
    if (user == null) return;
    final updated = AppUser(uid: user.uid, email: user.email, displayName: name.trim());
    await _store.saveAccount(updated);
    await _store.setSession(updated);
  }

  @override
  Future<void> signOut() => _store.setSession(null);
}

class DemoProfileService implements ProfileService {
  DemoProfileService(this._store);

  final DemoStore _store;

  @override
  Stream<UserProfile?> watchProfile(String uid) async* {
    yield _store.profile(uid);
    await for (final _ in _store.changes) {
      yield _store.profile(uid);
    }
  }

  @override
  Future<void> saveProfile(UserProfile profile) => _store.saveProfile(profile);

  @override
  Future<void> updateProfile(String uid, {String? displayName, String? city}) async {
    final current = _store.profile(uid);
    if (current == null) return;
    await _store.saveProfile(
      UserProfile(
        uid: uid,
        displayName: displayName?.trim() ?? current.displayName,
        email: current.email,
        createdAt: current.createdAt,
        city: city ?? current.city,
      ),
    );
  }
}

class DemoReservationService implements ReservationService {
  DemoReservationService(this._store, this._catalog);

  final DemoStore _store;
  final DemoCatalogService _catalog;

  @override
  Stream<List<Reservation>> watchReservations(String uid) async* {
    List<Reservation> sorted() => _store.reservations(uid)..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    yield sorted();
    await for (final _ in _store.changes) {
      yield sorted();
    }
  }

  @override
  Future<Reservation> confirm({
    required AppUser user,
    required BookingDraft draft,
    required PriceBreakdown price,
  }) async {
    await Future.delayed(const Duration(milliseconds: 900));
    final occupied = await _catalog.occupiedNow(draft.showtime!.id);
    final taken = draft.seats.where(occupied.contains).toList();
    if (taken.isNotEmpty) throw SeatConflictException(taken);
    final reservation = buildReservation(
      id: 'demo-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
      ref: generateBookingRef(),
      draft: draft,
      price: price,
      createdAt: DateTime.now(),
      isDemo: true,
    );
    await _store.addReservation(user.uid, reservation);
    return reservation;
  }
}
