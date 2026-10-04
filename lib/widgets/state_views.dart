import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../state/providers.dart';
import 'cine_button.dart';

/// Friendly empty state: illustrated icon, headline, one helpful action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: Space.xl, vertical: compact ? Space.lg : Space.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IllustratedIcon(icon: icon, size: compact ? 88 : 112),
              SizedBox(height: compact ? Space.md : Space.lg),
              Semantics(
                header: true,
                child: Text(title, style: AppText.h2, textAlign: TextAlign.center),
              ),
              Space.gap8,
              Text(message, style: AppText.bodyMuted, textAlign: TextAlign.center),
              if (actionLabel != null) ...[
                Space.gap24,
                CineButton(label: actionLabel!, onPressed: onAction, expand: false),
              ],
              if (secondaryLabel != null) ...[
                Space.gap8,
                CineButton.ghost(label: secondaryLabel!, onPressed: onSecondary),
              ],
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: Motion.slow).slideY(begin: 0.04, end: 0, curve: Motion.curve);
  }
}

class _IllustratedIcon extends StatelessWidget {
  const _IllustratedIcon({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [AppColors.accentSoft, Color(0x00FF6B5A)]),
            ),
          ),
          Container(
            width: size * 0.62,
            height: size * 0.62,
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.outline),
            ),
            child: Icon(icon, size: size * 0.3, color: AppColors.accent),
          ),
        ],
      ),
    );
  }
}

/// Error state with a retry action.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry, this.compact = false});

  final String message;
  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.wifi_tethering_error_rounded,
      title: 'Something went off-script',
      message: message,
      actionLabel: 'Try again',
      onAction: onRetry,
      compact: compact,
    );
  }
}

String friendlyError(Object error) {
  final text = error.toString();
  if (text.startsWith('Exception:')) return text.substring(10).trim();
  if (text.length > 160 || text.contains('Instance of')) {
    return 'We couldn\'t load this right now. Check your connection and try again.';
  }
  return text;
}

/// Slim banner shown at the top of the app while offline or in demo mode.
class StatusBanners extends ConsumerWidget {
  const StatusBanners({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDemo = ref.watch(isDemoProvider);
    final online = ref.watch(isOnlineProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isDemo)
          const _Banner(
            icon: Icons.science_outlined,
            color: AppColors.warning,
            text: 'Demo mode — data stays on this device and is not saved to Firebase.',
          ),
        AnimatedSize(
          duration: Motion.medium,
          curve: Motion.curve,
          child: online
              ? const SizedBox(width: double.infinity)
              : const _Banner(
                  icon: Icons.cloud_off_rounded,
                  color: AppColors.textSecondary,
                  text: 'You\'re offline. Showing saved info — booking resumes when you reconnect.',
                ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs),
        color: Color.alphaBlend(color.withValues(alpha: 0.14), AppColors.background),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            Space.gap8,
            Expanded(
              child: Text(text, style: AppText.caption.copyWith(color: AppColors.textPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}

void showAppSnack(BuildContext context, String message, {IconData? icon, String? actionLabel, VoidCallback? onAction}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 20, color: AppColors.accent), Space.gap12],
            Expanded(child: Text(message)),
          ],
        ),
        action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
        duration: const Duration(seconds: 4),
      ),
    );
}
