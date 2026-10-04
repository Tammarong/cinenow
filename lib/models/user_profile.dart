import 'json.dart';

/// The signed-in account (from Firebase Auth or the demo session).
class AppUser {
  const AppUser({required this.uid, required this.email, this.displayName});

  final String uid;
  final String email;
  final String? displayName;

  String get bestName {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return email.split('@').first;
  }

  String get firstName => bestName.split(' ').first;
}

/// Profile stored at `users/{uid}`.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.createdAt,
    this.city,
  });

  final String uid;
  final String displayName;
  final String email;
  final DateTime createdAt;
  final String? city;

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) => UserProfile(
    uid: uid,
    displayName: asString(map['displayName']),
    email: asString(map['email']),
    createdAt: DateTime.fromMillisecondsSinceEpoch(asInt(map['createdAt']), isUtc: true).toLocal(),
    city: asStringOrNull(map['city']),
  );

  Map<String, dynamic> toMap() => {
    'displayName': displayName,
    'email': email,
    'createdAt': createdAt.millisecondsSinceEpoch,
    if (city != null) 'city': city,
  };
}
