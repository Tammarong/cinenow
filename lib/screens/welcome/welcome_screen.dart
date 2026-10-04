import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../models/movie.dart';
import '../../state/preferences.dart';
import '../../state/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/cine_button.dart';
import '../../widgets/layout.dart';
import '../../widgets/poster_image.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movies = ref.watch(moviesProvider).value ?? const <Movie>[];

    Future<void> go(String location, {bool push = false}) async {
      await ref.read(welcomeSeenProvider.notifier).markSeen();
      if (!context.mounted) return;
      if (push) {
        final ok = await context.push<bool>(location);
        if (ok == true && context.mounted) context.go(Routes.home);
      } else {
        context.go(location);
      }
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _PosterWall(movies: movies),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66121214), Color(0x99121214), AppColors.background, AppColors.background],
                stops: [0, 0.38, 0.66, 1],
              ),
            ),
          ),
          // Warm coral bloom behind the headline.
          Positioned(
            left: -120,
            right: -120,
            bottom: 140,
            height: 320,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(colors: [AppColors.accent.withValues(alpha: 0.18), Colors.transparent]),
              ),
            ),
          ),
          SafeArea(
            child: ContentWidth(
              maxWidth: 520,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: Space.md),
                    const CineNowLogo(size: 24).animate().fadeIn(duration: Motion.slow),
                    const Spacer(),
                    Text(
                      'NOW SHOWING IN BANGKOK',
                      style: AppText.overline,
                    ).animate().fadeIn(delay: 150.ms, duration: Motion.slow).slideY(begin: 0.3, end: 0),
                    Space.gap12,
                    Text('Your best seat\nis waiting.', style: AppText.display.copyWith(fontSize: 38))
                        .animate()
                        .fadeIn(delay: 250.ms, duration: Motion.emphasized)
                        .slideY(begin: 0.2, end: 0, curve: Motion.curveEmphasized),
                    Space.gap12,
                    Text(
                      'Browse what\'s on, pick the perfect seat on a live map, and keep your tickets in one place.',
                      style: AppText.bodyLarge.copyWith(color: AppColors.textSecondary),
                    ).animate().fadeIn(delay: 380.ms, duration: Motion.emphasized),
                    Space.gap32,
                    CineButton(
                      label: 'Get started',
                      trailingIcon: Icons.arrow_forward_rounded,
                      onPressed: () => go(Routes.signUp(), push: true),
                    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.3, end: 0, curve: Motion.curve),
                    Space.gap12,
                    CineButton.secondary(
                      label: 'I have an account',
                      onPressed: () => go(Routes.signIn(), push: true),
                    ).animate().fadeIn(delay: 580.ms).slideY(begin: 0.3, end: 0, curve: Motion.curve),
                    Space.gap8,
                    Center(
                      child: CineButton.ghost(
                        label: 'Browse movies first',
                        icon: Icons.local_movies_outlined,
                        onPressed: () => go(Routes.home),
                      ),
                    ).animate().fadeIn(delay: 660.ms),
                    Space.gap8,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tilted columns of posters drifting in alternating directions.
class _PosterWall extends StatefulWidget {
  const _PosterWall({required this.movies});

  final List<Movie> movies;

  @override
  State<_PosterWall> createState() => _PosterWallState();
}

class _PosterWallState extends State<_PosterWall> with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(vsync: this, duration: const Duration(seconds: 60))
    ..repeat();

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final movies = widget.movies;
    if (movies.isEmpty) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.2,
            colors: [Color(0xFF2A1A18), AppColors.background],
          ),
        ),
      );
    }
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final width = MediaQuery.sizeOf(context).width;
    const columns = 4;
    final columnWidth = (width * 1.5) / columns;
    final tileHeight = columnWidth * 1.5 + Space.sm;

    List<Movie> columnMovies(int column) => [
      for (var i = 0; i < movies.length; i++) movies[(i + column * 3) % movies.length],
    ];

    return ExcludeSemantics(
      child: ClipRect(
        child: OverflowBox(
          maxWidth: width * 1.6,
          maxHeight: double.infinity,
          child: Transform.rotate(
            angle: -0.14,
            child: AnimatedBuilder(
              animation: _drift,
              builder: (context, _) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var c = 0; c < columns; c++)
                      _MarqueeColumn(
                        movies: columnMovies(c),
                        width: columnWidth,
                        tileHeight: tileHeight,
                        progress: reduceMotion ? 0 : (c.isEven ? _drift.value : 1 - _drift.value),
                        offset: c * tileHeight * 0.45,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MarqueeColumn extends StatelessWidget {
  const _MarqueeColumn({
    required this.movies,
    required this.width,
    required this.tileHeight,
    required this.progress,
    required this.offset,
  });

  final List<Movie> movies;
  final double width;
  final double tileHeight;
  final double progress;
  final double offset;

  @override
  Widget build(BuildContext context) {
    final loopHeight = tileHeight * movies.length;
    final dy = -(progress * loopHeight) - offset;
    return SizedBox(
      width: width,
      height: MediaQuery.sizeOf(context).height * 1.4,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          maxHeight: double.infinity,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Column(
              children: [
                for (var loop = 0; loop < 2; loop++)
                  for (final m in movies)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.xs / 2, vertical: Space.sm / 2),
                      child: SizedBox(
                        width: width - Space.xs,
                        height: tileHeight - Space.sm,
                        child: PosterImage(
                          url: m.posterUrl,
                          title: m.title,
                          accentHex: m.accentHex,
                          borderRadius: Radii.lgAll,
                          memCacheWidth: 360,
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
