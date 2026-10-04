/// An error with a message that is safe to show to people as-is.
class AppException implements Exception {
  const AppException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Thrown when one or more seats were booked by someone else between
/// selection and confirmation.
class SeatConflictException extends AppException {
  SeatConflictException(this.seats)
    : super(
        seats.length == 1
            ? 'Seat ${seats.first} was just booked by someone else.'
            : 'Seats ${seats.join(', ')} were just booked by someone else.',
        code: 'seat-conflict',
      );

  final List<String> seats;
}

class OfflineException extends AppException {
  const OfflineException()
    : super('You\'re offline. Reconnect to confirm your reservation — nothing has been booked yet.', code: 'offline');
}

/// Maps Firebase Auth error codes to friendly, actionable copy.
String friendlyAuthMessage(String code) => switch (code) {
  'invalid-email' => 'That email address looks incorrect. Check it and try again.',
  'user-disabled' => 'This account has been disabled. Contact support if this seems wrong.',
  'user-not-found' ||
  'wrong-password' ||
  'invalid-credential' ||
  'INVALID_LOGIN_CREDENTIALS' => 'Email or password is incorrect. Try again or reset your password.',
  'email-already-in-use' => 'An account already exists for this email. Try signing in instead.',
  'weak-password' => 'Choose a stronger password — at least 8 characters with a number.',
  'operation-not-allowed' => 'Email sign-in isn\'t enabled for this project yet.',
  'too-many-requests' => 'Too many attempts. Take a short break and try again in a minute.',
  'network-request-failed' => 'Can\'t reach the server. Check your connection and try again.',
  'missing-email' => 'Enter your email address first.',
  'requires-recent-login' => 'For your security, please sign in again and retry.',
  _ => 'Something went wrong. Please try again.',
};
