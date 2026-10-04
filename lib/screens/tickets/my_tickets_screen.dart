import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../models/reservation.dart';
import '../../state/providers.dart';
import '../../widgets/layout.dart';
import '../../widgets/shimmer_box.dart';
import '../../widgets/state_views.dart';
import '../../widgets/ticket_card.dart';

class MyTicketsScreen extends ConsumerStatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  ConsumerState<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends ConsumerState<MyTicketsScreen> {
  bool _showPast = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final reservations = ref.watch(reservationsProvider);

    final Widget body;
    if (user == null) {
      body = EmptyState(
        icon: Icons.confirmation_number_outlined,
        title: 'Your tickets live here',
        message: 'Sign in to see upcoming screenings and every ticket you\'ve booked.',
        actionLabel: 'Sign in',
        onAction: () => context.push(Routes.signIn()),
        secondaryLabel: 'Browse movies',
        onSecondary: () => context.go(Routes.home),
      );
    } else if (reservations.hasError && !reservations.hasValue) {
      body = ErrorState(
        message: friendlyError(reservations.error!),
        onRetry: () => ref.invalidate(reservationsProvider),
      );
    } else if (!reservations.hasValue) {
      body = const _TicketsSkeleton();
    } else {
      final all = reservations.value!;
      final upcoming = all.where((r) => r.isUpcoming()).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      final past = all.where((r) => !r.isUpcoming()).toList()..sort((a, b) => b.startsAt.compareTo(a.startsAt));
      body = Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: _Segments(
              showPast: _showPast,
              upcomingCount: upcoming.length,
              pastCount: past.length,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _showPast = v);
              },
            ),
          ),
          Space.gap16,
          Expanded(
            child: AnimatedSwitcher(
              duration: Motion.medium,
              child: KeyedSubtree(
                key: ValueKey(_showPast),
                child: _TicketList(
                  tickets: _showPast ? past : upcoming,
                  past: _showPast,
                  emptyState: _showPast
                      ? EmptyState(
                          icon: Icons.history_rounded,
                          title: 'No past screenings yet',
                          message: 'Films you\'ve seen will be kept here as a little cinema diary.',
                          compact: true,
                          actionLabel: upcoming.isNotEmpty ? 'See upcoming' : null,
                          onAction: () => setState(() => _showPast = false),
                        )
                      : EmptyState(
                          icon: Icons.local_activity_outlined,
                          title: 'No upcoming tickets',
                          message: 'Your next movie night is a few taps away.',
                          actionLabel: 'Browse movies',
                          onAction: () => context.go(Routes.home),
                          compact: true,
                        ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(header: true, child: Text('My Tickets', style: AppText.h1)),
                    const SizedBox(height: 4),
                    Text('Show your booking reference at the counter.', style: AppText.bodyMuted),
                  ],
                ),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketList extends StatelessWidget {
  const _TicketList({required this.tickets, required this.past, required this.emptyState});

  final List<Reservation> tickets;
  final bool past;
  final Widget emptyState;

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) return SingleChildScrollView(child: emptyState);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
      itemCount: tickets.length,
      separatorBuilder: (_, _) => Space.gap12,
      itemBuilder: (context, i) => TicketListCard(
        reservation: tickets[i],
        past: past,
        onTap: () => context.push(Routes.ticket(tickets[i].id), extra: tickets[i]),
      ).animate().fadeIn(delay: (50 * i).ms, duration: Motion.slow).slideY(begin: 0.08, end: 0),
    );
  }
}

class _Segments extends StatelessWidget {
  const _Segments({
    required this.showPast,
    required this.upcomingCount,
    required this.pastCount,
    required this.onChanged,
  });

  final bool showPast;
  final int upcomingCount;
  final int pastCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, int count, bool value) {
      final selected = showPast == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: '$label, $count',
          excludeSemantics: true,
          child: InkWell(
            borderRadius: Radii.pillAll,
            onTap: () => onChanged(value),
            child: SizedBox(
              height: Space.touchTarget,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: AppText.bodyStrong.copyWith(
                      color: selected ? AppColors.background : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedContainer(
                    duration: Motion.medium,
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.background.withValues(alpha: 0.15) : AppColors.surfaceRaised,
                      borderRadius: Radii.pillAll,
                    ),
                    child: Text(
                      '$count',
                      style: AppText.label.copyWith(color: selected ? AppColors.background : AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: Radii.pillAll,
        border: Border.all(color: AppColors.outlineSoft),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: Motion.medium,
            curve: Motion.curveEmphasized,
            alignment: showPast ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                height: Space.touchTarget,
                decoration: const BoxDecoration(color: AppColors.textPrimary, borderRadius: Radii.pillAll),
              ),
            ),
          ),
          Row(children: [seg('Upcoming', upcomingCount, false), seg('Past', pastCount, true)]),
        ],
      ),
    );
  }
}

class _TicketsSkeleton extends StatelessWidget {
  const _TicketsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        children: const [
          ShimmerBox(height: Space.touchTarget + 8, radius: Radii.pillAll),
          Space.gap16,
          ShimmerBox(height: 132, radius: Radii.lgAll),
          Space.gap12,
          ShimmerBox(height: 132, radius: Radii.lgAll),
        ],
      ),
    );
  }
}
