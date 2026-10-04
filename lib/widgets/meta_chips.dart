import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// ★ 8.6 — gold star + score. Shows "New" when unrated.
class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.rating, this.compact = false, this.onImage = false});

  final double? rating;
  final bool compact;
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final text = rating == null ? 'New' : rating!.toStringAsFixed(1);
    return Semantics(
      label: rating == null ? 'Not yet rated' : 'Rated ${rating!.toStringAsFixed(1)} out of 10',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 3 : 4),
        decoration: BoxDecoration(
          color: onImage ? AppColors.background.withValues(alpha: 0.72) : AppColors.goldSoft,
          borderRadius: Radii.pillAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, size: compact ? 14 : 16, color: AppColors.gold),
            const SizedBox(width: 3),
            Text(
              text,
              style: AppText.label.copyWith(color: AppColors.gold, fontSize: compact ? 12 : 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small outlined tag: age rating, format (IMAX, 4DX), duration, etc.
class MetaTag extends StatelessWidget {
  const MetaTag(this.text, {super.key, this.icon, this.color, this.filled = false});

  final String text;
  final IconData? icon;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? c.withValues(alpha: 0.16) : Colors.transparent,
        borderRadius: Radii.smAll,
        border: Border.all(color: filled ? Colors.transparent : c.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: c), const SizedBox(width: 4)],
          Text(text, style: AppText.label.copyWith(color: c, letterSpacing: 0.3)),
        ],
      ),
    );
  }
}

/// Colour-coded screening format badge.
class FormatBadge extends StatelessWidget {
  const FormatBadge(this.format, {super.key});

  final String format;

  static Color colorFor(String format) => switch (format) {
    'IMAX' => const Color(0xFF6EC1FF),
    '4DX' => const Color(0xFFB98CFF),
    'Dolby Atmos' => AppColors.success,
    _ => AppColors.textSecondary,
  };

  @override
  Widget build(BuildContext context) => MetaTag(format, color: colorFor(format), filled: true);
}

/// Dot-separated genres line: "Sci-Fi · Adventure".
class GenreLine extends StatelessWidget {
  const GenreLine(this.genres, {super.key, this.max = 2, this.style});

  final List<String> genres;
  final int max;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      genres.take(max).join('  ·  '),
      style: style ?? AppText.caption,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction, this.subtitle});

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(title, style: AppText.h2)),
                if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: AppText.caption)],
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text(actionLabel!), const Icon(Icons.chevron_right_rounded, size: 20)],
              ),
            ),
        ],
      ),
    );
  }
}
