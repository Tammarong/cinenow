import 'package:material_ui/material_ui.dart';

/// CineNow colour tokens. Every text/background pair used in the app meets
/// WCAG AA (4.5:1) — note that labels on coral use [onAccent] (near-black),
/// because white on coral only reaches ~2.8:1.
abstract final class AppColors {
  // Surfaces (deep charcoal, layered from back to front).
  static const background = Color(0xFF121214);
  static const surface = Color(0xFF1C1C1F);
  static const surfaceRaised = Color(0xFF26262A);
  static const surfaceBright = Color(0xFF313136);
  static const outline = Color(0xFF3A3A40);
  static const outlineSoft = Color(0xFF2C2C31);

  // Text (warm whites).
  static const textPrimary = Color(0xFFF5F1EA);
  static const textSecondary = Color(0xFFB9B3AA);
  static const textTertiary = Color(0xFF8E887F);

  // Accent.
  static const accent = Color(0xFFFF6B5A);
  static const accentPressed = Color(0xFFE85A4A);
  static const accentSoft = Color(0x29FF6B5A); // 16% coral wash
  static const onAccent = Color(0xFF1A0F0D);

  // Semantic.
  static const gold = Color(0xFFFFC861);
  static const goldSoft = Color(0x26FFC861);
  static const success = Color(0xFF4CD6A0);
  static const successSoft = Color(0x264CD6A0);
  static const error = Color(0xFFFF5470);
  static const errorSoft = Color(0x26FF5470);
  static const warning = Color(0xFFFFB547);
  static const warningSoft = Color(0x26FFB547);

  // Seats.
  static const seatAvailable = Color(0xFF3A3A40);
  static const seatOccupied = Color(0xFF2A2A2E);
  static const seatOccupiedMark = Color(0xFF6B665F);

  static const scrim = Color(0xCC121214);

  /// Gradient used over backdrops so text stays readable.
  static const backdropFade = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00121214), Color(0x99121214), background],
    stops: [0.0, 0.55, 1.0],
  );

  static Color fromHex(String? hex, {Color fallback = accent}) {
    if (hex == null) return fallback;
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned.length == 6 ? 'FF$cleaned' : cleaned, radix: 16);
    return value == null ? fallback : Color(value);
  }
}
