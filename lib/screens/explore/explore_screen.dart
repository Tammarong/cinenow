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
import '../../models/movie.dart';
import '../../state/providers.dart';
import '../../widgets/layout.dart';
import '../../widgets/movie_card.dart';
import '../../widgets/shimmer_box.dart';
import '../../widgets/state_views.dart';

enum _StatusFilter { all, nowShowing, comingSoon }

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key, this.initialGenre, this.focusSearch = false});

  final String? initialGenre;
  final bool focusSearch;

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  String _query = '';
  String? _genre;
  _StatusFilter _status = _StatusFilter.all;

  @override
  void initState() {
    super.initState();
    _genre = widget.initialGenre;
    if (widget.focusSearch) WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void didUpdateWidget(covariant ExploreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialGenre != oldWidget.initialGenre && widget.initialGenre != null) {
      setState(() => _genre = widget.initialGenre);
    }
    if (widget.focusSearch && !oldWidget.focusSearch) _focus.requestFocus();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _query = value.trim().toLowerCase());
    });
    setState(() {}); // refresh the clear button
  }

  void _clearAll() {
    HapticFeedback.selectionClick();
    _search.clear();
    setState(() {
      _query = '';
      _genre = null;
      _status = _StatusFilter.all;
    });
  }

  List<Movie> _filter(List<Movie> movies) {
    return movies.where((m) {
      if (_status == _StatusFilter.nowShowing && !m.isNowShowing) return false;
      if (_status == _StatusFilter.comingSoon && !m.isComingSoon) return false;
      if (_genre != null && !m.genres.contains(_genre)) return false;
      if (_query.isNotEmpty) {
        final haystack = '${m.title} ${m.cast.map((c) => c.name).join(' ')}'.toLowerCase();
        if (!haystack.contains(_query)) return false;
      }
      return true;
    }).toList()..sort((a, b) {
      if (a.isNowShowing != b.isNowShowing) return a.isNowShowing ? -1 : 1;
      return (b.rating ?? 0).compareTo(a.rating ?? 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final movies = ref.watch(moviesProvider);
    final genres = ref.watch(genresProvider);
    final hasFilters = _query.isNotEmpty || _genre != null || _status != _StatusFilter.all;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(header: true, child: Text('Explore', style: AppText.h1)),
                      const SizedBox(height: 4),
                      Text('Find something worth the big screen.', style: AppText.bodyMuted),
                      Space.gap16,
                      _SearchField(
                        controller: _search,
                        focusNode: _focus,
                        onChanged: _onQueryChanged,
                        onClear: () {
                          _search.clear();
                          _onQueryChanged('');
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                      child: _StatusSegments(value: _status, onChanged: (v) => setState(() => _status = v)),
                    ),
                    Space.gap12,
                    SizedBox(
                      height: Space.touchTarget,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                        children: [
                          _GenreChip(
                            label: 'All genres',
                            selected: _genre == null,
                            onTap: () => setState(() => _genre = null),
                          ),
                          for (final g in genres)
                            _GenreChip(
                              label: g,
                              selected: _genre == g,
                              onTap: () => setState(() => _genre = _genre == g ? null : g),
                            ),
                        ],
                      ),
                    ),
                    Space.gap8,
                  ],
                ),
              ),
              ...switch (movies) {
                AsyncValue(hasValue: true, :final value?) => _results(_filter(value), hasFilters),
                AsyncValue(:final error?) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: ErrorState(message: friendlyError(error), onRetry: () => ref.invalidate(moviesProvider)),
                  ),
                ],
                _ => [_skeletonGrid(context)],
              },
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _results(List<Movie> results, bool hasFilters) {
    if (results.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.movie_filter_outlined,
            title: 'No matches',
            message: _query.isNotEmpty
                ? 'Nothing matches "${_search.text.trim()}"${_genre != null ? ' in $_genre' : ''}. Try another title or clear your filters.'
                : 'No ${_genre ?? ''} movies here right now. Try another genre.',
            actionLabel: 'Clear filters',
            onAction: _clearAll,
            compact: true,
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.sm),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              Semantics(
                liveRegion: true,
                child: Text('${results.length} ${results.length == 1 ? 'movie' : 'movies'}', style: AppText.caption),
              ),
              const Spacer(),
              if (hasFilters) TextButton(onPressed: _clearAll, child: const Text('Clear filters')),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) {
            final columns = posterGridColumns(constraints.crossAxisExtent);
            return SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: Space.md,
                mainAxisSpacing: Space.lg,
                childAspectRatio: 0.5,
              ),
              itemCount: results.length,
              itemBuilder: (context, i) {
                final m = results[i];
                return MovieCard(
                  key: ValueKey(m.id),
                  movie: m,
                  onTap: () => context.push('${Routes.movie(m.id)}?hero=card'),
                ).animate().fadeIn(delay: (40 * (i % 8)).ms, duration: Motion.slow).scaleXY(begin: 0.96, end: 1);
              },
            );
          },
        ),
      ),
    ];
  }

  Widget _skeletonGrid(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xl),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final columns = posterGridColumns(constraints.crossAxisExtent);
          final w = (constraints.crossAxisExtent - (columns - 1) * Space.md) / columns;
          return SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: Space.md,
              mainAxisSpacing: Space.lg,
              childAspectRatio: 0.5,
            ),
            itemCount: columns * 2,
            itemBuilder: (_, _) => ShimmerScope(child: PosterCardSkeleton(width: w)),
          );
        },
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: AppText.bodyLarge,
      decoration: InputDecoration(
        hintText: 'Search by title or cast',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(tooltip: 'Clear search', icon: const Icon(Icons.close_rounded), onPressed: onClear),
      ),
    );
  }
}

class _StatusSegments extends StatelessWidget {
  const _StatusSegments({required this.value, required this.onChanged});

  final _StatusFilter value;
  final ValueChanged<_StatusFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = {
      _StatusFilter.all: 'All',
      _StatusFilter.nowShowing: 'Now showing',
      _StatusFilter.comingSoon: 'Coming soon',
    };
    return Row(
      children: [
        for (final entry in labels.entries) ...[
          _Pill(
            label: entry.value,
            selected: value == entry.key,
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(entry.key);
            },
          ),
          if (entry.key != _StatusFilter.comingSoon) Space.gap8,
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.pillAll,
        child: AnimatedContainer(
          duration: Motion.medium,
          height: 40,
          constraints: const BoxConstraints(minWidth: Space.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.textPrimary : Colors.transparent,
            borderRadius: Radii.pillAll,
          ),
          child: Text(
            label,
            style: AppText.bodyStrong.copyWith(
              fontSize: 14,
              color: selected ? AppColors.background : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: Space.xs),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) {
          HapticFeedback.selectionClick();
          onTap();
        },
        labelStyle: AppText.bodyStrong.copyWith(
          fontSize: 14,
          color: selected ? AppColors.onAccent : AppColors.textPrimary,
        ),
        side: BorderSide(color: selected ? AppColors.accent : AppColors.outline),
      ),
    );
  }
}
