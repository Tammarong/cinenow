import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../models/movie.dart';
import '../../state/booking_controller.dart';
import '../../state/preferences.dart';
import '../../state/providers.dart';
import '../../widgets/cine_button.dart';
import '../../widgets/layout.dart';
import '../../widgets/meta_chips.dart';
import '../../widgets/poster_image.dart';
import '../../widgets/shimmer_box.dart';
import '../../widgets/state_views.dart';

class MovieDetailsScreen extends ConsumerWidget {
  const MovieDetailsScreen({super.key, required this.movieId, this.heroPrefix = 'card'});

  final String movieId;
  final String heroPrefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movie = ref.watch(movieProvider(movieId));
    return Scaffold(
      body: switch (movie) {
        AsyncValue(hasValue: true, value: final m?) => _Details(movie: m, heroTag: '$heroPrefix-poster-${m.id}'),
        AsyncValue(hasValue: true) => _missing(context),
        AsyncValue(:final error?) => SafeArea(
          child: ErrorState(message: friendlyError(error), onRetry: () => ref.invalidate(moviesProvider)),
        ),
        _ => const _DetailsSkeleton(),
      },
    );
  }

  Widget _missing(BuildContext context) => SafeArea(
    child: EmptyState(
      icon: Icons.movie_outlined,
      title: 'Movie not found',
      message: 'This title may have left cinemas. Let\'s find you something else.',
      actionLabel: 'Back to Home',
      onAction: () => context.go(Routes.home),
    ),
  );
}

class _Details extends ConsumerStatefulWidget {
  const _Details({required this.movie, required this.heroTag});

  final Movie movie;
  final String heroTag;

  @override
  ConsumerState<_Details> createState() => _DetailsState();
}

class _DetailsState extends ConsumerState<_Details> {
  final _scroll = ScrollController();
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final threshold = _backdropHeight(context) - 120;
      final collapsed = _scroll.offset > threshold;
      if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  static double _backdropHeight(BuildContext context) => (MediaQuery.sizeOf(context).width * 0.78).clamp(280.0, 440.0);

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    final backdropHeight = _backdropHeight(context);
    const posterHeight = 177.0;
    const overlap = 96.0;
    final topInset = MediaQuery.paddingOf(context).top;
    final reminded = ref.watch(remindersProvider).contains(movie.id);
    final release = movie.releaseDate;

    return Stack(
      children: [
        CustomScrollView(
          controller: _scroll,
          slivers: [
            // Backdrop with the poster + title overlapping its lower edge.
            SliverToBoxAdapter(
              child: SizedBox(
                height: backdropHeight + posterHeight - overlap,
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: backdropHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          PosterImage(
                            url: movie.backdropUrl,
                            title: movie.title,
                            accentHex: movie.accentHex,
                            borderRadius: BorderRadius.zero,
                            showTitleOnFallback: false,
                            semanticLabel: 'Scene from ${movie.title}',
                          ),
                          const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.backdropFade)),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ContentWidth(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                width: 118,
                                height: posterHeight,
                                decoration: BoxDecoration(
                                  borderRadius: Radii.lgAll,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.55),
                                      blurRadius: 28,
                                      offset: const Offset(0, 14),
                                    ),
                                  ],
                                ),
                                child: Hero(
                                  tag: widget.heroTag,
                                  child: PosterImage(
                                    url: movie.posterUrl,
                                    title: movie.title,
                                    accentHex: movie.accentHex,
                                    memCacheWidth: 400,
                                  ),
                                ),
                              ),
                              Space.gap16,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (movie.tag != null) ...[
                                      Text(movie.tag!.toUpperCase(), style: AppText.overline),
                                      const SizedBox(height: 6),
                                    ],
                                    Semantics(
                                      header: true,
                                      child: Text(
                                        movie.title,
                                        style: AppText.h1,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Space.gap8,
                                    Wrap(
                                      spacing: Space.xs,
                                      runSpacing: Space.xs,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        RatingBadge(rating: movie.rating),
                                        MetaTag(Fmt.duration(movie.durationMin), icon: Icons.schedule_rounded),
                                        MetaTag(movie.ageRating, color: AppColors.textPrimary),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: ContentWidth(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (movie.isComingSoon && release != null) ...[_ReleaseCallout(date: release), Space.gap16],
                      Wrap(
                        spacing: Space.xs,
                        runSpacing: Space.xs,
                        children: [
                          for (final g in movie.genres)
                            ActionChip(
                              label: Text(g),
                              tooltip: 'More $g movies',
                              onPressed: () => context.go(Routes.exploreWith(genre: g)),
                            ),
                        ],
                      ),
                      Space.gap24,
                      Text('Synopsis', style: AppText.h2),
                      Space.gap8,
                      _ExpandableText(movie.synopsis),
                      Space.gap24,
                      if (movie.cast.isNotEmpty) ...[Text('Cast', style: AppText.h2), Space.gap12],
                    ],
                  ),
                ),
              ),
            ),
            if (movie.cast.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 150,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                    itemCount: movie.cast.length,
                    separatorBuilder: (_, _) => Space.gap16,
                    itemBuilder: (context, i) {
                      final c = movie.cast[i];
                      return Semantics(
                        label: '${c.name} as ${c.character}',
                        excludeSemantics: true,
                        child: SizedBox(
                          width: 84,
                          child: Column(
                            children: [
                              NetworkAvatar(name: c.name, url: c.photoUrl, size: 72),
                              Space.gap8,
                              Text(
                                c.name,
                                style: AppText.label.copyWith(color: AppColors.textPrimary),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                c.character,
                                style: AppText.label.copyWith(fontSize: 11, fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: (50 * i).ms).slideX(begin: 0.2, end: 0);
                    },
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 130)),
          ],
        ),
        // Compact bar that fades in once the backdrop scrolls away.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _collapsed ? 1 : 0,
              duration: Motion.medium,
              child: Container(
                height: topInset + 64,
                padding: EdgeInsets.only(top: topInset, left: 76, right: Space.gutter),
                decoration: const BoxDecoration(
                  color: Color(0xF2121214),
                  border: Border(bottom: BorderSide(color: AppColors.outlineSoft)),
                ),
                alignment: Alignment.centerLeft,
                child: Text(movie.title, style: AppText.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
        ),
        Positioned(
          top: topInset + 8,
          left: Space.sm,
          child: GlassIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onPressed: () => context.canPop() ? context.pop() : context.go(Routes.home),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: StickyBottomBar(
            child: movie.isNowShowing
                ? CineButton(
                    label: 'Book Tickets',
                    icon: Icons.confirmation_number_rounded,
                    onPressed: () {
                      ref.read(bookingProvider.notifier).startFor(movie);
                      context.push(Routes.showtimes(movie.id));
                    },
                  )
                : CineButton(
                    label: reminded ? 'Reminder set' : 'Remind me',
                    variant: reminded ? CineButtonVariant.secondary : CineButtonVariant.primary,
                    icon: reminded ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                    onPressed: () async {
                      final on = await ref.read(remindersProvider.notifier).toggle(movie.id);
                      if (!context.mounted) return;
                      showAppSnack(
                        context,
                        on
                            ? 'Saved. ${movie.title} is on your watchlist on this device — check back on opening day.'
                            : 'Reminder removed.',
                        icon: on ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _ReleaseCallout extends StatelessWidget {
  const _ReleaseCallout({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final days = date.difference(DateTime.now()).inDays;
    return SurfaceCard(
      color: AppColors.accentSoft,
      borderColor: AppColors.accent.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(Space.sm),
      child: Row(
        children: [
          const Icon(Icons.event_rounded, color: AppColors.accent),
          Space.gap12,
          Expanded(
            child: Text(
              'In cinemas ${Fmt.releaseDate(date)}${days > 0 ? ' · $days days to go' : ''}',
              style: AppText.bodyStrong,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableText extends StatefulWidget {
  const _ExpandableText(this.text);

  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: AppText.bodyMuted),
          maxLines: 3,
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: Motion.slow,
              curve: Motion.curve,
              alignment: Alignment.topCenter,
              child: Text(
                widget.text,
                style: AppText.bodyMuted.copyWith(height: 1.6),
                maxLines: _expanded ? null : 3,
                overflow: _expanded ? TextOverflow.visible : TextOverflow.fade,
              ),
            ),
            if (overflows)
              TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_expanded ? 'Show less' : 'Read more'),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: Motion.medium,
                      child: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DetailsSkeleton extends StatelessWidget {
  const _DetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return ShimmerScope(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(height: (width * 0.78).clamp(280.0, 440.0), radius: BorderRadius.zero),
          const Padding(
            padding: EdgeInsets.all(Space.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 220, height: 28),
                Space.gap12,
                ShimmerBox(width: 160, height: 18),
                Space.gap24,
                ShimmerBox(height: 14),
                Space.gap8,
                ShimmerBox(height: 14),
                Space.gap8,
                ShimmerBox(width: 200, height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
