import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/app_exceptions.dart';
import '../../core/utils/formatters.dart';
import '../../models/seat_layout.dart';
import '../../state/booking_controller.dart';
import '../../state/providers.dart';
import '../../widgets/booking_widgets.dart';
import '../../widgets/cine_button.dart';
import '../../widgets/layout.dart';
import '../../widgets/meta_chips.dart';
import '../../widgets/poster_image.dart';
import '../../widgets/state_views.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  bool _busy = false;

  bool _conflictDialogOpen = false;

  /// Set once our own booking succeeds, so our new seats showing up as
  /// "occupied" during the exit transition aren't mistaken for a conflict.
  bool _completed = false;

  /// Shared by the live seat listener and a rejected confirmation: drop the
  /// lost seats, explain what happened, and send the user back to the map.
  Future<void> _handleTakenSeats(List<String> taken) async {
    if (_conflictDialogOpen || !mounted) return;
    _conflictDialogOpen = true;
    HapticFeedback.heavyImpact();
    ref.read(bookingProvider.notifier).releaseTaken(taken.toSet());
    final message = taken.length == 1
        ? 'Seat ${taken.first} was just booked by someone else.'
        : 'Seats ${taken.join(', ')} were just booked by someone else.';
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.event_seat_rounded, color: AppColors.accent, size: 36),
        title: Text(taken.length == 1 ? 'That seat was just taken' : 'Those seats were just taken'),
        content: Text(
          '$message Nothing was booked and you haven\'t been charged. '
          'Your other seats are still selected — pick a replacement to continue.',
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onAccent,
              minimumSize: const Size(0, Space.touchTarget),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Choose new seats'),
          ),
        ],
      ),
    );
    _conflictDialogOpen = false;
    if (mounted && context.canPop()) context.pop();
  }

  Future<void> _signIn() async {
    final ok = await context.push<bool>(Routes.signIn(forBooking: true));
    if (ok == true && mounted) {
      showAppSnack(
        context,
        'You\'re signed in. Your seats are still selected — confirm when ready.',
        icon: Icons.check_circle_rounded,
      );
    }
  }

  Future<void> _confirm() async {
    final user = ref.read(currentUserProvider);
    final draft = ref.read(bookingProvider);
    if (user == null) return _signIn();
    if (!draft.isReadyForReview) return;
    if (draft.showtime!.hasStarted()) {
      showAppSnack(
        context,
        'This showtime has just started. Please choose a later session.',
        icon: Icons.schedule_rounded,
      );
      return;
    }

    setState(() => _busy = true);
    if (!await ref.read(ensureConnectedProvider)()) {
      if (mounted) {
        setState(() => _busy = false);
        showAppSnack(context, const OfflineException().message, icon: Icons.cloud_off_rounded);
      }
      return;
    }
    final config = ref.read(configProvider).value;
    final price = draft.price(bookingFeePerTicket: config?.bookingFeePerTicket ?? 10);
    try {
      final reservation = await ref.read(reservationServiceProvider).confirm(user: user, draft: draft, price: price);
      _completed = true;
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      final booking = ref.read(bookingProvider.notifier);
      context.go(Routes.confirmation, extra: reservation);
      // Clear the draft after the transition so this screen doesn't flash empty.
      Future.delayed(const Duration(milliseconds: 600), booking.reset);
    } on SeatConflictException catch (e) {
      if (mounted) setState(() => _busy = false);
      await _handleTakenSeats(e.seats);
    } on AppException catch (e) {
      if (mounted) showAppSnack(context, e.message, icon: Icons.error_outline_rounded);
    } catch (_) {
      if (mounted) {
        showAppSnack(
          context,
          'We couldn\'t confirm your reservation. Nothing was booked — please try again.',
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingProvider);
    final user = ref.watch(currentUserProvider);
    final online = ref.watch(isOnlineProvider);
    final isDemo = ref.watch(isDemoProvider);
    final config = ref.watch(configProvider).value;

    if (!draft.isReadyForReview) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.event_seat_outlined,
          title: 'No seats selected',
          message: 'Pick at least one seat to review your reservation.',
          actionLabel: 'Back',
          onAction: () => context.canPop() ? context.pop() : context.go(Routes.home),
        ),
      );
    }

    final movie = draft.movie!;
    final cinema = draft.cinema!;
    final showtime = draft.showtime!;
    final layout = draft.layout!;

    // Live availability: if someone books one of these seats while the user
    // is reviewing, tell them right away instead of failing on Confirm.
    ref.listen(occupiedSeatsProvider(showtime.id), (previous, next) {
      final occupied = next.value;
      if (occupied == null || _busy || _completed) return;
      final taken = ref.read(bookingProvider).seats.where(occupied.contains).toList();
      if (taken.isNotEmpty) _handleTakenSeats(taken);
    });
    final price = draft.price(bookingFeePerTicket: config?.bookingFeePerTicket ?? 10);
    final date = DateTime.tryParse(showtime.date) ?? showtime.startsAt;
    final seats = Fmt.sortSeats(draft.seats);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to seats',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Review reservation'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, 200),
            children: [
              ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MovieHeader(
                      title: movie.title,
                      posterUrl: movie.posterUrl,
                      backdropUrl: movie.backdropUrl,
                      accentHex: movie.accentHex,
                      format: showtime.format,
                      meta: '${Fmt.duration(movie.durationMin)} · ${movie.ageRating}',
                    ),
                    Space.gap16,
                    SurfaceCard(
                      child: Column(
                        children: [
                          InfoRow(
                            icon: Icons.theaters_rounded,
                            label: 'CINEMA',
                            value: cinema.name,
                            sublabel: cinema.address,
                          ),
                          InfoRow(
                            icon: Icons.calendar_today_rounded,
                            label: 'DATE & TIME',
                            value: '${Fmt.longDate(date)} · ${showtime.time}',
                            sublabel: Fmt.countdown(showtime.startsAt),
                          ),
                          InfoRow(
                            icon: Icons.meeting_room_outlined,
                            label: 'HALL',
                            value: '${showtime.hallName} · ${showtime.format}',
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: Space.xs),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: const BoxDecoration(
                                    color: AppColors.surfaceRaised,
                                    borderRadius: Radii.smAll,
                                  ),
                                  child: const Icon(Icons.event_seat_rounded, size: 18, color: AppColors.textSecondary),
                                ),
                                Space.gap12,
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('SEATS · ${seats.length}', style: AppText.label),
                                      Space.gap8,
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          for (final s in seats)
                                            _SeatChip(id: s, deluxe: layout.typeOf(s) == SeatType.deluxe),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(onPressed: () => context.pop(), child: const Text('Change')),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Space.gap16,
                    Text('Price breakdown', style: AppText.h3),
                    Space.gap8,
                    SurfaceCard(child: PriceBreakdownView(price: price)),
                    Space.gap16,
                    _Note(
                      icon: Icons.info_outline_rounded,
                      color: AppColors.textSecondary,
                      text:
                          'This is a reservation demo — no payment is taken in the app. '
                          'Seats are held for you once you confirm.',
                    ),
                    if (isDemo) ...[
                      Space.gap8,
                      const _Note(
                        icon: Icons.science_outlined,
                        color: AppColors.warning,
                        text: 'Demo mode: this reservation will be saved on this device only, not to Firebase.',
                      ),
                    ],
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
              top: user == null
                  ? Row(
                      children: [
                        const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textSecondary),
                        Space.gap8,
                        Expanded(child: Text('Sign in to confirm. Your seats stay selected.', style: AppText.caption)),
                      ],
                    )
                  : Column(
                      children: [
                        if (!online)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Space.xs),
                            child: Row(
                              children: [
                                const Icon(Icons.cloud_off_rounded, size: 16, color: AppColors.warning),
                                Space.gap8,
                                Expanded(
                                  child: Text(
                                    'Connection lost — we\'ll reconnect when you confirm.',
                                    style: AppText.caption.copyWith(color: AppColors.warning),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            Text('Total', style: AppText.bodyMuted),
                            const Spacer(),
                            Text(Fmt.baht(price.total), style: AppText.price),
                          ],
                        ),
                      ],
                    ),
              child: user == null
                  ? CineButton(label: 'Sign in to confirm', icon: Icons.login_rounded, onPressed: _signIn)
                  : CineButton(
                      label: 'Confirm Reservation',
                      icon: online ? Icons.check_circle_rounded : Icons.cloud_sync_rounded,
                      loading: _busy,
                      onPressed: _confirm,
                      semanticHint: online
                          ? 'Total ${Fmt.baht(price.total)}'
                          : 'You appear offline; we will try to reconnect first',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovieHeader extends StatelessWidget {
  const _MovieHeader({
    required this.title,
    required this.posterUrl,
    required this.backdropUrl,
    required this.accentHex,
    required this.format,
    required this.meta,
  });

  final String title;
  final String posterUrl;
  final String backdropUrl;
  final String accentHex;
  final String format;
  final String meta;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: Radii.lgAll,
      child: SizedBox(
        height: 140,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PosterImage(
              url: backdropUrl,
              title: title,
              accentHex: accentHex,
              borderRadius: BorderRadius.zero,
              showTitleOnFallback: false,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xF0121214), Color(0x66121214)])),
            ),
            Padding(
              padding: const EdgeInsets.all(Space.sm),
              child: Row(
                children: [
                  AspectRatio(
                    aspectRatio: 2 / 3,
                    child: PosterImage(
                      url: posterUrl,
                      title: title,
                      accentHex: accentHex,
                      borderRadius: Radii.mdAll,
                      memCacheWidth: 240,
                    ),
                  ),
                  Space.gap16,
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppText.h2, maxLines: 2, overflow: TextOverflow.ellipsis),
                        Space.gap8,
                        Row(
                          children: [
                            FormatBadge(format),
                            Space.gap8,
                            Text(meta, style: AppText.caption),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeatChip extends StatelessWidget {
  const _SeatChip({required this.id, required this.deluxe});

  final String id;
  final bool deluxe;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: deluxe ? AppColors.goldSoft : AppColors.accentSoft, borderRadius: Radii.smAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (deluxe) ...[const Icon(Icons.weekend_rounded, size: 14, color: AppColors.gold), const SizedBox(width: 4)],
          Text(id, style: AppText.bodyStrong.copyWith(fontSize: 14, color: deluxe ? AppColors.gold : AppColors.accent)),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.sm),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: Radii.mdAll),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          Space.gap12,
          Expanded(
            child: Text(text, style: AppText.caption.copyWith(color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
