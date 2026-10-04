// Builds `firebase/database.seed.json` from `assets/seed/catalog.json`.
//
//   dart run tool/generate_seed.dart                 # 21 days from today
//   dart run tool/generate_seed.dart --days 30
//   dart run tool/generate_seed.dart --from 2026-10-04
//   dart run tool/generate_seed.dart --refresh       # showtimes/seats only
//
// Upload a first-time seed:   firebase database:set / firebase/database.seed.json
// Refresh showtimes later:    firebase database:update / firebase/database.refresh.json
//   (the refresh file uses multi-path keys, so reservations and users are untouched)
import 'dart:convert';
import 'dart:io';

import 'package:cinenow/models/catalog.dart';
import 'package:cinenow/services/seed/showtime_generator.dart';

void main(List<String> args) {
  var days = 21;
  var from = DateTime.now();
  var refresh = false;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--days':
        days = int.parse(args[++i]);
      case '--from':
        from = DateTime.parse(args[++i]);
      case '--refresh':
        refresh = true;
    }
  }
  from = DateTime(from.year, from.month, from.day);

  final raw = jsonDecode(File('assets/seed/catalog.json').readAsStringSync()) as Map<String, dynamic>;
  final catalog = Catalog.fromJson(raw);
  final generator = ShowtimeGenerator(catalog);
  final showtimes = generator.forRange(from, days);

  final showtimesByMovie = <String, Map<String, Object?>>{};
  final occupied = <String, Map<String, Object?>>{};
  var seatCount = 0;
  for (final st in showtimes) {
    showtimesByMovie.putIfAbsent(st.movieId, () => {})[st.id] = st.toMap();
    final seats = generator.presoldSeats(st);
    if (seats.isEmpty) continue;
    seatCount += seats.length;
    occupied[st.id] = {
      for (final s in seats) s: const {'uid': 'box-office'},
    };
  }

  // Catalog nodes, minus the generator-only inputs (programmes, pricing).
  final catalogNodes = {
    'config': raw['config'],
    'movies': raw['movies'],
    'cinemas': raw['cinemas'],
    'layouts': raw['layouts'],
  };

  const encoder = JsonEncoder.withIndent('  ');
  Directory('firebase').createSync(recursive: true);
  if (refresh) {
    final update = <String, Object?>{
      ...catalogNodes,
      for (final e in showtimesByMovie.entries) 'showtimes/${e.key}': e.value,
      for (final e in occupied.entries) 'occupiedSeats/${e.key}': e.value,
    };
    File('firebase/database.refresh.json').writeAsStringSync(encoder.convert(update));
    stdout.writeln('Wrote firebase/database.refresh.json');
  } else {
    final seed = {...catalogNodes, 'showtimes': showtimesByMovie, 'occupiedSeats': occupied};
    File('firebase/database.seed.json').writeAsStringSync(encoder.convert(seed));
    stdout.writeln('Wrote firebase/database.seed.json');
  }
  stdout.writeln(
    '${showtimes.length} showtimes over $days days from ${ShowtimeGenerator.isoDate(from)}, '
    '$seatCount pre-sold seats, ${showtimes.where((s) => s.soldOut).length} sold-out sessions.',
  );
}
