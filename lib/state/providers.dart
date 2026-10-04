import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/backend_mode.dart';
import '../core/utils/formatters.dart';
import '../models/catalog.dart';
import '../models/cinema.dart';
import '../models/movie.dart';
import '../models/reservation.dart';
import '../models/seat_layout.dart';
import '../models/showtime.dart';
import '../models/user_profile.dart';
import '../services/demo/demo_services.dart';
import '../services/demo/demo_store.dart';
import '../services/firebase/firebase_auth_service.dart';
import '../services/firebase/firebase_catalog_service.dart';
import '../services/firebase/firebase_profile_service.dart';
import '../services/firebase/firebase_reservation_service.dart';
import '../services/services.dart';

// ---------------------------------------------------------------------------
// Bootstrap (overridden in main.dart)
// ---------------------------------------------------------------------------

final backendStatusProvider = Provider<BackendStatus>((ref) => throw UnimplementedError('Override in main'));
final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('Override in main'));

final isDemoProvider = Provider<bool>((ref) => ref.watch(backendStatusProvider).mode.isDemo);

// ---------------------------------------------------------------------------
// Services — Firebase or on-device demo, chosen once at startup
// ---------------------------------------------------------------------------

final demoStoreProvider = Provider<DemoStore>((ref) => DemoStore(ref.watch(prefsProvider)));
final _demoCatalogProvider = Provider<DemoCatalogService>((ref) => DemoCatalogService(ref.watch(demoStoreProvider)));

final catalogServiceProvider = Provider<CatalogService>(
  (ref) =>
      ref.watch(isDemoProvider) ? ref.watch(_demoCatalogProvider) : FirebaseCatalogService(FirebaseDatabase.instance),
);

final profileServiceProvider = Provider<ProfileService>(
  (ref) => ref.watch(isDemoProvider)
      ? DemoProfileService(ref.watch(demoStoreProvider))
      : FirebaseProfileService(FirebaseDatabase.instance),
);

final authServiceProvider = Provider<AuthService>(
  (ref) => ref.watch(isDemoProvider)
      ? DemoAuthService(ref.watch(demoStoreProvider))
      : FirebaseAuthService(FirebaseAuth.instance, ref.watch(profileServiceProvider)),
);

final reservationServiceProvider = Provider<ReservationService>(
  (ref) => ref.watch(isDemoProvider)
      ? DemoReservationService(ref.watch(demoStoreProvider), ref.watch(_demoCatalogProvider))
      : FirebaseReservationService(FirebaseDatabase.instance),
);

// ---------------------------------------------------------------------------
// Catalog
// ---------------------------------------------------------------------------

final configProvider = FutureProvider<CatalogConfig>((ref) async {
  try {
    return await ref.watch(catalogServiceProvider).fetchConfig();
  } catch (_) {
    return const CatalogConfig();
  }
});

final moviesProvider = FutureProvider<List<Movie>>((ref) => ref.watch(catalogServiceProvider).fetchMovies());

final nowShowingProvider = Provider<AsyncValue<List<Movie>>>(
  (ref) => ref
      .watch(moviesProvider)
      .whenData(
        (movies) =>
            movies.where((m) => m.isNowShowing).toList()..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0)),
      ),
);

final comingSoonProvider = Provider<AsyncValue<List<Movie>>>(
  (ref) => ref
      .watch(moviesProvider)
      .whenData(
        (movies) =>
            movies.where((m) => m.isComingSoon).toList()
              ..sort((a, b) => (a.releaseDate ?? DateTime(2100)).compareTo(b.releaseDate ?? DateTime(2100))),
      ),
);

final featuredProvider = Provider<AsyncValue<List<Movie>>>(
  (ref) => ref.watch(moviesProvider).whenData((movies) => movies.where((m) => m.featured && m.isNowShowing).toList()),
);

final movieProvider = Provider.family<AsyncValue<Movie?>, String>(
  (ref, id) => ref.watch(moviesProvider).whenData((movies) => movies.where((m) => m.id == id).firstOrNull),
);

final genresProvider = Provider<List<String>>((ref) {
  final movies = ref.watch(moviesProvider).value ?? const [];
  return {for (final m in movies) ...m.genres}.toList()..sort();
});

final cinemasProvider = FutureProvider<List<Cinema>>((ref) => ref.watch(catalogServiceProvider).fetchCinemas());

final layoutsProvider = FutureProvider<Map<String, SeatLayout>>(
  (ref) => ref.watch(catalogServiceProvider).fetchLayouts(),
);

/// Number of days shown in the date selector.
const bookingWindowDays = 7;

final showtimesProvider = FutureProvider.autoDispose.family<List<Showtime>, String>((ref, movieId) {
  final today = DateTime.now();
  final from = DateTime(today.year, today.month, today.day);
  final to = from.add(const Duration(days: bookingWindowDays - 1));
  return ref
      .watch(catalogServiceProvider)
      .fetchShowtimes(movieId, fromDate: Fmt.isoDate(from), toDate: Fmt.isoDate(to));
});

final occupiedSeatsProvider = StreamProvider.autoDispose.family<Set<String>, String>(
  (ref, showtimeId) => ref.watch(catalogServiceProvider).watchOccupiedSeats(showtimeId),
);

// ---------------------------------------------------------------------------
// Account
// ---------------------------------------------------------------------------

final authStateProvider = StreamProvider<AppUser?>((ref) => ref.watch(authServiceProvider).authStateChanges());

final currentUserProvider = Provider<AppUser?>((ref) {
  final state = ref.watch(authStateProvider);
  return state.value ?? (state.isLoading ? ref.watch(authServiceProvider).currentUser : null);
});

final profileProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);
  return ref.watch(profileServiceProvider).watchProfile(user.uid);
});

final reservationsProvider = StreamProvider<List<Reservation>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return ref.watch(reservationServiceProvider).watchReservations(user.uid);
});

// ---------------------------------------------------------------------------
// Connectivity — `.info/connected`, debounced so brief blips don't flash a
// banner. Optimistically "online" at start-up while the socket connects.
// ---------------------------------------------------------------------------

final connectionProvider = StreamProvider<bool>((ref) {
  if (ref.watch(isDemoProvider)) return Stream.value(true);
  final db = FirebaseDatabase.instance;
  // On Android the SDK closes an idle socket after 60s with no listeners, and
  // `.info/connected` then reads false even though the device is online. A
  // listener on the tiny `config` node keeps the socket (and the banner) honest.
  final keepAlive = db.ref('config').onValue.listen((_) {}, onError: (_) {});
  ref.onDispose(keepAlive.cancel);
  final source = db.ref('.info/connected').onValue.map((e) => e.snapshot.value == true);
  return debounceOffline(source, const Duration(milliseconds: 2500));
});

Stream<bool> debounceOffline(Stream<bool> source, Duration grace) {
  late final StreamController<bool> controller;
  StreamSubscription<bool>? sub;
  Timer? timer;
  var current = true;
  void emit(bool value) {
    if (value == current) return;
    current = value;
    controller.add(value);
  }

  controller = StreamController<bool>(
    onListen: () {
      controller.add(true);
      final started = DateTime.now();
      sub = source.listen((online) {
        timer?.cancel();
        if (online) return emit(true);
        // The socket reports "offline" while it first connects: be patient.
        final wait = DateTime.now().difference(started) < grace * 2 ? grace * 2 : grace;
        timer = Timer(wait, () => emit(false));
      });
    },
    onCancel: () {
      timer?.cancel();
      return sub?.cancel();
    },
  );
  return controller.stream;
}

final isOnlineProvider = Provider<bool>((ref) => ref.watch(connectionProvider).value ?? true);

/// Before an important write: if we look offline, ask the SDK to reconnect
/// and give it a few seconds. Returns false only if we really can't connect.
final ensureConnectedProvider = Provider<Future<bool> Function()>(
  (ref) => () async {
    if (ref.read(isDemoProvider) || ref.read(isOnlineProvider)) return true;
    final db = FirebaseDatabase.instance;
    db.goOnline();
    try {
      await db
          .ref('.info/connected')
          .onValue
          .map((e) => e.snapshot.value == true)
          .firstWhere((v) => v)
          .timeout(const Duration(seconds: 5));
      return true;
    } catch (_) {
      return false;
    }
  },
);
