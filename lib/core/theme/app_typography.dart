import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

/// Type scale: Sora for display/headings, Inter for everything you read.
abstract final class AppText {
  static TextStyle _sora(double size, FontWeight weight, {double height = 1.2, double spacing = -0.2}) =>
      GoogleFonts.sora(
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: spacing,
        color: AppColors.textPrimary,
      );

  static TextStyle _inter(
    double size,
    FontWeight weight, {
    double height = 1.45,
    Color color = AppColors.textPrimary,
    double spacing = 0,
  }) => GoogleFonts.inter(fontSize: size, fontWeight: weight, height: height, letterSpacing: spacing, color: color);

  static final display = _sora(32, FontWeight.w700, height: 1.12, spacing: -0.6);
  static final h1 = _sora(26, FontWeight.w700, height: 1.15, spacing: -0.4);
  static final h2 = _sora(20, FontWeight.w600);
  static final h3 = _sora(17, FontWeight.w600, height: 1.25, spacing: -0.1);

  static final bodyLarge = _inter(17, FontWeight.w400);
  static final body = _inter(15, FontWeight.w400);
  static final bodyMuted = _inter(15, FontWeight.w400, color: AppColors.textSecondary);
  static final bodyStrong = _inter(15, FontWeight.w600);
  static final caption = _inter(13, FontWeight.w500, height: 1.35, color: AppColors.textSecondary);
  static final label = _inter(12, FontWeight.w600, height: 1.2, color: AppColors.textSecondary, spacing: 0.4);
  static final button = _inter(16, FontWeight.w700, height: 1.2, spacing: 0.1);
  static final overline = _inter(12, FontWeight.w700, height: 1.2, color: AppColors.accent, spacing: 1.4);

  /// Large amounts. Inter, because Sora has no Thai Baht glyph (฿).
  static final price = _inter(20, FontWeight.w700, height: 1.2, spacing: -0.2);

  static TextTheme textTheme() => TextTheme(
    displayLarge: display,
    displayMedium: display,
    displaySmall: h1,
    headlineLarge: h1,
    headlineMedium: h1,
    headlineSmall: h2,
    titleLarge: h2,
    titleMedium: h3,
    titleSmall: bodyStrong,
    bodyLarge: bodyLarge,
    bodyMedium: body,
    bodySmall: caption,
    labelLarge: button,
    labelMedium: label,
    labelSmall: label,
  );
}
