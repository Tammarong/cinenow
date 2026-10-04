import 'dart:math' as math;

import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../models/reservation.dart';
import '../../widgets/cine_button.dart';
import '../../widgets/layout.dart';
import '../../widgets/state_views.dart';
import '../../widgets/ticket_card.dart';

class ConfirmationScreen extends StatelessWidget {
  const ConfirmationScreen({super.key, required this.reservation});

  final Reservation? reservation;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    if (r == null) {
      return Scaffold(
        body: SafeArea(
          child: EmptyState(
            icon: Icons.confirmation_number_outlined,
            title: 'Your tickets are safe',
            message: 'Find every reservation in My Tickets.',
            actionLabel: 'View My Tickets',
            onAction: () => context.go(Routes.tickets),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(Routes.home);
      },
      child: Scaffold(
        body: Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(
                Space.gutter,
                MediaQuery.paddingOf(context).top + Space.lg,
                Space.gutter,
                190,
              ),
              children: [
                ContentWidth(
                  maxWidth: 480,
                  child: Column(
                    children: [
                      const SuccessBurst(size: 132),
                      Space.gap16,
                      Semantics(
                        liveRegion: true,
                        header: true,
                        child: Text('You\'re all set!', style: AppText.h1, textAlign: TextAlign.center),
                      ).animate().fadeIn(delay: 650.ms, duration: Motion.slow).slideY(begin: 0.3, end: 0),
                      Space.gap8,
                      Text(
                        r.isDemo
                            ? 'Reservation saved on this device (demo mode — not sent to Firebase).'
                            : 'Reservation confirmed. Your ticket is saved to My Tickets.',
                        style: AppText.bodyMuted,
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 780.ms, duration: Motion.slow),
                      Space.gap24,
                      TicketCard(reservation: r)
                          .animate()
                          .fadeIn(delay: 900.ms, duration: Motion.emphasized)
                          .slideY(begin: 0.25, end: 0, curve: Motion.curveEmphasized, duration: Motion.emphasized),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: StickyBottomBar(
                child: Column(
                  children: [
                    CineButton(
                      label: 'View My Tickets',
                      icon: Icons.confirmation_number_rounded,
                      onPressed: () => context.go(Routes.tickets),
                    ),
                    Space.gap8,
                    CineButton.ghost(label: 'Back to Home', onPressed: () => context.go(Routes.home)),
                  ],
                ),
              ).animate().fadeIn(delay: 1100.ms),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated success mark: ring draws on, tick strokes in, confetti bursts.
class SuccessBurst extends StatefulWidget {
  const SuccessBurst({super.key, this.size = 120});

  final double size;

  @override
  State<SuccessBurst> createState() => _SuccessBurstState();
}

class _SuccessBurstState extends State<SuccessBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  late final List<_Particle> _particles = _makeParticles();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        _c.value = 1;
      } else {
        _c.forward();
      }
    });
  }

  List<_Particle> _makeParticles() {
    final rng = math.Random(7);
    const colors = [AppColors.accent, AppColors.gold, AppColors.textPrimary, AppColors.success, Color(0xFF6EC1FF)];
    return List.generate(26, (i) {
      final angle = (i / 26) * math.pi * 2 + rng.nextDouble() * 0.3;
      return _Particle(
        angle: angle,
        distance: 0.75 + rng.nextDouble() * 0.55,
        size: 3 + rng.nextDouble() * 4,
        color: colors[i % colors.length],
        isRect: i.isEven,
        spin: rng.nextDouble() * math.pi,
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Success',
      child: SizedBox(
        width: widget.size * 2,
        height: widget.size * 1.6,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            painter: _SuccessPainter(progress: _c.value, particles: _particles, size: widget.size),
          ),
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
    required this.isRect,
    required this.spin,
  });

  final double angle;
  final double distance;
  final double size;
  final Color color;
  final bool isRect;
  final double spin;
}

class _SuccessPainter extends CustomPainter {
  _SuccessPainter({required this.progress, required this.particles, required this.size});

  final double progress;
  final List<_Particle> particles;
  final double size;

  double _interval(double begin, double end, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((progress - begin) / (end - begin)).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final centre = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final radius = size / 2;

    // Soft glow (radial gradient rather than a blur filter — cheaper on GPUs).
    final glow = _interval(0.0, 0.5);
    final glowRadius = radius * (1.25 + 0.3 * glow);
    canvas.drawCircle(
      centre,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.32 * glow),
            AppColors.accent.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: centre, radius: glowRadius)),
    );

    // Filled disc pops in.
    final disc = _interval(0.25, 0.55, Curves.easeOutBack);
    canvas.drawCircle(centre, radius * 0.86 * disc, Paint()..color = AppColors.accent);

    // Ring draws around.
    final ring = _interval(0.0, 0.45);
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -math.pi / 2,
      math.pi * 2 * ring,
      false,
      Paint()
        ..color = AppColors.accent.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Tick strokes in.
    final tick = _interval(0.45, 0.75);
    if (tick > 0) {
      final path = Path()
        ..moveTo(centre.dx - radius * 0.34, centre.dy + radius * 0.02)
        ..lineTo(centre.dx - radius * 0.08, centre.dy + radius * 0.28)
        ..lineTo(centre.dx + radius * 0.38, centre.dy - radius * 0.24);
      final metric = path.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * tick),
        Paint()
          ..color = AppColors.onAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.13
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Confetti burst.
    final burst = _interval(0.4, 1.0, Curves.easeOutQuart);
    final fade = 1 - _interval(0.75, 1.0, Curves.easeIn);
    if (burst > 0 && fade > 0) {
      for (final p in particles) {
        final d = radius * (1.05 + p.distance * burst);
        final pos = centre + Offset(math.cos(p.angle) * d, math.sin(p.angle) * d + 18 * burst * burst);
        final paint = Paint()..color = p.color.withValues(alpha: fade);
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(p.spin + burst * 4);
        if (p.isRect) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: p.size * 1.8, height: p.size),
              const Radius.circular(1.5),
            ),
            paint,
          );
        } else {
          canvas.drawCircle(Offset.zero, p.size / 2, paint);
        }
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SuccessPainter old) => old.progress != progress;
}
