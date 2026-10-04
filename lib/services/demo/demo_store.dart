import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/json.dart';
import '../../models/reservation.dart';
import '../../models/user_profile.dart';

/// On-device storage for demo mode. Nothing here ever reaches Firebase.
class DemoStore {
  DemoStore(this._prefs);

  final SharedPreferences _prefs;
  final _changes = StreamController<void>.broadcast();

  static const _sessionKey = 'demo.session';
  static const _accountsKey = 'demo.accounts';
  static const _profilesKey = 'demo.profiles';
  static const _reservationsKey = 'demo.reservations';

  Stream<void> get changes => _changes.stream;

  Map<String, dynamic> _readMap(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return {};
    try {
      return asMap(jsonDecode(raw));
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeMap(String key, Map<String, dynamic> value) async {
    await _prefs.setString(key, jsonEncode(value));
    _changes.add(null);
  }

  // Session -----------------------------------------------------------------
  AppUser? get session {
    final map = _readMap(_sessionKey);
    if (map.isEmpty) return null;
    return AppUser(uid: asString(map['uid']), email: asString(map['email']), displayName: asStringOrNull(map['name']));
  }

  Future<void> setSession(AppUser? user) async {
    if (user == null) {
      await _prefs.remove(_sessionKey);
      _changes.add(null);
      return;
    }
    await _writeMap(_sessionKey, {'uid': user.uid, 'email': user.email, 'name': user.displayName});
  }

  // Accounts (email -> uid/name). Demo sign-in doesn't store passwords. -----
  AppUser? accountFor(String email) {
    final map = asMap(_readMap(_accountsKey)[email.toLowerCase()]);
    if (map.isEmpty) return null;
    return AppUser(uid: asString(map['uid']), email: email.toLowerCase(), displayName: asStringOrNull(map['name']));
  }

  Future<void> saveAccount(AppUser user) async {
    final all = _readMap(_accountsKey);
    all[user.email.toLowerCase()] = {'uid': user.uid, 'name': user.displayName};
    await _writeMap(_accountsKey, all);
  }

  // Profiles ---------------------------------------------------------------
  UserProfile? profile(String uid) {
    final map = asMap(_readMap(_profilesKey)[uid]);
    return map.isEmpty ? null : UserProfile.fromMap(uid, map);
  }

  Future<void> saveProfile(UserProfile profile) async {
    final all = _readMap(_profilesKey);
    all[profile.uid] = profile.toMap();
    await _writeMap(_profilesKey, all);
  }

  // Reservations -----------------------------------------------------------
  List<Reservation> reservations(String uid) {
    final map = asMap(_readMap(_reservationsKey)[uid]);
    return [for (final e in map.entries) Reservation.fromMap(e.key, asMap(e.value), isDemo: true)];
  }

  /// Seats booked on this device for a showtime (by any demo account).
  Set<String> bookedSeats(String showtimeId) {
    final all = _readMap(_reservationsKey);
    final seats = <String>{};
    for (final userReservations in all.values) {
      for (final r in asMap(userReservations).values) {
        final res = asMap(r);
        if (res['showtimeId'] == showtimeId) seats.addAll(asMap(res['seats']).keys);
      }
    }
    return seats;
  }

  Future<void> addReservation(String uid, Reservation reservation) async {
    final all = _readMap(_reservationsKey);
    final mine = asMap(all[uid]);
    mine[reservation.id] = reservation.toMap();
    all[uid] = mine;
    await _writeMap(_reservationsKey, all);
  }
}
