import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../models/cinema.dart';
import '../../models/showtime.dart';
import '../../state/booking_controller.dart';
import '../../state/preferences.dart';
import '../../state/providers.dart';
import '../../widgets/booking_widgets.dart';
import '../../widgets/cine_button.dart';
import '../../widgets/layout.dart';
import '../../widgets/shimmer_box.dart';
import '../../widgets/state_views.dart';

class ShowtimesScreen extends ConsumerStatefulWidget {
  const ShowtimesScreen({super.key, required this.movieId});

  final String movieId;

  @override
  ConsumerState<ShowtimesScreen> createState() => _ShowtimesScreenState();
}

class _ShowtimesScreenState extends ConsumerState<ShowtimesScreen> {
  final _dateScroll = ScrollController();
  bool _autoPicked = false;

  List<DateTime> get _dates {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return [for (var i = 0; i < bookingWindowDays; i++) today.add(Duration(days: i))];
  }

  @override
  void initState() {
    super.initState();
    // Deep links / restored routes: make sure the draft is for this movie.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final movie = ref.read(movieProvider(widget.movieId)).value;
      if (movie != null) ref.read(bookingProvider.notifier).startFor(movie);
    });
  }

  @override
  void dispose() {
    _dateScroll.dispose();
    super.dispose();
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  void _pickInitialDate(List<Showtime> showtimes) {
    if (_autoPicked) return;
    _autoPicked = true;
    final draft = ref.read(bookingProvider);
    if (draft.date != null && _dates.any((d) => _sameDay(d, draft.date!))) return;
    final firstBookable = _dates.firstWhere(
      (d) => showtimes.any((s) => s.date == Fmt.isoDate(d) && s.isBookable()),
      orElse: () => _dates.first,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(bookingProvider.notifier).selectDate(firstBookable);
    });
  }

  void _onShowtimeTap(Cinema cinema, Showtime s) {
    if (!s.isBookable()) {
      showAppSnack(
        context,
        s.soldOut ? 'The ${s.time} show is sold out. Try another time.' : 'The ${s.time} show has already started.',
        icon: Icons.event_busy_rounded,
      );
      return;
    }
    final layout = ref.read(layoutsProvider).value?[s.layoutId];
    ref.read(bookingProvider.notifier).selectShowtime(cinema, s, layout);
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingProvider);
    final showtimesAsync = ref.watch(showtimesProvider(widget.movieId));
    final cinemas = ref.watch(cinemasProvider);
    final city = ref.watch(locationProvider);
    ref.watch(layoutsProvider); // warm up seat layouts
    final selectedDate = draft.date ?? _dates.first;

    final Widget body;
    if (showtimesAsync.hasError || cinemas.hasError) {
      body = ErrorState(
        message: friendlyError(showtimesAsync.error ?? cinemas.error!),
        onRetry: () {
          ref.invalidate(showtimesProvider(widget.movieId));
          ref.invalidate(cinemasProvider);
        },
      );
    } else if (!showtimesAsync.hasValue || !cinemas.hasValue) {
      body = const _ListSkeleton();
    } else {
      final all = showtimesAsync.value!;
      _pickInitialDate(all);
      final day = all.where((s) => s.date == Fmt.isoDate(selectedDate)).toList();
      body = _CinemaList(
        cinemas: cinemas.value!,
        showtimes: day,
        city: city,
        selectedId: draft.showtime?.id,
        dateLabel: Fmt.relativeDay(selectedDate) == 'Today' ? 'today' : 'on ${Fmt.mediumDate(selectedDate)}',
        onSelect: _onShowtimeTap,
        onNextDay: () {
          final next = _dates.firstWhere(
            (d) => d.isAfter(selectedDate) && all.any((s) => s.date == Fmt.isoDate(d) && s.isBookable()),
            orElse: () => selectedDate,
          );
          ref.read(bookingProvider.notifier).selectDate(next);
        },
      );
    }

    final allShowtimes = showtimesAsync.value ?? const <Showtime>[];
    final st = draft.showtime;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Choose a showtime'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.md),
                child: ContentWidth(child: BookingSummaryBar(draft: draft)),
              ),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  controller: _dateScroll,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  itemCount: _dates.length,
                  separatorBuilder: (_, _) => Space.gap8,
                  itemBuilder: (context, i) {
                    final d = _dates[i];
                    return DateChip(
                      date: d,
                      selected: _sameDay(d, selectedDate),
                      hasShows:
                          allShowtimes.isEmpty || allShowtimes.any((s) => s.date == Fmt.isoDate(d) && s.isBookable()),
                      onTap: () => ref.read(bookingProvider.notifier).selectDate(d),
                    );
                  },
                ),
              ),
              Space.gap8,
              Expanded(
                child: AnimatedSwitcher(
                  duration: Motion.medium,
                  child: KeyedSubtree(key: ValueKey(selectedDate), child: body),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: StickyBottomBar(
              top: AnimatedSwitcher(
                duration: Motion.medium,
                child: st == null
                    ? Text('Pick a time to see the seat map', key: const ValueKey('hint'), style: AppText.caption)
                    : Row(
                        key: ValueKey(st.id),
                        children: [
                          Expanded(
                            child: Text(
                              '${draft.cinema?.name ?? ''} · ${st.hallName}',
                              style: AppText.caption.copyWith(color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text('from ${Fmt.baht(st.priceStandard)}', style: AppText.caption),
                        ],
                      ),
              ),
              child: CineButton(
                label: st == null ? 'Select a showtime' : 'Select seats · ${st.time}',
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: st == null ? null : () => context.push(Routes.seats),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CinemaList extends StatelessWidget {
  const _CinemaList({
    required this.cinemas,
    required this.showtimes,
    required this.city,
    required this.selectedId,
    required this.dateLabel,
    required this.onSelect,
    required this.onNextDay,
  });

  final List<Cinema> cinemas;
  final List<Showtime> showtimes;
  final String city;
  final String? selectedId;
  final String dateLabel;
  final void Function(Cinema, Showtime) onSelect;
  final VoidCallback onNextDay;

  @override
  Widget build(BuildContext context) {
    final byCinema = <Cinema, List<Showtime>>{};
    for (final c in cinemas) {
      final list = showtimes.where((s) => s.cinemaId == c.id).toList();
      if (list.isNotEmpty) byCinema[c] = list;
    }
    if (byCinema.isEmpty || !showtimes.any((s) => s.isBookable())) {
      return EmptyState(
        icon: Icons.event_busy_rounded,
        title: 'No more screenings $dateLabel',
        message: 'All sessions for this day have started or sold out. Later dates still have great seats.',
        actionLabel: 'See next available day',
        onAction: onNextDay,
        compact: true,
      );
    }
    final local = byCinema.keys.where((c) => c.city == city).toList();
    final others = byCinema.keys.where((c) => c.city != city).toList();

    Widget card(Cinema c, int i) => Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: CinemaShowtimesCard(
        cinema: c,
        showtimes: byCinema[c]!,
        selectedId: selectedId,
        onSelect: (s) => onSelect(c, s),
      ).animate().fadeIn(delay: (70 * i).ms, duration: Motion.slow).slideY(begin: 0.06, end: 0),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, 170),
      children: [
        ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (local.isNotEmpty) ...[
                _GroupLabel('In $city · ${local.length} ${local.length == 1 ? 'cinema' : 'cinemas'}'),
                for (var i = 0; i < local.length; i++) card(local[i], i),
              ],
              if (others.isNotEmpty) ...[
                _GroupLabel(local.isEmpty ? 'No screenings in $city — nearby cities' : 'Other cities'),
                for (var i = 0; i < others.length; i++) card(others[i], local.length + i),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.sm, top: Space.xs),
    child: Text(text.toUpperCase(), style: AppText.label.copyWith(letterSpacing: 1)),
  );
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.xs),
        children: const [
          ShimmerBox(height: 190, radius: Radii.lgAll),
          Space.gap16,
          ShimmerBox(height: 190, radius: Radii.lgAll),
          Space.gap16,
          ShimmerBox(height: 140, radius: Radii.lgAll),
        ],
      ),
    );
  }
}
