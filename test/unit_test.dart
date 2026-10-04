import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cinenow/core/utils/app_exceptions.dart';
import 'package:cinenow/core/utils/formatters.dart';
import 'package:cinenow/core/utils/validators.dart';
import 'package:cinenow/models/booking_draft.dart';
import 'package:cinenow/models/catalog.dart';
import 'package:cinenow/models/movie.dart';
import 'package:cinenow/models/seat_layout.dart';
import 'package:cinenow/services/seed/showtime_generator.dart';
import 'package:cinenow/services/services.dart';
import 'package:cinenow/state/booking_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Catalog loadCatalog() =>
    Catalog.fromJson(jsonDecode(File('assets/seed/catalog.json').readAsStringSync()) as Map<String, dynamic>);

void main() {
  final catalog = loadCatalog();

  group('Validators', () {
    test('email', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('a@b'), isNotNull);
      expect(Validators.email('alex@example.com'), isNull);
      expect(Validators.email('  alex@example.co.th  '), isNull);
    });

    test('new password needs 8+ chars with letters and a number', () {
      expect(Validators.newPassword('short1'), isNotNull);
      expect(Validators.newPassword('longpassword'), isNotNull);
      expect(Validators.newPassword('12345678'), isNotNull);
      expect(Validators.newPassword('popcorn42'), isNull);
    });

    test('confirm password must match', () {
      final validate = Validators.confirmPassword(() => 'popcorn42');
      expect(validate('popcorn41'), isNotNull);
      expect(validate('popcorn42'), isNull);
    });

    test('password strength grows with complexity', () {
      expect(Validators.passwordStrength(''), 0);
      expect(Validators.passwordStrength('abc'), 1);
      expect(Validators.passwordStrength('Popcorn42!xyz'), 3);
    });

    test('name', () {
      expect(Validators.name(' '), isNotNull);
      expect(Validators.name('A'), isNotNull);
      expect(Validators.name('Alex Tan'), isNull);
    });
  });

  group('Formatters', () {
    test('baht and duration', () {
      expect(Fmt.baht(1140), '฿1,140');
      expect(Fmt.duration(166), '2h 46m');
      expect(Fmt.duration(120), '2h');
      expect(Fmt.duration(null), 'TBA');
    });

    test('seats sort naturally', () {
      expect(Fmt.sortSeats(['B1', 'A10', 'A2', 'K3']), ['A2', 'A10', 'B1', 'K3']);
    });

    test('initials', () {
      expect(Fmt.initials('Alex Tan'), 'AT');
      expect(Fmt.initials('zendaya'), 'Z');
      expect(Fmt.initials(''), '?');
    });

    test('relative day', () {
      final now = DateTime(2026, 10, 4, 15);
      expect(Fmt.relativeDay(DateTime(2026, 10, 4), now: now), 'Today');
      expect(Fmt.relativeDay(DateTime(2026, 10, 5), now: now), 'Tomorrow');
      expect(Fmt.relativeDay(DateTime(2026, 10, 7), now: now), 'Wed');
    });
  });

  group('Auth error copy', () {
    test('maps Firebase codes to friendly messages', () {
      expect(friendlyAuthMessage('invalid-credential'), contains('incorrect'));
      expect(friendlyAuthMessage('email-already-in-use'), contains('already exists'));
      expect(friendlyAuthMessage('network-request-failed'), contains('connection'));
      expect(friendlyAuthMessage('something-new'), contains('try again'));
    });

    test('seat conflict message names the seats', () {
      expect(SeatConflictException(['E7']).message, contains('Seat E7 was'));
      expect(SeatConflictException(['E7', 'E8']).message, contains('E7, E8 were'));
    });
  });

  group('Catalog & showtime generator', () {
    test('catalog has at least 8 movies and 3 cinemas', () {
      expect(catalog.movies.length, greaterThanOrEqualTo(8));
      expect(catalog.cinemas.length, greaterThanOrEqualTo(3));
      expect(catalog.movies.values.where((m) => m.isComingSoon), isNotEmpty);
    });

    test('generates dated showtimes in Bangkok time, never for coming-soon films', () {
      final generator = ShowtimeGenerator(catalog);
      final day = DateTime(2026, 10, 10);
      final shows = generator.forDay(day);
      expect(shows, isNotEmpty);
      expect(shows.every((s) => s.date == '2026-10-10'), isTrue);
      expect(shows.any((s) => catalog.movies[s.movieId]!.status == MovieStatus.comingSoon), isFalse);

      final s = shows.firstWhere((s) => s.time == '18:20' && s.movieId == 'dune-part-two');
      // 18:20 in UTC+7 is 11:20 UTC.
      expect(s.startsAt.toUtc(), DateTime.utc(2026, 10, 10, 11, 20));
      expect(s.id, 'cn-siam_dune-part-two_20261010_1820');
    });

    test('pre-sold seats are deterministic and valid', () {
      final generator = ShowtimeGenerator(catalog);
      final show = generator.forDay(DateTime(2026, 10, 10)).first;
      final a = generator.presoldSeats(show);
      final b = generator.presoldSeats(show);
      expect(a, b);
      final layout = catalog.layouts[show.layoutId]!;
      expect(a.every(layout.allSeatIds.toSet().contains), isTrue);
      expect(a.length, lessThan(layout.capacity));
    });

    test('every seat id matches the security-rule pattern', () {
      final pattern = RegExp(r'^[A-L][0-9]{1,2}$');
      for (final layout in catalog.layouts.values) {
        expect(layout.allSeatIds.every(pattern.hasMatch), isTrue, reason: layout.id);
      }
    });
  });

  group('Pricing', () {
    test('breakdown splits standard and deluxe plus booking fee', () {
      final generator = ShowtimeGenerator(catalog);
      final show = generator
          .forDay(DateTime(2026, 10, 10))
          .firstWhere((s) => s.format == '2D' && s.layoutId == 'classic');
      final draft = BookingDraft(
        movie: catalog.movies[show.movieId],
        cinema: catalog.cinemas[show.cinemaId],
        showtime: show,
        layout: catalog.layouts['classic'],
        seats: const ['E7', 'E8', 'J1'],
      );
      final price = draft.price(bookingFeePerTicket: 10);
      expect(price.standardCount, 2);
      expect(price.deluxeCount, 1);
      expect(price.ticketsSubtotal, 2 * 220 + 320);
      expect(price.bookingFee, 30);
      expect(price.total, 790);
    });
  });

  group('BookingController', () {
    late ProviderContainer container;
    late BookingController controller;

    setUp(() {
      container = ProviderContainer();
      controller = container.read(bookingProvider.notifier);
    });
    tearDown(() => container.dispose());

    test('select, deselect, occupied and limit', () {
      expect(controller.toggleSeat('A1', occupied: {}, maxSeats: 2), SeatToggle.selected);
      expect(controller.toggleSeat('A2', occupied: {}, maxSeats: 2), SeatToggle.selected);
      expect(controller.toggleSeat('A3', occupied: {}, maxSeats: 2), SeatToggle.limitReached);
      expect(controller.toggleSeat('B1', occupied: {'B1'}, maxSeats: 5), SeatToggle.occupied);
      expect(controller.toggleSeat('A1', occupied: {}, maxSeats: 2), SeatToggle.deselected);
      expect(container.read(bookingProvider).seats, ['A2']);
    });

    test('seats someone else booked are released', () {
      controller.toggleSeat('C4', occupied: {}, maxSeats: 10);
      controller.toggleSeat('C5', occupied: {}, maxSeats: 10);
      expect(controller.releaseTaken({'C5', 'Z9'}), ['C5']);
      expect(container.read(bookingProvider).seats, ['C4']);
    });

    test('re-entering the same movie keeps the selection', () {
      final movie = catalog.movies['dune-part-two']!;
      controller.startFor(movie);
      controller.toggleSeat('D4', occupied: {}, maxSeats: 10);
      controller.startFor(movie);
      expect(container.read(bookingProvider).seats, ['D4']);
      controller.startFor(catalog.movies['inside-out-2']!);
      expect(container.read(bookingProvider).seats, isEmpty);
    });
  });

  test('booking reference format', () {
    final ref = generateBookingRef(Random(1));
    expect(ref, matches(RegExp(r'^CN-[A-HJ-NP-Z2-9]{6}$')));
  });

  test('seat layout knows deluxe rows', () {
    final layout = catalog.layouts['classic']!;
    expect(layout.typeOf('A1'), SeatType.standard);
    expect(layout.typeOf('K10'), SeatType.deluxe);
    expect(layout.capacity, 8 * 14 + 2 * 10);
  });
}
