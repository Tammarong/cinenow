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
import '../../models/seat_layout.dart';
import '../../state/booking_controller.dart';
import '../../state/providers.dart';
import '../../widgets/cine_button.dart';
import '../../widgets/layout.dart';
import '../../widgets/seat_map.dart';
import '../../widgets/state_views.dart';

class SeatSelectionScreen extends ConsumerWidget {
  const SeatSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(bookingProvider);
    final showtime = draft.showtime;
    if (showtime == null || draft.movie == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.event_seat_outlined,
          title: 'Pick a showtime first',
          message: 'Choose a movie and a time, then you can pick your seats here.',
          actionLabel: 'Browse movies',
          onAction: () => context.go(Routes.home),
        ),
      );
    }

    final layouts = ref.watch(layoutsProvider);
    final layout = draft.layout ?? layouts.value?[showtime.layoutId];
    if (draft.layout == null && layout != null) {
      Future.microtask(() => ref.read(bookingProvider.notifier).setLayout(layout));
    }
    final occupiedAsync = ref.watch(occupiedSeatsProvider(showtime.id));
    final occupied = occupiedAsync.value ?? const <String>{};
    final config = ref.watch(configProvider).value;
    final maxSeats = config?.maxSeatsPerBooking ?? 10;
    final online = ref.watch(isOnlineProvider);

    // Someone else booked a seat we'd picked: release it and say so kindly.
    // (While Review is on top, it handles this itself with a clearer dialog.)
    ref.listen(occupiedSeatsProvider(showtime.id), (previous, next) {
      final now = next.value;
      if (now == null || ModalRoute.of(context)?.isCurrent != true) return;
      final taken = ref.read(bookingProvider.notifier).releaseTaken(now);
      if (taken.isNotEmpty) {
        HapticFeedback.heavyImpact();
        showAppSnack(
          context,
          '${taken.length == 1 ? 'Seat ${taken.first} was' : 'Seats ${taken.join(', ')} were'} just booked by someone else. '
          'Please choose another.',
          icon: Icons.event_seat_rounded,
        );
      }
    });

    final price = draft.price(bookingFeePerTicket: config?.bookingFeePerTicket ?? 10);
    final date = DateTime.tryParse(showtime.date) ?? showtime.startsAt;

    void onSeatTap(String id) {
      final result = ref.read(bookingProvider.notifier).toggleSeat(id, occupied: occupied, maxSeats: maxSeats);
      switch (result) {
        case SeatToggle.selected:
          HapticFeedback.selectionClick();
        case SeatToggle.deselected:
          HapticFeedback.lightImpact();
        case SeatToggle.occupied:
          HapticFeedback.heavyImpact();
          showAppSnack(context, 'Seat $id is already taken. Pick an outlined seat.', icon: Icons.block_rounded);
        case SeatToggle.limitReached:
          HapticFeedback.heavyImpact();
          showAppSnack(context, 'You can book up to $maxSeats seats at a time.', icon: Icons.info_outline_rounded);
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select seats', style: AppText.h3),
            Text(
              '${showtime.hallName} · ${showtime.format} · ${Fmt.mediumDate(date)}, ${showtime.time}',
              style: AppText.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const Padding(padding: EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xs), child: SeatLegend()),
          if (!online)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.xs),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 16, color: AppColors.warning),
                  Space.gap8,
                  Expanded(
                    child: Text(
                      'Offline — availability may be out of date.',
                      style: AppText.caption.copyWith(color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          AnimatedOpacity(
            opacity: occupiedAsync.isLoading ? 1 : 0,
            duration: Motion.medium,
            child: const LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.transparent),
          ),
          Expanded(
            child: layout == null
                ? (layouts.hasError
                      ? ErrorState(
                          message: friendlyError(layouts.error!),
                          onRetry: () => ref.invalidate(layoutsProvider),
                          compact: true,
                        )
                      : const Center(child: CircularProgressIndicator()))
                : occupiedAsync.hasError && !occupiedAsync.hasValue
                ? ErrorState(
                    message: 'We couldn\'t load live seat availability. Check your connection and try again.',
                    onRetry: () => ref.invalidate(occupiedSeatsProvider(showtime.id)),
                    compact: true,
                  )
                : SeatMap(
                    layout: layout,
                    occupied: occupied,
                    selected: draft.seats,
                    onSeatTap: onSeatTap,
                    priceStandard: showtime.priceStandard,
                    priceDeluxe: showtime.priceDeluxe,
                  ).animate().fadeIn(duration: Motion.slow),
          ),
          _BottomPanel(
            seats: draft.seats,
            layout: layout,
            total: price.total,
            ticketsSubtotal: price.ticketsSubtotal,
            onRemove: onSeatTap,
            onContinue: draft.seats.isEmpty ? null : () => context.push(Routes.review),
          ),
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.seats,
    required this.layout,
    required this.total,
    required this.ticketsSubtotal,
    required this.onRemove,
    required this.onContinue,
  });

  final List<String> seats;
  final SeatLayout? layout;
  final int total;
  final int ticketsSubtotal;
  final ValueChanged<String> onRemove;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final sorted = Fmt.sortSeats(seats);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        border: const Border(top: BorderSide(color: AppColors.outlineSoft)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, -8)),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        Space.gutter,
        Space.md,
        Space.gutter,
        Space.md + MediaQuery.paddingOf(context).bottom,
      ),
      child: ContentWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      seats.isEmpty
                          ? 'Tap a seat to select it'
                          : '${seats.length} ${seats.length == 1 ? 'seat' : 'seats'} selected',
                      style: AppText.bodyStrong,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: Motion.medium,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Text(
                    Fmt.baht(ticketsSubtotal),
                    key: ValueKey(ticketsSubtotal),
                    style: AppText.price.copyWith(
                      color: seats.isEmpty ? AppColors.textTertiary : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: Motion.medium,
              curve: Motion.curve,
              alignment: Alignment.topCenter,
              child: seats.isEmpty
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: Space.sm),
                      child: SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: sorted.length,
                          separatorBuilder: (_, _) => Space.gap8,
                          itemBuilder: (context, i) {
                            final id = sorted[i];
                            final deluxe = layout?.typeOf(id) == SeatType.deluxe;
                            return InputChip(
                              label: Text(id),
                              avatar: deluxe
                                  ? const Icon(Icons.weekend_rounded, size: 16, color: AppColors.gold)
                                  : null,
                              onDeleted: () => onRemove(id),
                              deleteButtonTooltipMessage: 'Remove seat $id',
                              deleteIconColor: AppColors.textSecondary,
                              backgroundColor: AppColors.surfaceRaised,
                              side: BorderSide(
                                color: deluxe ? AppColors.gold.withValues(alpha: 0.6) : AppColors.outline,
                              ),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ).animate().fadeIn(duration: Motion.fast).scaleXY(begin: 0.85, end: 1);
                          },
                        ),
                      ),
                    ),
            ),
            Space.gap12,
            CineButton(
              label: seats.isEmpty ? 'Continue' : 'Continue · ${Fmt.baht(total)}',
              trailingIcon: Icons.arrow_forward_rounded,
              onPressed: onContinue,
              semanticHint: 'Includes booking fee',
            ),
          ],
        ),
      ),
    );
  }
}
