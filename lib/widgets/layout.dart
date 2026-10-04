import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// Centres content and caps its width on tablets / landscape.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = Space.maxContentWidth});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Columns for poster grids: 2 on phones, 3 on large phones/small tablets, 4+ on tablets.
int posterGridColumns(double width) {
  if (width >= 900) return 5;
  if (width >= 700) return 4;
  if (width >= 520) return 3;
  return 2;
}

/// Bottom action area that stays above content, the home indicator and the
/// keyboard. A soft fade makes scrolling content slide under it gracefully.
class StickyBottomBar extends StatelessWidget {
  const StickyBottomBar({super.key, required this.child, this.top});

  final Widget child;

  /// Optional summary line(s) above the main action.
  final Widget? top;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A short fade so content slides under softly — but the bar itself
        // is solid, so nothing shows through behind its text.
        const IgnorePointer(
          child: SizedBox(
            height: Space.lg,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00121214), AppColors.background],
                ),
              ),
            ),
          ),
        ),
        ColoredBox(
          color: AppColors.background,
          child: Padding(
            padding: EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.md + bottomInset),
            child: ContentWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (top != null) ...[top!, Space.gap12],
                  child,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A rounded surface card with an optional outline.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.md),
    this.color = AppColors.surface,
    this.borderColor = AppColors.outlineSoft,
    this.radius = Radii.lgAll,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color? borderColor;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: child,
    );
  }
}
