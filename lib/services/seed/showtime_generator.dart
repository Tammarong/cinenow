import 'dart:math';

import '../../models/catalog.dart';
import '../../models/seat_layout.dart';
import '../../models/showtime.dart';

/// Turns each cinema's daily programme (in `catalog.json`) into concrete,
/// dated showtimes — plus a realistic, deterministic set of pre-sold seats.
///
/// Pure Dart (no Flutter imports) so `tool/generate_seed.dart` can use it to
/// build the Firebase seed, and demo mode can use it at runtime.
class ShowtimeGenerator {
  ShowtimeGenerator(this.catalog);

  final Catalog catalog;

  /// Cinemas are in Thailand (UTC+7, no daylight saving).
  static const cinemaUtcOffset = Duration(hours: 7);

  static String showtimeId(String cinemaId, String movieId, String date, String time) =>
      '${cinemaId}_${movieId}_${date.replaceAll('-', '')}_${time.replaceAll(':', '')}';

  static String isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// All showtimes on [day] (a calendar date in cinema local time).
  List<Showtime> forDay(DateTime day, {String? movieId}) {
    final date = isoDate(day);
    final result = <Showtime>[];
    for (final entry in catalog.programmes.entries) {
      final cinema = catalog.cinemas[entry.key];
      if (cinema == null) continue;
      for (final slot in entry.value) {
        if (movieId != null && slot.movieId != movieId) continue;
        final movie = catalog.movies[slot.movieId];
        final hall = cinema.halls[slot.hallId];
        if (movie == null || hall == null || movie.isComingSoon) continue;
        final price = catalog.pricing[hall.format] ?? const FormatPrice(standard: 220, deluxe: 320);
        for (final time in slot.times) {
          final parts = time.split(':');
          final startsAt = DateTime.utc(
            day.year,
            day.month,
            day.day,
            int.parse(parts[0]),
            int.parse(parts[1]),
          ).subtract(cinemaUtcOffset);
          final id = showtimeId(cinema.id, movie.id, date, time);
          result.add(
            Showtime(
              id: id,
              movieId: movie.id,
              cinemaId: cinema.id,
              hallId: hall.id,
              hallName: hall.name,
              format: hall.format,
              layoutId: hall.layoutId,
              date: date,
              time: time,
              startsAt: startsAt.toLocal(),
              priceStandard: price.standard,
              priceDeluxe: price.deluxe,
              soldOut: _isSoldOut(id, time, day),
            ),
          );
        }
      }
    }
    result.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return result;
  }

  List<Showtime> forRange(DateTime from, int days, {String? movieId}) => [
    for (var i = 0; i < days; i++) ...forDay(DateTime(from.year, from.month, from.day + i), movieId: movieId),
  ];

  /// Seats already sold at the box office. Busier in the evening and at
  /// weekends, clustered in pairs, and biased towards the centre.
  Set<String> presoldSeats(Showtime showtime) {
    final layout = catalog.layouts[showtime.layoutId];
    if (layout == null) return const {};
    final rng = Random(_hash(showtime.id));
    final hour = int.tryParse(showtime.time.split(':').first) ?? 12;
    final day = DateTime.tryParse(showtime.date) ?? DateTime.now();
    final weekend = day.weekday >= DateTime.friday;
    var rate = 0.05 + rng.nextDouble() * 0.12;
    if (hour >= 18) rate += 0.14;
    if (weekend) rate += 0.08;
    if (hour < 11) rate -= 0.04;
    rate = rate.clamp(0.03, 0.55);

    final taken = <String>{};
    for (var r = 0; r < layout.rows.length; r++) {
      final row = layout.rows[r];
      // Middle rows are the most popular.
      final rowCentre = 1 - ((r / max(1, layout.rows.length - 1)) - 0.55).abs();
      for (var s = 1; s <= row.seats; s++) {
        final seatCentre = 1 - ((s - 1) / max(1, row.seats - 1) - 0.5).abs() * 1.4;
        final weight = (0.55 + 0.45 * rowCentre) * (0.5 + 0.7 * seatCentre) * (row.type == SeatType.deluxe ? 1.15 : 1);
        if (rng.nextDouble() < rate * weight) {
          taken.add('${row.label}$s');
          if (s < row.seats && rng.nextDouble() < 0.5) taken.add('${row.label}${s + 1}');
        }
      }
    }
    return taken;
  }

  bool _isSoldOut(String id, String time, DateTime day) {
    final hour = int.tryParse(time.split(':').first) ?? 12;
    if (hour < 18) return false;
    final weekendBoost = day.weekday >= DateTime.friday ? 2 : 0;
    return _hash(id) % 23 < 1 + weekendBoost;
  }

  /// FNV-1a — stable across runs and platforms.
  static int _hash(String input) {
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }
}
