import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

enum CineButtonVariant { primary, secondary, ghost }

/// The app's one button. Primary = coral (one per screen), secondary =
/// outlined, ghost = text only. Shows a spinner while [loading].
class CineButton extends StatefulWidget {
  const CineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = CineButtonVariant.primary,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = true,
    this.height = 56,
    this.semanticHint,
  });

  const CineButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = true,
    this.height = 56,
    this.semanticHint,
  }) : variant = CineButtonVariant.secondary;

  const CineButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
    this.height = 48,
    this.semanticHint,
  }) : variant = CineButtonVariant.ghost;

  final String label;
  final VoidCallback? onPressed;
  final CineButtonVariant variant;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool loading;
  final bool expand;
  final double height;
  final String? semanticHint;

  @override
  State<CineButton> createState() => _CineButtonState();
}

class _CineButtonState extends State<CineButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (widget.variant) {
      CineButtonVariant.primary => (
        _enabled || widget.loading ? AppColors.accent : AppColors.surfaceRaised,
        _enabled || widget.loading ? AppColors.onAccent : AppColors.textTertiary,
        null,
      ),
      CineButtonVariant.secondary => (
        Colors.transparent,
        _enabled ? AppColors.textPrimary : AppColors.textTertiary,
        Border.all(color: _enabled ? AppColors.outline : AppColors.outlineSoft, width: 1.2),
      ),
      CineButtonVariant.ghost => (Colors.transparent, _enabled ? AppColors.accent : AppColors.textTertiary, null),
    };

    final content = AnimatedSwitcher(
      duration: Motion.fast,
      child: widget.loading
          ? SizedBox(
              key: const ValueKey('spinner'),
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[Icon(widget.icon, size: 20, color: fg), Space.gap8],
                // Full-width buttons may ellipsize; hugging buttons size to their label.
                if (widget.expand)
                  Flexible(
                    child: Text(
                      widget.label,
                      style: AppText.button.copyWith(color: fg),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  Text(widget.label, style: AppText.button.copyWith(color: fg), softWrap: false),
                if (widget.trailingIcon != null) ...[Space.gap8, Icon(widget.trailingIcon, size: 20, color: fg)],
              ],
            ),
    );

    final button = AnimatedContainer(
      duration: Motion.medium,
      curve: Motion.curve,
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: Space.lg),
      decoration: BoxDecoration(
        color: _pressed && widget.variant == CineButtonVariant.primary ? AppColors.accentPressed : bg,
        borderRadius: Radii.pillAll,
        border: border,
        boxShadow: widget.variant == CineButtonVariant.primary && _enabled
            ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.28), blurRadius: 24, offset: const Offset(0, 8))]
            : null,
      ),
      alignment: Alignment.center,
      child: content,
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      hint: widget.semanticHint,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTap: _enabled
            ? () {
                HapticFeedback.lightImpact();
                widget.onPressed!();
              }
            : null,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: Motion.fast,
          curve: Motion.curve,
          child: widget.expand ? SizedBox(width: double.infinity, child: button) : IntrinsicWidth(child: button),
        ),
      ),
    );
  }
}

/// Round icon button on a translucent disc — used over imagery.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({super.key, required this.icon, required this.onPressed, required this.tooltip});

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.background.withValues(alpha: 0.55),
        shape: const CircleBorder(side: BorderSide(color: Color(0x22FFFFFF))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                },
          child: SizedBox(width: Space.touchTarget, height: Space.touchTarget, child: Icon(icon, size: 22)),
        ),
      ),
    );
  }
}
