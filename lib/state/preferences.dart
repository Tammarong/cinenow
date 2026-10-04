import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Selected city for the Home header and cinema ordering.
class LocationController extends Notifier<String> {
  static const _key = 'pref.city';

  @override
  String build() => ref.watch(prefsProvider).getString(_key) ?? 'Bangkok';

  Future<void> set(String city) async {
    state = city;
    await ref.read(prefsProvider).setString(_key, city);
  }
}

final locationProvider = NotifierProvider<LocationController, String>(LocationController.new);

/// Whether the welcome screen has been shown on this device.
class WelcomeSeenController extends Notifier<bool> {
  static const _key = 'pref.welcomeSeen';

  @override
  bool build() => ref.watch(prefsProvider).getBool(_key) ?? false;

  Future<void> markSeen() async {
    if (state) return;
    state = true;
    await ref.read(prefsProvider).setBool(_key, true);
  }
}

final welcomeSeenProvider = NotifierProvider<WelcomeSeenController, bool>(WelcomeSeenController.new);

/// "Remind me" for coming-soon titles (kept on this device).
class RemindersController extends Notifier<Set<String>> {
  static const _key = 'pref.reminders';

  @override
  Set<String> build() => (ref.watch(prefsProvider).getStringList(_key) ?? const []).toSet();

  /// Returns true when the reminder is now on.
  Future<bool> toggle(String movieId) async {
    final next = {...state};
    final added = next.add(movieId);
    if (!added) next.remove(movieId);
    state = next;
    await ref.read(prefsProvider).setStringList(_key, next.toList());
    return added;
  }
}

final remindersProvider = NotifierProvider<RemindersController, Set<String>>(RemindersController.new);
