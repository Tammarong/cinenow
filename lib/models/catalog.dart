import 'cinema.dart';
import 'json.dart';
import 'movie.dart';
import 'seat_layout.dart';

/// App-wide settings stored at `config` in the database.
class CatalogConfig {
  const CatalogConfig({
    this.currency = 'THB',
    this.bookingFeePerTicket = 10,
    this.maxSeatsPerBooking = 10,
    this.cities = const ['Bangkok', 'Nonthaburi'],
  });

  final String currency;
  final int bookingFeePerTicket;
  final int maxSeatsPerBooking;
  final List<String> cities;

  factory CatalogConfig.fromMap(Map<String, dynamic> map) => CatalogConfig(
    currency: asString(map['currency'], 'THB'),
    bookingFeePerTicket: asInt(map['bookingFeePerTicket'], 10),
    maxSeatsPerBooking: asInt(map['maxSeatsPerBooking'], 10),
    cities: map['cities'] == null ? const ['Bangkok', 'Nonthaburi'] : asStringList(map['cities']),
  );

  Map<String, dynamic> toMap() => {
    'currency': currency,
    'bookingFeePerTicket': bookingFeePerTicket,
    'maxSeatsPerBooking': maxSeatsPerBooking,
    'cities': cities,
  };
}

/// One line of a cinema's daily programme: a movie in a hall at fixed times.
class ProgrammeSlot {
  const ProgrammeSlot({required this.movieId, required this.hallId, required this.times});

  final String movieId;
  final String hallId;
  final List<String> times;

  factory ProgrammeSlot.fromMap(Map<String, dynamic> map) => ProgrammeSlot(
    movieId: asString(map['movieId']),
    hallId: asString(map['hallId']),
    times: asStringList(map['times']),
  );
}

class FormatPrice {
  const FormatPrice({required this.standard, required this.deluxe});

  final int standard;
  final int deluxe;

  factory FormatPrice.fromMap(Map<String, dynamic> map) =>
      FormatPrice(standard: asInt(map['standard'], 220), deluxe: asInt(map['deluxe'], 320));
}

/// Everything in `assets/seed/catalog.json`: the single source of truth for
/// both the Firebase seed and demo mode.
class Catalog {
  const Catalog({
    required this.config,
    required this.movies,
    required this.cinemas,
    required this.layouts,
    required this.programmes,
    required this.pricing,
  });

  final CatalogConfig config;
  final Map<String, Movie> movies;
  final Map<String, Cinema> cinemas;
  final Map<String, SeatLayout> layouts;
  final Map<String, List<ProgrammeSlot>> programmes;
  final Map<String, FormatPrice> pricing;

  factory Catalog.fromJson(Map<String, dynamic> json) {
    final movies = asMap(json['movies']);
    final cinemas = asMap(json['cinemas']);
    final layouts = asMap(json['layouts']);
    final programmes = asMap(json['programmes']);
    final pricing = asMap(json['pricing']);
    return Catalog(
      config: CatalogConfig.fromMap(asMap(json['config'])),
      movies: {for (final e in movies.entries) e.key: Movie.fromMap(e.key, asMap(e.value))},
      cinemas: {for (final e in cinemas.entries) e.key: Cinema.fromMap(e.key, asMap(e.value))},
      layouts: {for (final e in layouts.entries) e.key: SeatLayout.fromMap(e.key, asMap(e.value))},
      programmes: {
        for (final e in programmes.entries) e.key: asList(e.value).map((s) => ProgrammeSlot.fromMap(asMap(s))).toList(),
      },
      pricing: {for (final e in pricing.entries) e.key: FormatPrice.fromMap(asMap(e.value))},
    );
  }
}
