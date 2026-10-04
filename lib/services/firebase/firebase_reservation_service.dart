import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../core/utils/app_exceptions.dart';
import '../../models/booking_draft.dart';
import '../../models/json.dart';
import '../../models/reservation.dart';
import '../../models/user_profile.dart';
import '../services.dart';

class FirebaseReservationService implements ReservationService {
  FirebaseReservationService(this._db);

  final FirebaseDatabase _db;

  @override
  Stream<List<Reservation>> watchReservations(String uid) => _db.ref('reservations/$uid').onValue.map((event) {
    final map = asMap(event.snapshot.value);
    final list = [for (final e in map.entries) Reservation.fromMap(e.key, asMap(e.value))];
    list.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return list;
  });

  /// Books all seats and the reservation in ONE atomic multi-path update.
  ///
  /// Security rules reject a seat write if the seat already exists, which
  /// makes Firebase reject the whole update — so either every seat and the
  /// reservation are saved together, or nothing is.
  @override
  Future<Reservation> confirm({
    required AppUser user,
    required BookingDraft draft,
    required PriceBreakdown price,
  }) async {
    final showtime = draft.showtime!;
    final resRef = _db.ref('reservations/${user.uid}').push();
    final id = resRef.key!;
    final reservation = buildReservation(
      id: id,
      ref: generateBookingRef(),
      draft: draft,
      price: price,
      createdAt: DateTime.now(),
    );

    final updates = <String, Object?>{
      'reservations/${user.uid}/$id': reservation.toMap(createdAtOverride: ServerValue.timestamp),
      for (final seat in draft.seats)
        'occupiedSeats/${showtime.id}/$seat': {'uid': user.uid, 'reservationId': id, 'bookedAt': ServerValue.timestamp},
    };

    try {
      await _db.ref().update(updates).timeout(const Duration(seconds: 20));
      return reservation;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        final taken = await _takenSeats(showtime.id, draft.seats);
        if (taken.isNotEmpty) throw SeatConflictException(taken);
        throw const AppException(
          'Your reservation couldn\'t be saved. Please sign in again and retry.',
          code: 'permission-denied',
        );
      }
      throw AppException('Your reservation couldn\'t be saved (${e.code}). Please try again.', code: e.code);
    } on TimeoutException {
      throw const AppException(
        'The connection is too slow to confirm right now. Check My Tickets in a moment before trying again.',
        code: 'timeout',
      );
    }
  }

  Future<List<String>> _takenSeats(String showtimeId, List<String> seats) async {
    try {
      final snap = await _db.ref('occupiedSeats/$showtimeId').get();
      final occupied = asMap(snap.value).keys.toSet();
      return seats.where(occupied.contains).toList();
    } catch (_) {
      return const [];
    }
  }
}
