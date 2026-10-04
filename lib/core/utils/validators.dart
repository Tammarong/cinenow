/// Form validators. Each returns `null` when the value is valid, or a short,
/// friendly sentence telling the user how to fix it.
abstract final class Validators {
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static String? name(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Tell us what to call you.';
    if (v.length < 2) return 'Your name needs at least 2 characters.';
    if (v.length > 60) return 'Please keep your name under 60 characters.';
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email address.';
    if (!_email.hasMatch(v)) return 'That doesn\'t look like an email address.';
    return null;
  }

  /// Sign-in only needs a non-empty password; Firebase decides if it's right.
  static String? passwordPresent(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password.';
    return null;
  }

  static String? newPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Create a password.';
    if (v.length < 8) return 'Use at least 8 characters.';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Mix letters and at least one number.';
    }
    return null;
  }

  static String? Function(String?) confirmPassword(String Function() original) => (value) {
    if (value == null || value.isEmpty) return 'Re-enter your password.';
    if (value != original()) return 'Passwords don\'t match.';
    return null;
  };

  /// 0 = empty, 1 = weak, 2 = okay, 3 = strong. Drives the strength meter.
  static int passwordStrength(String value) {
    if (value.isEmpty) return 0;
    var score = 0;
    if (value.length >= 8) score++;
    if (value.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(value) && RegExp(r'[a-z]').hasMatch(value)) score++;
    if (RegExp(r'\d').hasMatch(value)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
    if (score <= 1) return 1;
    if (score <= 3) return 2;
    return 3;
  }
}
