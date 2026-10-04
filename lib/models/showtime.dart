import 'json.dart';

class Showtime {
  const Showtime({
    required this.id,
    required this.movieId,
    required this.cinemaId,
    required this.hallId,
    required this.hallName,
    required this.format,
    required this.layoutId,
    required this.date,
    required this.time,
    required this.startsAt,
    required this.priceStandard,
    required this.priceDeluxe,
    this.soldOut = false,
  });

  /// `{cinemaId}_{movieId}_{yyyyMMdd}_{HHmm}` — also the key under `occupiedSeats`.
  final String id;
  final String movieId;
  final String cinemaId;
  final String hallId;
  final String hallName;
  final String format;
  final String layoutId;

  /// Local cinema date, `yyyy-MM-dd`.
  final String date;

  /// Local cinema time, `HH:mm`.
  final String time;

  /// Absolute start time (UTC epoch) — used for "already started" checks.
  final DateTime startsAt;
  final int priceStandard;
  final int priceDeluxe;
  final bool soldOut;

  bool hasStarted([DateTime? now]) => !startsAt.isAfter(now ?? DateTime.now());
  bool isBookable([DateTime? now]) => !soldOut && !hasStarted(now);

  factory Showtime.fromMap(String id, Map<String, dynamic> map) => Showtime(
    id: id,
    movieId: asString(map['movieId']),
    cinemaId: asString(map['cinemaId']),
    hallId: asString(map['hallId']),
    hallName: asString(map['hallName'], 'Hall'),
    format: asString(map['format'], '2D'),
    layoutId: asString(map['layoutId'], 'classic'),
    date: asString(map['date']),
    time: asString(map['time']),
    startsAt: DateTime.fromMillisecondsSinceEpoch(asInt(map['startsAt']), isUtc: true).toLocal(),
    priceStandard: asInt(map['priceStandard'], 220),
    priceDeluxe: asInt(map['priceDeluxe'], 320),
    soldOut: asBool(map['soldOut']),
  );

  Map<String, dynamic> toMap() => {
    'movieId': movieId,
    'cinemaId': cinemaId,
    'hallId': hallId,
    'hallName': hallName,
    'format': format,
    'layoutId': layoutId,
    'date': date,
    'time': time,
    'startsAt': startsAt.millisecondsSinceEpoch,
    'priceStandard': priceStandard,
    'priceDeluxe': priceDeluxe,
    if (soldOut) 'soldOut': true,
  };

  @override
  bool operator ==(Object other) => other is Showtime && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
