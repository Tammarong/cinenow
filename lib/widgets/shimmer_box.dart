import 'package:material_ui/material_ui.dart';
import 'package:shimmer/shimmer.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// Wrap a group of [ShimmerBox]es so they shimmer in sync.
class ShimmerScope extends StatelessWidget {
  const ShimmerScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) return child;
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceBright,
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }
}

class ShimmerBox extends StatelessWidget {
  const ShimmerBox({super.key, this.width, this.height, this.radius = Radii.mdAll});

  final double? width;
  final double? height;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: radius),
    );
  }
}

/// Loading placeholder that mirrors a poster card (poster + two text lines).
class PosterCardSkeleton extends StatelessWidget {
  const PosterCardSkeleton({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: ShimmerBox(radius: Radii.lgAll),
          ),
          Space.gap12,
          ShimmerBox(width: width * 0.8, height: 14, radius: Radii.smAll),
          Space.gap8,
          ShimmerBox(width: width * 0.5, height: 12, radius: Radii.smAll),
        ],
      ),
    );
  }
}
