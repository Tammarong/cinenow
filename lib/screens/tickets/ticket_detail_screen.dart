import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../models/reservation.dart';
import '../../state/providers.dart';
import '../../widgets/booking_widgets.dart';
import '../../widgets/cine_button.dart';
import '../../widgets/layout.dart';
import '../../widgets/meta_chips.dart';
import '../../widgets/state_views.dart';
import '../../widgets/ticket_card.dart';

class TicketDetailScreen extends ConsumerWidget {
  const TicketDetailScreen({super.key, required this.reservationId, this.initial});

  final String reservationId;
  final Reservation? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(reservationsProvider).value?.where((r) => r.id == reservationId).firstOrNull;
    final r = live ?? initial;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.tickets),
        ),
        title: const Text('Your ticket'),
      ),
      body: r == null
          ? EmptyState(
              icon: Icons.confirmation_number_outlined,
              title: 'Ticket not found',
              message: 'It may belong to another account. Sign in with the account you booked with.',
              actionLabel: 'Go to My Tickets',
              onAction: () => context.go(Routes.tickets),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(
                Space.gutter,
                Space.xs,
                Space.gutter,
                Space.xl + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                ContentWidth(
                  maxWidth: 480,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          MetaTag(
                            r.isUpcoming() ? Fmt.countdown(r.startsAt) : 'Screened',
                            icon: r.isUpcoming() ? Icons.schedule_rounded : Icons.check_circle_outline_rounded,
                            color: r.isUpcoming() ? AppColors.accent : AppColors.textTertiary,
                            filled: true,
                          ),
                          if (r.isDemo) ...[
                            Space.gap8,
                            const MetaTag('Demo · on this device', color: AppColors.warning, filled: true),
                          ],
                        ],
                      ),
                      Space.gap16,
                      TicketCard(reservation: r, heroTag: 'ticket-poster-${r.id}'),
                      Space.gap24,
                      SurfaceCard(
                        child: Column(
                          children: [
                            InfoRow(
                              icon: Icons.place_outlined,
                              label: 'ADDRESS',
                              value: r.cinemaName,
                              sublabel: r.cinemaAddress,
                            ),
                            InfoRow(
                              icon: Icons.receipt_long_outlined,
                              label: 'TOTAL · PAY AT THE CINEMA',
                              value: Fmt.baht(r.total),
                              sublabel:
                                  'Includes ${Fmt.baht(r.bookingFee)} booking fee · no payment is taken in the app',
                            ),
                            InfoRow(
                              icon: Icons.history_rounded,
                              label: 'BOOKED',
                              value:
                                  '${Fmt.mediumDate(r.createdAt)} · ${r.createdAt.hour.toString().padLeft(2, '0')}:${r.createdAt.minute.toString().padLeft(2, '0')}',
                            ),
                          ],
                        ),
                      ),
                      Space.gap16,
                      CineButton.secondary(
                        label: 'Copy booking reference',
                        icon: Icons.copy_rounded,
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: r.ref));
                          if (context.mounted) showAppSnack(context, 'Copied ${r.ref}', icon: Icons.check_rounded);
                        },
                      ),
                      Space.gap8,
                      CineButton.ghost(
                        label: 'Copy cinema address',
                        icon: Icons.near_me_outlined,
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: '${r.cinemaName}, ${r.cinemaAddress}'));
                          if (context.mounted) {
                            showAppSnack(
                              context,
                              'Address copied — paste it into your maps app.',
                              icon: Icons.check_rounded,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
