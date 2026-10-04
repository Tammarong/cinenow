import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/booking_draft.dart';
import '../models/cinema.dart';
import '../models/movie.dart';
import '../models/seat_layout.dart';
import '../models/showtime.dart';

enum SeatToggle { selected, deselected, occupied, limitReached }

/// Holds the in-progress booking. Kept alive for the whole session, so the
/// selection survives going back, switching tabs, and signing in mid-flow.
class BookingController extends Notifier<BookingDraft> {
  @override
  BookingDraft build() => const BookingDraft();

  /// Starts (or resumes) a booking for [movie]. Re-entering the same movie
  /// keeps the previous selection.
  void startFor(Movie movie) {
    if (state.movie?.id == movie.id) return;
    state = BookingDraft(movie: movie);
  }

  void selectDate(DateTime date) {
    if (state.date != null && _sameDay(state.date!, date)) return;
    state = BookingDraft(movie: state.movie, date: date);
  }

  void selectShowtime(Cinema cinema, Showtime showtime, SeatLayout? layout) {
    if (state.showtime?.id == showtime.id) {
      if (layout != null && state.layout == null) state = state.copyWith(layout: layout);
      return;
    }
    state = BookingDraft(movie: state.movie, date: state.date, cinema: cinema, showtime: showtime, layout: layout);
  }

  void setLayout(SeatLayout layout) {
    if (state.layout?.id != layout.id) state = state.copyWith(layout: layout);
  }

  SeatToggle toggleSeat(String seatId, {required Set<String> occupied, required int maxSeats}) {
    final seats = [...state.seats];
    if (seats.contains(seatId)) {
      seats.remove(seatId);
      state = state.copyWith(seats: seats);
      return SeatToggle.deselected;
    }
    if (occupied.contains(seatId)) return SeatToggle.occupied;
    if (seats.length >= maxSeats) return SeatToggle.limitReached;
    state = state.copyWith(seats: [...seats, seatId]);
    return SeatToggle.selected;
  }

  /// Drops seats that someone else has just booked. Returns those removed.
  List<String> releaseTaken(Set<String> occupied) {
    final taken = state.seats.where(occupied.contains).toList();
    if (taken.isNotEmpty) {
      state = state.copyWith(seats: state.seats.where((s) => !occupied.contains(s)).toList());
    }
    return taken;
  }

  void clearSeats() => state = state.copyWith(seats: const []);

  void reset() => state = const BookingDraft();

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

final bookingProvider = NotifierProvider<BookingController, BookingDraft>(BookingController.new);
