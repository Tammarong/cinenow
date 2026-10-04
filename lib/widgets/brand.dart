import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

/// CineNow wordmark: a coral "play-ticket" glyph + "Cine" in warm white and
/// "Now" in coral.
class CineNowLogo extends StatelessWidget {
  const CineNowLogo({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'CineNow',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size * 1.25,
            height: size * 1.25,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(size * 0.36),
              boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.45), blurRadius: size * 0.8)],
            ),
            child: Icon(Icons.play_arrow_rounded, color: AppColors.onAccent, size: size),
          ),
          SizedBox(width: size * 0.4),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Cine'),
                TextSpan(
                  text: 'Now',
                  style: TextStyle(color: AppColors.accent),
                ),
              ],
            ),
            style: AppText.display.copyWith(fontSize: size, height: 1, letterSpacing: -0.8),
          ),
        ],
      ),
    );
  }
}
