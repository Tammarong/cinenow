import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Where the app reads and writes data.
enum BackendMode {
  /// The live `cinenow-kmutnb-2026` Firebase project.
  firebase,

  /// The local Firebase Emulator Suite (`firebase emulators:start`).
  emulator,

  /// No Firebase: bundled sample data, everything stays on the device.
  demo;

  bool get isDemo => this == BackendMode.demo;

  String get label => switch (this) {
    BackendMode.firebase => 'Firebase (live)',
    BackendMode.emulator => 'Firebase Emulator Suite',
    BackendMode.demo => 'Demo mode (on-device only)',
  };
}

class BackendStatus {
  const BackendStatus(this.mode, {this.reason});

  final BackendMode mode;

  /// Why we ended up in demo mode, shown on the Profile > About sheet.
  final String? reason;
}

/// Build-time switches:
///   --dart-define=FORCE_DEMO=true        run without Firebase
///   --dart-define=USE_EMULATORS=true     use the local emulators
///   --dart-define=EMULATOR_HOST=10.0.2.2 host for the emulators
const _forceDemo = bool.fromEnvironment('FORCE_DEMO');
const _useEmulators = bool.fromEnvironment('USE_EMULATORS');
const _emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');

Future<BackendStatus> initBackend() async {
  if (_forceDemo) {
    return const BackendStatus(BackendMode.demo, reason: 'Started with FORCE_DEMO=true.');
  }

  final FirebaseOptions options;
  try {
    options = DefaultFirebaseOptions.currentPlatform;
  } catch (e) {
    return BackendStatus(BackendMode.demo, reason: 'No Firebase configuration for this platform.');
  }
  if (options.apiKey.isEmpty || options.apiKey.contains('REPLACE') || options.databaseURL == null) {
    return const BackendStatus(BackendMode.demo, reason: 'Firebase configuration is missing or incomplete.');
  }

  try {
    await Firebase.initializeApp(options: options).timeout(const Duration(seconds: 12));
    if (_useEmulators) {
      await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
      FirebaseDatabase.instance.useDatabaseEmulator(_emulatorHost, 9000);
      return const BackendStatus(BackendMode.emulator);
    }
    // Cache catalog + tickets on disk so the app opens offline.
    FirebaseDatabase.instance.setPersistenceEnabled(true);
    FirebaseDatabase.instance.setPersistenceCacheSizeBytes(20 * 1024 * 1024);
    unawaited(_dropInvalidSession());
    return const BackendStatus(BackendMode.firebase);
  } catch (e) {
    debugPrint('Firebase init failed, falling back to demo mode: $e');
    return BackendStatus(BackendMode.demo, reason: 'Firebase could not start ($e).');
  }
}

/// A saved session whose token the server rejects (account deleted, token
/// revoked, or left over from the emulator) makes the Realtime Database drop
/// every connection — even for public movie data. Sign out in that case so
/// the app keeps working as a guest. Network errors are ignored.
Future<void> _dropInvalidSession() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  try {
    await user.getIdToken(true).timeout(const Duration(seconds: 10));
  } on FirebaseAuthException catch (e) {
    const fatal = {'user-token-expired', 'invalid-user-token', 'user-not-found', 'user-disabled', 'invalid-credential'};
    if (fatal.contains(e.code)) {
      debugPrint('Saved session is no longer valid (${e.code}); signing out.');
      await FirebaseAuth.instance.signOut();
    }
  } catch (_) {
    // Offline or slow network: keep the session.
  }
}
