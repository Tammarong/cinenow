import 'json.dart';

class Reservation {
  const Reservation({
    required this.id,
    required this.ref,
    required this.movieId,
    required this.movieTitle,
    required this.posterUrl,
    required this.backdropUrl,
    required this.cinemaId,
    required this.cinemaName,
    required this.cinemaAddress,
    required this.hallName,
    required this.format,
    required this.showtimeId,
    required this.date,
    required this.time,
    required this.startsAt,
    required this.seats,
    required this.standardCount,
    required this.deluxeCount,
    required this.priceStandard,
    required this.priceDeluxe,
    required this.bookingFee,
    required this.total,
    required this.createdAt,
    this.isDemo = false,
  });

  final String id;

  /// Human-friendly booking reference, e.g. `CN-7K4Q2X`.
  final String ref;
  final String movieId;
  final String movieTitle;
  final String posterUrl;
  final String backdropUrl;
  final String cinemaId;
  final String cinemaName;
  final String cinemaAddress;
  final String hallName;
  final String format;
  final String showtimeId;
  final String date;
  final String time;
  final DateTime startsAt;
  final List<String> seats;
  final int standardCount;
  final int deluxeCount;
  final int priceStandard;
  final int priceDeluxe;
  final int bookingFee;
  final int total;
  final DateTime createdAt;

  /// True when stored on this device only (demo mode).
  final bool isDemo;

  /// A ticket stays "upcoming" until 3 hours after the start time.
  bool isUpcoming([DateTime? now]) => startsAt.add(const Duration(hours: 3)).isAfter(now ?? DateTime.now());

  factory Reservation.fromMap(String id, Map<String, dynamic> map, {bool isDemo = false}) {
    final seatsValue = map['seats'];
    final seats = seatsValue is Map ? asMap(seatsValue).keys.toList() : asStringList(seatsValue);
    return Reservation(
      id: id,
      ref: asString(map['ref'], id),
      movieId: asString(map['movieId']),
      movieTitle: asString(map['movieTitle']),
      posterUrl: asString(map['posterUrl']),
      backdropUrl: asString(map['backdropUrl']),
      cinemaId: asString(map['cinemaId']),
      cinemaName: asString(map['cinemaName']),
      cinemaAddress: asString(map['cinemaAddress']),
      hallName: asString(map['hallName']),
      format: asString(map['format'], '2D'),
      showtimeId: asString(map['showtimeId']),
      date: asString(map['date']),
      time: asString(map['time']),
      startsAt: DateTime.fromMillisecondsSinceEpoch(asInt(map['startsAt']), isUtc: true).toLocal(),
      seats: _sorted(seats),
      standardCount: asInt(map['standardCount']),
      deluxeCount: asInt(map['deluxeCount']),
      priceStandard: asInt(map['priceStandard']),
      priceDeluxe: asInt(map['priceDeluxe']),
      bookingFee: asInt(map['bookingFee']),
      total: asInt(map['total']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(asInt(map['createdAt']), isUtc: true).toLocal(),
      isDemo: isDemo,
    );
  }

  /// Database shape. Seats are stored as a map (`{"E7": true}`) so security
  /// rules can check that each occupied seat belongs to this reservation.
  Map<String, dynamic> toMap({Object? createdAtOverride}) => {
    'ref': ref,
    'movieId': movieId,
    'movieTitle': movieTitle,
    'posterUrl': posterUrl,
    'backdropUrl': backdropUrl,
    'cinemaId': cinemaId,
    'cinemaName': cinemaName,
    'cinemaAddress': cinemaAddress,
    'hallName': hallName,
    'format': format,
    'showtimeId': showtimeId,
    'date': date,
    'time': time,
    'startsAt': startsAt.millisecondsSinceEpoch,
    'seats': {for (final s in seats) s: true},
    'standardCount': standardCount,
    'deluxeCount': deluxeCount,
    'priceStandard': priceStandard,
    'priceDeluxe': priceDeluxe,
    'bookingFee': bookingFee,
    'total': total,
    'createdAt': createdAtOverride ?? createdAt.millisecondsSinceEpoch,
  };

  static List<String> _sorted(List<String> seats) {
    final list = [...seats];
    list.sort((a, b) {
      final r = a.substring(0, 1).compareTo(b.substring(0, 1));
      return r != 0 ? r : (int.tryParse(a.substring(1)) ?? 0).compareTo(int.tryParse(b.substring(1)) ?? 0);
    });
    return list;
  }
}
