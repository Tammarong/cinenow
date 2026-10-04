import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static const overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.surface,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      primaryContainer: AppColors.accentSoft,
      onPrimaryContainer: AppColors.textPrimary,
      secondary: AppColors.gold,
      onSecondary: AppColors.onAccent,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerLowest: AppColors.background,
      surfaceContainerLow: AppColors.surface,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surfaceRaised,
      surfaceContainerHighest: AppColors.surfaceBright,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineSoft,
      error: AppColors.error,
      onError: AppColors.onAccent,
    );

    final text = AppText.textTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      dividerTheme: const DividerThemeData(color: AppColors.outlineSoft, thickness: 1, space: 1),
      iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 24),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: overlayStyle,
        titleTextStyle: AppText.h3,
        foregroundColor: AppColors.textPrimary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.accentSoft,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected) ? AppColors.accent : AppColors.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppText.label.copyWith(
            color: states.contains(WidgetState.selected) ? AppColors.textPrimary : AppColors.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 18),
        hintStyle: AppText.body.copyWith(color: AppColors.textTertiary),
        labelStyle: AppText.body.copyWith(color: AppColors.textSecondary),
        floatingLabelStyle: AppText.label.copyWith(color: AppColors.accent),
        errorStyle: AppText.caption.copyWith(color: AppColors.error),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
        border: const OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide(color: AppColors.outlineSoft),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide(color: AppColors.outlineSoft),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide(color: AppColors.accent, width: 1.6),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide(color: AppColors.error, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.accent,
        disabledColor: AppColors.surface,
        side: const BorderSide(color: AppColors.outline),
        shape: const StadiumBorder(),
        labelStyle: AppText.bodyStrong.copyWith(fontSize: 14),
        secondaryLabelStyle: AppText.bodyStrong.copyWith(fontSize: 14, color: AppColors.onAccent),
        checkmarkColor: AppColors.onAccent,
        padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xs),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceBright,
        contentTextStyle: AppText.body,
        actionTextColor: AppColors.accent,
        shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
        insetPadding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surface,
        showDragHandle: true,
        dragHandleColor: AppColors.outline,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Radii.xlAll),
        titleTextStyle: AppText.h2,
        contentTextStyle: AppText.bodyMuted,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          minimumSize: const Size(Space.touchTarget, Space.touchTarget),
          textStyle: AppText.bodyStrong,
          shape: const StadiumBorder(),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(Space.touchTarget, Space.touchTarget),
          foregroundColor: AppColors.textPrimary,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.accent),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionColor: AppColors.accentSoft,
        selectionHandleColor: AppColors.accent,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(color: AppColors.surfaceBright, borderRadius: Radii.smAll),
        textStyle: AppText.caption.copyWith(color: AppColors.textPrimary),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
      ),
    );
  }
}
