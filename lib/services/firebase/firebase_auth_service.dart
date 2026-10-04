import 'package:firebase_auth/firebase_auth.dart';

import '../../core/utils/app_exceptions.dart';
import '../../models/user_profile.dart';
import '../services.dart';

class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this._auth, this._profiles);

  final FirebaseAuth _auth;
  final ProfileService _profiles;

  static AppUser? _map(User? user) =>
      user == null ? null : AppUser(uid: user.uid, email: user.email ?? '', displayName: user.displayName);

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw AppException(friendlyAuthMessage(e.code), code: e.code);
    }
  }

  // userChanges() also fires when the display name changes.
  @override
  Stream<AppUser?> authStateChanges() => _auth.userChanges().map(_map);

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Future<AppUser> signIn({required String email, required String password}) => _guard(() async {
    final cred = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    return _map(cred.user)!;
  });

  @override
  Future<AppUser> signUp({required String name, required String email, required String password, String? city}) =>
      _guard(() async {
        final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
        final user = cred.user!;
        await user.updateDisplayName(name.trim());
        try {
          await _profiles.saveProfile(
            UserProfile(
              uid: user.uid,
              displayName: name.trim(),
              email: user.email ?? email.trim(),
              createdAt: DateTime.now(),
              city: city,
            ),
          );
        } catch (_) {
          // The account exists; the profile is recreated on next edit if this failed.
        }
        return AppUser(uid: user.uid, email: user.email ?? email.trim(), displayName: name.trim());
      });

  @override
  Future<void> sendPasswordReset(String email) => _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> updateDisplayName(String name) => _guard(() async {
    await _auth.currentUser?.updateDisplayName(name.trim());
    await _auth.currentUser?.reload();
  });

  @override
  Future<void> signOut() => _auth.signOut();
}
