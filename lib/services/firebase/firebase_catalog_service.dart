import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

import '../../core/utils/app_exceptions.dart';
import '../../models/catalog.dart';
import '../../models/cinema.dart';
import '../../models/json.dart';
import '../../models/movie.dart';
import '../../models/seat_layout.dart';
import '../../models/showtime.dart';
import '../services.dart';

class FirebaseCatalogService implements CatalogService {
  FirebaseCatalogService(this._db);

  final FirebaseDatabase _db;

  /// Prefer fresh server data; fall back to the on-disk cache when offline.
  Future<Object?> _read(Query query, String what) async {
    try {
      final snap = await query.get().timeout(const Duration(seconds: 8));
      return snap.value;
    } catch (_) {
      try {
        final event = await query.once().timeout(const Duration(seconds: 6));
        return event.snapshot.value;
      } catch (_) {
        throw AppException('We couldn\'t load $what. Check your connection and try again.', code: 'unavailable');
      }
    }
  }

  @override
  Future<CatalogConfig> fetchConfig() async => CatalogConfig.fromMap(asMap(await _read(_db.ref('config'), 'settings')));

  @override
  Future<List<Movie>> fetchMovies() async {
    final map = asMap(await _read(_db.ref('movies'), 'movies'));
    return [for (final e in map.entries) Movie.fromMap(e.key, asMap(e.value))];
  }

  @override
  Future<List<Cinema>> fetchCinemas() async {
    final map = asMap(await _read(_db.ref('cinemas'), 'cinemas'));
    return [for (final e in map.entries) Cinema.fromMap(e.key, asMap(e.value))];
  }

  @override
  Future<Map<String, SeatLayout>> fetchLayouts() async {
    final map = asMap(await _read(_db.ref('layouts'), 'seat maps'));
    return {for (final e in map.entries) e.key: SeatLayout.fromMap(e.key, asMap(e.value))};
  }

  @override
  Future<List<Showtime>> fetchShowtimes(String movieId, {required String fromDate, required String toDate}) async {
    final query = _db.ref('showtimes/$movieId').orderByChild('date').startAt(fromDate).endAt(toDate);
    final map = asMap(await _read(query, 'showtimes'));
    final list = [for (final e in map.entries) Showtime.fromMap(e.key, asMap(e.value))];
    list.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return list;
  }

  @override
  Stream<Set<String>> watchOccupiedSeats(String showtimeId) =>
      _db.ref('occupiedSeats/$showtimeId').onValue.map((event) => asMap(event.snapshot.value).keys.toSet());
}
