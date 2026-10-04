import 'dart:async';

import 'package:flutter/services.dart';
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
import '../../widgets/meta_chips.dart';
import '../../widgets/movie_card.dart';
import '../../widgets/poster_image.dart';
import '../../widgets/pressable.dart';
import '../../widgets/shimmer_box.dart';
import '../../widgets/state_views.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movies = ref.watch(moviesProvider);
    final featured = ref.watch(featuredProvider).value ?? const <Movie>[];
    final nowShowing = ref.watch(nowShowingProvider).value ?? const <Movie>[];
    final comingSoon = ref.watch(comingSoonProvider).value ?? const <Movie>[];

    void openMovie(Movie m, {String hero = 'card'}) => context.push('${Routes.movie(m.id)}?hero=$hero');

    final Widget content;
    if (movies.hasError && !movies.hasValue) {
      content = SliverFillRemaining(
        hasScrollBody: false,
        child: ErrorState(message: friendlyError(movies.error!), onRetry: () => ref.invalidate(moviesProvider)),
      );
    } else if (!movies.hasValue) {
      content = const SliverToBoxAdapter(child: _HomeSkeleton());
    } else {
      content = SliverList.list(
        children: [
          if (featured.isNotEmpty)
            _FeaturedCarousel(
              movies: featured,
              onOpen: (m) => openMovie(m, hero: 'featured'),
              onBook: (m) {
                ref.read(bookingProvider.notifier).startFor(m);
                context.push(Routes.showtimes(m.id));
              },
            ),
          Space.gap32,
          SectionHeader(
            title: 'Now Showing',
            subtitle: '${nowShowing.length} films in cinemas',
            actionLabel: 'See all',
            onAction: () => context.go(Routes.explore),
          ),
          Space.gap16,
          _MovieRail(
            movies: nowShowing,
            onTap: (m) => openMovie(m, hero: 'now'),
          ),
          Space.gap32,
          SectionHeader(title: 'Coming Soon', subtitle: 'Set a reminder for opening day'),
          Space.gap16,
          _MovieRail(
            movies: comingSoon,
            onTap: (m) => openMovie(m, hero: 'soon'),
          ),
          Space.gap32,
        ],
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.surfaceRaised,
            onRefresh: () async {
              ref.invalidate(moviesProvider);
              await ref.read(moviesProvider.future).catchError((_) => <Movie>[]);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                const SliverSafeArea(bottom: false, sliver: SliverToBoxAdapter(child: _Header())),
                content,
              ],
            ),
          ),
          // Keeps status-bar icons readable over scrolling posters.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.paddingOf(context).top,
            child: const IgnorePointer(child: ColoredBox(color: Color(0xEB121214))),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header: location · avatar · greeting · search
// ---------------------------------------------------------------------------

class _Header extends ConsumerWidget {
  const _Header();

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final city = ref.watch(locationProvider);
    final user = ref.watch(currentUserProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PressableScale(
                onTap: () => _showLocationSheet(context, ref),
                semanticLabel: 'Location: $city. Change location',
                borderRadius: Radii.pillAll,
                child: Container(
                  constraints: const BoxConstraints(minHeight: Space.touchTarget),
                  padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: Radii.pillAll,
                    border: Border.all(color: AppColors.outlineSoft),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_rounded, size: 18, color: AppColors.accent),
                      const SizedBox(width: 6),
                      Text(city, style: AppText.bodyStrong),
                      const SizedBox(width: 2),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              PressableScale(
                onTap: () => context.go(Routes.profile),
                semanticLabel: user == null ? 'Profile, signed out' : 'Profile, ${user.bestName}',
                borderRadius: Radii.pillAll,
                child: Container(
                  width: Space.touchTarget,
                  height: Space.touchTarget,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: user == null ? AppColors.outline : AppColors.accent, width: 1.6),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: user == null
                      ? const CircleAvatar(
                          backgroundColor: AppColors.surfaceRaised,
                          child: Icon(Icons.person_outline_rounded, size: 22, color: AppColors.textSecondary),
                        )
                      : CircleAvatar(
                          backgroundColor: AppColors.accentSoft,
                          child: Text(
                            Fmt.initials(user.bestName),
                            style: AppText.bodyStrong.copyWith(color: AppColors.accent, fontSize: 14),
                          ),
                        ),
                ),
              ),
            ],
          ),
          Space.gap24,
          Text(user == null ? _greeting() : '${_greeting()}, ${user.firstName}', style: AppText.bodyMuted),
          const SizedBox(height: 4),
          Semantics(header: true, child: Text('What are we watching\ntonight?', style: AppText.h1)),
          Space.gap16,
          PressableScale(
            onTap: () => context.go(Routes.exploreWith(focusSearch: true)),
            semanticLabel: 'Search movies',
            borderRadius: Radii.lgAll,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: Radii.lgAll,
                border: Border.all(color: AppColors.outlineSoft),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                  Space.gap12,
                  Expanded(
                    child: Text('Search movies, genres…', style: AppText.body.copyWith(color: AppColors.textTertiary)),
                  ),
                  const Icon(Icons.tune_rounded, color: AppColors.textTertiary, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLocationSheet(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final selected = ref.watch(locationProvider);
          final cities = ref.watch(configProvider).value?.cities ?? const ['Bangkok', 'Nonthaburi'];
          final cinemas = ref.watch(cinemasProvider).value ?? const [];
          return Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choose your city', style: AppText.h2),
                const SizedBox(height: 4),
                Text('We\'ll show nearby cinemas first.', style: AppText.bodyMuted),
                Space.gap16,
                for (final city in cities)
                  _CityTile(
                    city: city,
                    count: cinemas.where((c) => c.city == city).length,
                    selected: city == selected,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(locationProvider.notifier).set(city);
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CityTile extends StatelessWidget {
  const _CityTile({required this.city, required this.count, required this.selected, required this.onTap});

  final String city;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs),
      child: Material(
        color: selected ? AppColors.accentSoft : AppColors.surfaceRaised,
        borderRadius: Radii.mdAll,
        child: InkWell(
          borderRadius: Radii.mdAll,
          onTap: onTap,
          child: Semantics(
            selected: selected,
            child: Padding(
              padding: const EdgeInsets.all(Space.md),
              child: Row(
                children: [
                  Icon(Icons.location_city_rounded, color: selected ? AppColors.accent : AppColors.textSecondary),
                  Space.gap12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(city, style: AppText.bodyStrong),
                        Text('$count CineNow ${count == 1 ? 'cinema' : 'cinemas'}', style: AppText.caption),
                      ],
                    ),
                  ),
                  if (selected) const Icon(Icons.check_circle_rounded, color: AppColors.accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Featured carousel
// ---------------------------------------------------------------------------

class _FeaturedCarousel extends StatefulWidget {
  const _FeaturedCarousel({required this.movies, required this.onOpen, required this.onBook});

  final List<Movie> movies;
  final ValueChanged<Movie> onOpen;
  final ValueChanged<Movie> onBook;

  @override
  State<_FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<_FeaturedCarousel> {
  final _controller = PageController(viewportFraction: 0.86);
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_controller.hasClients) return;
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
      if (!(TickerMode.valuesOf(context).enabled)) return;
      final next = (_page + 1) % widget.movies.length;
      _controller.animateToPage(next, duration: Motion.emphasized, curve: Motion.curveEmphasized);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = (width * 0.86 * 1.08).clamp(300.0, 460.0);
    return Column(
      children: [
        SizedBox(
          height: height,
          child: NotificationListener<ScrollStartNotification>(
            onNotification: (n) {
              if (n.dragDetails != null) _restartTimer();
              return false;
            },
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.movies.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, index) => AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  var delta = 0.0;
                  if (_controller.position.haveDimensions) {
                    delta = (_controller.page ?? 0) - index;
                  } else {
                    delta = (_page - index).toDouble();
                  }
                  final scale = 1 - (delta.abs() * 0.07).clamp(0.0, 0.07);
                  return Transform.scale(
                    scale: scale,
                    child: _FeaturedCard(
                      movie: widget.movies[index],
                      parallax: delta.clamp(-1.0, 1.0),
                      onOpen: () => widget.onOpen(widget.movies[index]),
                      onBook: () => widget.onBook(widget.movies[index]),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Space.gap16,
        Semantics(
          label: 'Featured ${_page + 1} of ${widget.movies.length}',
          excludeSemantics: true,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.movies.length; i++)
                AnimatedContainer(
                  duration: Motion.medium,
                  curve: Motion.curve,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 22 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page ? AppColors.accent : AppColors.outline,
                    borderRadius: Radii.pillAll,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.movie, required this.parallax, required this.onOpen, required this.onBook});

  final Movie movie;
  final double parallax;
  final VoidCallback onOpen;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: PressableScale(
        onTap: onOpen,
        semanticLabel: 'Featured: ${movie.title}. ${movie.genres.join(', ')}. Open details',
        borderRadius: Radii.xlAll,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: Radii.xlAll,
            boxShadow: [
              BoxShadow(
                color: AppColors.fromHex(movie.accentHex).withValues(alpha: 0.25),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: Radii.xlAll,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: 'featured-poster-${movie.id}',
                  child: PosterImage(
                    url: movie.posterUrl,
                    title: movie.title,
                    accentHex: movie.accentHex,
                    borderRadius: BorderRadius.zero,
                    alignment: Alignment(parallax * 0.6, -0.2),
                    memCacheWidth: 900,
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00121214), Color(0x66121214), Color(0xF0121214)],
                      stops: [0.3, 0.55, 1],
                    ),
                  ),
                ),
                if (movie.tag != null)
                  Positioned(
                    top: Space.md,
                    left: Space.md,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: const BoxDecoration(color: AppColors.accent, borderRadius: Radii.pillAll),
                      child: Text(
                        movie.tag!.toUpperCase(),
                        style: AppText.label.copyWith(color: AppColors.onAccent, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                Positioned(
                  left: Space.md + 4,
                  right: Space.md + 4,
                  bottom: Space.md + 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie.title,
                        style: AppText.h1.copyWith(fontSize: 24),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Space.gap8,
                      Row(
                        children: [
                          RatingBadge(rating: movie.rating, compact: true, onImage: true),
                          Space.gap8,
                          Flexible(
                            child: Text(
                              '${movie.genres.take(2).join(' · ')}  ·  ${Fmt.duration(movie.durationMin)}',
                              style: AppText.caption.copyWith(color: AppColors.textPrimary.withValues(alpha: 0.85)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Space.gap16,
                      _BookPill(onTap: onBook),
                    ],
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

class _BookPill extends StatelessWidget {
  const _BookPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      semanticLabel: 'Book tickets',
      borderRadius: Radii.pillAll,
      child: Container(
        height: Space.touchTarget,
        padding: const EdgeInsets.symmetric(horizontal: Space.md + 4),
        decoration: const BoxDecoration(color: AppColors.accent, borderRadius: Radii.pillAll),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.confirmation_number_rounded, size: 18, color: AppColors.onAccent),
            Space.gap8,
            Text('Book tickets', style: AppText.button.copyWith(color: AppColors.onAccent, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rails & skeleton
// ---------------------------------------------------------------------------

class _MovieRail extends StatelessWidget {
  const _MovieRail({required this.movies, required this.onTap});

  final List<Movie> movies;
  final ValueChanged<Movie> onTap;

  @override
  Widget build(BuildContext context) {
    const cardWidth = 144.0;
    return SizedBox(
      height: cardWidth * 1.5 + 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        itemCount: movies.length,
        separatorBuilder: (_, _) => Space.gap16,
        itemBuilder: (context, i) => MovieCard(
          movie: movies[i],
          width: cardWidth,
          heroTagPrefix: movies[i].isComingSoon ? 'soon' : 'now',
          onTap: () => onTap(movies[i]),
        ).animate().fadeIn(delay: (60 * i).ms, duration: Motion.slow).slideX(begin: 0.15, end: 0, curve: Motion.curve),
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Semantics(
      label: 'Loading movies',
      child: ShimmerScope(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: ShimmerBox(height: (width * 0.86 * 1.08).clamp(300.0, 460.0), radius: Radii.xlAll),
            ),
            Space.gap32,
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Space.gutter),
              child: ShimmerBox(width: 160, height: 22, radius: Radii.smAll),
            ),
            Space.gap16,
            SizedBox(
              height: 280,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                itemCount: 4,
                separatorBuilder: (_, _) => Space.gap16,
                itemBuilder: (_, _) => const PosterCardSkeleton(width: 144),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
