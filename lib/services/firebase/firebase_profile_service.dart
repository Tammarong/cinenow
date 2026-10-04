import 'package:firebase_database/firebase_database.dart';

import '../../models/json.dart';
import '../../models/user_profile.dart';
import '../services.dart';

class FirebaseProfileService implements ProfileService {
  FirebaseProfileService(this._db);

  final FirebaseDatabase _db;

  @override
  Stream<UserProfile?> watchProfile(String uid) => _db.ref('users/$uid').onValue.map((event) {
    final value = event.snapshot.value;
    return value == null ? null : UserProfile.fromMap(uid, asMap(value));
  });

  @override
  Future<void> saveProfile(UserProfile profile) =>
      _db.ref('users/${profile.uid}').set({...profile.toMap(), 'createdAt': ServerValue.timestamp});

  @override
  Future<void> updateProfile(String uid, {String? displayName, String? city}) =>
      _db.ref('users/$uid').update({'displayName': ?displayName?.trim(), 'city': ?city});
}
