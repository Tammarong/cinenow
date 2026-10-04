import 'cinema.dart';
import 'movie.dart';
import 'seat_layout.dart';
import 'showtime.dart';

/// Everything the user has picked so far. Lives in memory only — seats are
/// never written to the database until the user confirms.
class BookingDraft {
  const BookingDraft({this.movie, this.date, this.cinema, this.showtime, this.layout, this.seats = const []});

  final Movie? movie;
  final DateTime? date;
  final Cinema? cinema;
  final Showtime? showtime;
  final SeatLayout? layout;

  /// Selected seat ids in the order they were picked.
  final List<String> seats;

  bool get hasShowtime => movie != null && cinema != null && showtime != null;
  bool get isReadyForReview => hasShowtime && layout != null && seats.isNotEmpty;

  BookingDraft copyWith({
    Movie? movie,
    DateTime? date,
    Cinema? cinema,
    Showtime? showtime,
    SeatLayout? layout,
    List<String>? seats,
    bool clearShowtime = false,
  }) => BookingDraft(
    movie: movie ?? this.movie,
    date: date ?? this.date,
    cinema: clearShowtime ? null : (cinema ?? this.cinema),
    showtime: clearShowtime ? null : (showtime ?? this.showtime),
    layout: clearShowtime ? null : (layout ?? this.layout),
    seats: seats ?? this.seats,
  );

  PriceBreakdown price({required int bookingFeePerTicket}) {
    final layout = this.layout;
    final showtime = this.showtime;
    if (layout == null || showtime == null) return PriceBreakdown.empty;
    var standard = 0;
    var deluxe = 0;
    for (final s in seats) {
      layout.typeOf(s) == SeatType.deluxe ? deluxe++ : standard++;
    }
    return PriceBreakdown(
      standardCount: standard,
      deluxeCount: deluxe,
      priceStandard: showtime.priceStandard,
      priceDeluxe: showtime.priceDeluxe,
      bookingFeePerTicket: bookingFeePerTicket,
    );
  }
}

class PriceBreakdown {
  const PriceBreakdown({
    required this.standardCount,
    required this.deluxeCount,
    required this.priceStandard,
    required this.priceDeluxe,
    required this.bookingFeePerTicket,
  });

  static const empty = PriceBreakdown(
    standardCount: 0,
    deluxeCount: 0,
    priceStandard: 0,
    priceDeluxe: 0,
    bookingFeePerTicket: 0,
  );

  final int standardCount;
  final int deluxeCount;
  final int priceStandard;
  final int priceDeluxe;
  final int bookingFeePerTicket;

  int get tickets => standardCount + deluxeCount;
  int get standardSubtotal => standardCount * priceStandard;
  int get deluxeSubtotal => deluxeCount * priceDeluxe;
  int get ticketsSubtotal => standardSubtotal + deluxeSubtotal;
  int get bookingFee => tickets * bookingFeePerTicket;
  int get total => ticketsSubtotal + bookingFee;
}
