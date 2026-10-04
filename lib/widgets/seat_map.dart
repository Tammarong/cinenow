import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/formatters.dart';
import '../models/seat_layout.dart';

enum SeatState { available, selected, occupied }

/// Full seat map: curved screen, row labels on both sides, aisles, and a
/// pinch-zoomable canvas with zoom buttons. At 100% zoom every seat is a 48dp
/// touch target; the map opens zoomed-to-fit so the whole hall is visible.
class SeatMap extends StatefulWidget {
  const SeatMap({
    super.key,
    required this.layout,
    required this.occupied,
    required this.selected,
    required this.onSeatTap,
    required this.priceStandard,
    required this.priceDeluxe,
  });

  final SeatLayout layout;
  final Set<String> occupied;
  final List<String> selected;
  final ValueChanged<String> onSeatTap;
  final int priceStandard;
  final int priceDeluxe;

  static const double cell = 48;
  static const double aisle = 22;
  static const double label = 30;
  static const double screenHeight = 86;
  static const double deluxeGap = 26;

  @override
  State<SeatMap> createState() => _SeatMapState();
}

class _SeatMapState extends State<SeatMap> with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final AnimationController _anim = AnimationController(vsync: this, duration: Motion.slow);
  Animation<Matrix4>? _zoomAnimation;
  double _fitScale = 1;
  Size _viewport = Size.zero;
  bool _showHint = true;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      if (_zoomAnimation != null) _transform.value = _zoomAnimation!.value;
    });
    _hintTimer = Timer(const Duration(seconds: 5), _hideHint);
  }

  void _hideHint() {
    if (_showHint && mounted) setState(() => _showHint = false);
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _anim.dispose();
    _transform.dispose();
    super.dispose();
  }

  double get _contentWidth {
    var widest = 0.0;
    for (final row in widget.layout.rows) {
      final w = row.seats * SeatMap.cell + row.aisleAfter.length * SeatMap.aisle;
      widest = math.max(widest, w);
    }
    return widest + SeatMap.label * 2 + Space.md * 2;
  }

  double get _contentHeight {
    final hasDeluxe = widget.layout.rows.any((r) => r.type == SeatType.deluxe);
    return SeatMap.screenHeight +
        widget.layout.rows.length * SeatMap.cell +
        (hasDeluxe ? SeatMap.deluxeGap + 18 : 0) +
        Space.lg;
  }

  Matrix4 _matrixFor(double scale, {Offset focal = Offset.zero}) {
    // Keep the content horizontally centred when it's narrower than the viewport.
    final scaledWidth = _contentWidth * scale;
    final dxCentre = scaledWidth < _viewport.width ? (_viewport.width - scaledWidth) / 2 : null;
    var dx = dxCentre ?? -(focal.dx * scale - _viewport.width / 2);
    var dy = -(focal.dy * scale - _viewport.height / 2);
    if (dxCentre == null) dx = dx.clamp(_viewport.width - scaledWidth, 0.0);
    final scaledHeight = _contentHeight * scale;
    // Small halls sit a little above centre instead of hugging the top.
    dy = scaledHeight < _viewport.height
        ? (_viewport.height - scaledHeight) * 0.3
        : dy.clamp(_viewport.height - scaledHeight, 0.0);
    return Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _animateTo(Matrix4 target) {
    _zoomAnimation = Matrix4Tween(
      begin: _transform.value,
      end: target,
    ).animate(CurvedAnimation(parent: _anim, curve: Motion.curveEmphasized));
    _anim.forward(from: 0);
  }

  double get _currentScale => _transform.value.getMaxScaleOnAxis();

  void _zoom(double factor) {
    _hideHint();
    final target = (_currentScale * factor).clamp(_fitScale, 1.4);
    // Zoom around the centre of what's currently visible.
    final inverse = Matrix4.inverted(_transform.value);
    final centre = MatrixUtils.transformPoint(inverse, Offset(_viewport.width / 2, _viewport.height / 2));
    _animateTo(_matrixFor(target, focal: centre));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final fit = math.min(1.0, viewport.width / _contentWidth);
        if (viewport != _viewport || fit != _fitScale) {
          final firstLayout = _viewport == Size.zero;
          _viewport = viewport;
          _fitScale = fit;
          if (firstLayout || _currentScale < fit) _transform.value = _matrixFor(fit);
        }

        return Stack(
          children: [
            // No double-tap-to-zoom: it would delay every single seat tap by
            // ~300ms while the gesture arena waits for a second tap.
            InteractiveViewer(
              transformationController: _transform,
              onInteractionStart: (_) => _hideHint(),
              constrained: false,
              minScale: _fitScale,
              maxScale: 1.4,
              boundaryMargin: const EdgeInsets.all(Space.xl),
              child: SizedBox(
                width: _contentWidth,
                height: _contentHeight,
                child: _SeatCanvas(
                  layout: widget.layout,
                  occupied: widget.occupied,
                  selected: widget.selected,
                  onSeatTap: widget.onSeatTap,
                  priceStandard: widget.priceStandard,
                  priceDeluxe: widget.priceDeluxe,
                ),
              ),
            ),
            // Big halls open zoomed out; tell people they can enlarge seats.
            if (_fitScale < 0.75)
              Positioned(
                top: Space.xs,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _showHint ? 1 : 0,
                    duration: Motion.slow,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceRaised.withValues(alpha: 0.95),
                          borderRadius: Radii.pillAll,
                          border: Border.all(color: AppColors.outline),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.pinch_rounded, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text('Pinch or tap + to enlarge seats', style: AppText.caption.copyWith(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              right: Space.sm,
              bottom: Space.sm,
              child: _ZoomControls(
                onZoomIn: () => _zoom(1.5),
                onZoomOut: () => _zoom(1 / 1.5),
                onFit: () {
                  _hideHint();
                  _animateTo(_matrixFor(_fitScale));
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SeatCanvas extends StatelessWidget {
  const _SeatCanvas({
    required this.layout,
    required this.occupied,
    required this.selected,
    required this.onSeatTap,
    required this.priceStandard,
    required this.priceDeluxe,
  });

  final SeatLayout layout;
  final Set<String> occupied;
  final List<String> selected;
  final ValueChanged<String> onSeatTap;
  final int priceStandard;
  final int priceDeluxe;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    var deluxeHeaderShown = false;
    for (final row in layout.rows) {
      if (row.type == SeatType.deluxe && !deluxeHeaderShown) {
        deluxeHeaderShown = true;
        rows.add(
          Padding(
            padding: const EdgeInsets.only(top: SeatMap.deluxeGap - 8, bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.weekend_rounded, size: 14, color: AppColors.gold),
                const SizedBox(width: 6),
                Text('DELUXE · ${Fmt.baht(priceDeluxe)}', style: AppText.label.copyWith(color: AppColors.gold)),
              ],
            ),
          ),
        );
      }
      rows.add(
        SizedBox(
          height: SeatMap.cell,
          child: Row(
            children: [
              _RowLabel(row.label),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var n = 1; n <= row.seats; n++) ...[
                      _seat(row, '${row.label}$n'),
                      if (row.aisleAfter.contains(n)) const SizedBox(width: SeatMap.aisle),
                    ],
                  ],
                ),
              ),
              _RowLabel(row.label),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      child: Column(
        children: [
          const SizedBox(height: SeatMap.screenHeight, child: CurvedScreen()),
          ...rows,
        ],
      ),
    );
  }

  Widget _seat(SeatRow row, String id) {
    final state = selected.contains(id)
        ? SeatState.selected
        : occupied.contains(id)
        ? SeatState.occupied
        : SeatState.available;
    final price = row.type == SeatType.deluxe ? priceDeluxe : priceStandard;
    return SeatTile(
      id: id,
      state: state,
      type: row.type,
      semanticLabel:
          'Seat $id, ${row.type.label} ${Fmt.baht(price)}, '
          '${switch (state) {
            SeatState.available => 'available',
            SeatState.selected => 'selected',
            SeatState.occupied => 'occupied',
          }}',
      onTap: () => onSeatTap(id),
    );
  }
}

class _RowLabel extends StatelessWidget {
  const _RowLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: SeatMap.label,
    child: ExcludeSemantics(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppText.label.copyWith(color: AppColors.textTertiary),
      ),
    ),
  );
}

/// One seat. Distinct by colour *and* symbol: outline (available),
/// coral + ✓ (selected), dark + ✕ (occupied); deluxe seats are gold-edged.
class SeatTile extends StatelessWidget {
  const SeatTile({
    super.key,
    required this.id,
    required this.state,
    required this.type,
    required this.onTap,
    this.semanticLabel,
    this.size = SeatMap.cell,
    this.interactive = true,
  });

  final String id;
  final SeatState state;
  final SeatType type;
  final VoidCallback onTap;
  final String? semanticLabel;
  final double size;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final deluxe = type == SeatType.deluxe;
    final (fill, border, mark) = switch (state) {
      SeatState.selected => (AppColors.accent, AppColors.accent, AppColors.onAccent),
      SeatState.occupied => (AppColors.seatOccupied, AppColors.seatOccupied, AppColors.seatOccupiedMark),
      SeatState.available => (
        deluxe ? AppColors.goldSoft : Colors.transparent,
        deluxe ? AppColors.gold.withValues(alpha: 0.85) : const Color(0xFF55555E),
        Colors.transparent,
      ),
    };
    final seatW = size * (deluxe ? 0.8 : 0.7);
    final seatH = size * 0.62;

    final visual = TweenAnimationBuilder<double>(
      key: ValueKey(state),
      tween: Tween(begin: state == SeatState.selected ? 0.7 : 1, end: 1),
      duration: Motion.slow,
      curve: Motion.curveBounce,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: Motion.medium,
            curve: Motion.curve,
            width: seatW,
            height: seatH,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.vertical(top: Radius.circular(seatH * 0.42), bottom: const Radius.circular(4)),
              border: Border.all(color: border, width: 1.5),
              boxShadow: state == SeatState.selected
                  ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.45), blurRadius: 12)]
                  : null,
            ),
            alignment: Alignment.center,
            child: switch (state) {
              SeatState.selected => Icon(Icons.check_rounded, size: seatH * 0.62, color: mark),
              SeatState.occupied => Icon(Icons.close_rounded, size: seatH * 0.55, color: mark),
              SeatState.available => null,
            },
          ),
          const SizedBox(height: 2),
          // Seat base / armrest line.
          AnimatedContainer(
            duration: Motion.medium,
            width: seatW * 0.86,
            height: 3,
            decoration: BoxDecoration(color: border.withValues(alpha: 0.9), borderRadius: Radii.pillAll),
          ),
        ],
      ),
    );

    if (!interactive) {
      return SizedBox(width: size, height: size, child: Center(child: visual));
    }

    return Semantics(
      button: true,
      enabled: state != SeatState.occupied,
      selected: state == SeatState.selected,
      label: semanticLabel ?? 'Seat $id',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: visual),
        ),
      ),
    );
  }
}

/// The curved, softly glowing cinema screen.
class CurvedScreen extends StatelessWidget {
  const CurvedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: CustomPaint(painter: _ScreenPainter(), size: Size.infinite),
        ),
        Text('SCREEN', style: AppText.label.copyWith(color: AppColors.textTertiary, letterSpacing: 6)),
        const SizedBox(height: Space.sm),
      ],
    );
  }
}

class _ScreenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final inset = w * 0.08;
    final top = size.height * 0.35;
    final path = Path()
      ..moveTo(inset, top + 18)
      ..quadraticBezierTo(w / 2, top - 14, w - inset, top + 18);

    // Light spilling towards the seats.
    final glow = Path()
      ..moveTo(inset, top + 18)
      ..quadraticBezierTo(w / 2, top - 14, w - inset, top + 18)
      ..lineTo(w - inset * 1.6, size.height)
      ..lineTo(inset * 1.6, size.height)
      ..close();
    canvas.drawPath(
      glow,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.accent.withValues(alpha: 0.18), AppColors.accent.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, top, w, size.height - top)),
    );

    // Coral line that fades out at both ends.
    Shader lineShader(double alpha) => LinearGradient(
      colors: [
        AppColors.accent.withValues(alpha: 0),
        AppColors.accent.withValues(alpha: alpha * 0.8),
        AppColors.accent.withValues(alpha: alpha),
        AppColors.accent.withValues(alpha: alpha * 0.8),
        AppColors.accent.withValues(alpha: 0),
      ],
      stops: const [0, 0.18, 0.5, 0.82, 1],
    ).createShader(Rect.fromLTWH(0, 0, w, size.height));

    // Soft halo from layered translucent strokes, then the crisp line. No
    // blur mask filter: cheaper, and safe on every GPU / software renderer.
    for (final (width, alpha) in const [(18.0, 0.07), (12.0, 0.12), (8.0, 0.2), (4.0, 1.0)]) {
      canvas.drawPath(
        path,
        Paint()
          ..shader = lineShader(alpha)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = width,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({required this.onZoomIn, required this.onZoomOut, required this.onFit});

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String tip, VoidCallback onTap) => IconButton(
      tooltip: tip,
      onPressed: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      icon: Icon(icon, size: 20),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised.withValues(alpha: 0.92),
        borderRadius: Radii.pillAll,
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.remove_rounded, 'Zoom out', onZoomOut),
          button(Icons.fit_screen_rounded, 'Fit whole hall', onFit),
          button(Icons.add_rounded, 'Zoom in', onZoomIn),
        ],
      ),
    );
  }
}

/// Legend explaining every seat state with the same visuals as the map.
class SeatLegend extends StatelessWidget {
  const SeatLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(SeatState state, SeatType type, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SeatTile(id: label, state: state, type: type, onTap: () {}, size: 26, interactive: false),
        const SizedBox(width: 4),
        Text(label, style: AppText.caption),
      ],
    );
    return Semantics(
      label:
          'Legend: outlined seats are available, coral seats with a tick are selected, '
          'dark seats with a cross are taken, gold-edged seats are Deluxe.',
      excludeSemantics: true,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: Space.md,
        runSpacing: Space.xs,
        children: [
          item(SeatState.available, SeatType.standard, 'Available'),
          item(SeatState.selected, SeatType.standard, 'Selected'),
          item(SeatState.occupied, SeatType.standard, 'Taken'),
          item(SeatState.available, SeatType.deluxe, 'Deluxe'),
        ],
      ),
    );
  }
}
