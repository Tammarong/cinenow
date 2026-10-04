import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/formatters.dart';
import '../models/booking_draft.dart';
import '../models/cinema.dart';
import '../models/showtime.dart';
import 'meta_chips.dart';
import 'poster_image.dart';
import 'pressable.dart';

/// Persistent summary of what's being booked: poster, title, date · time.
class BookingSummaryBar extends StatelessWidget {
  const BookingSummaryBar({super.key, required this.draft, this.trailing});

  final BookingDraft draft;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final movie = draft.movie;
    if (movie == null) return const SizedBox.shrink();
    final showtime = draft.showtime;
    final date = draft.date;
    final parts = <String>[
      if (date != null) Fmt.mediumDate(date),
      if (showtime != null) showtime.time else 'Pick a time',
      if (showtime != null) showtime.format,
    ];
    return Container(
      padding: const EdgeInsets.all(Space.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: Radii.lgAll,
        border: Border.all(color: AppColors.outlineSoft),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 64,
            child: PosterImage(
              url: movie.posterUrl,
              title: movie.title,
              accentHex: movie.accentHex,
              borderRadius: Radii.smAll,
              showTitleOnFallback: false,
              memCacheWidth: 132,
            ),
          ),
          Space.gap12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(movie.title, style: AppText.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: Motion.medium,
                  child: Text(
                    parts.join('  ·  '),
                    key: ValueKey(parts.join()),
                    style: AppText.caption.copyWith(
                      color: showtime == null ? AppColors.textTertiary : AppColors.accent,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (draft.cinema != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${draft.cinema!.name}${showtime == null ? '' : ' · ${showtime.hallName}'}',
                    style: AppText.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Day pill for the horizontal date selector.
class DateChip extends StatelessWidget {
  const DateChip({super.key, required this.date, required this.selected, required this.onTap, this.hasShows = true});

  final DateTime date;
  final bool selected;
  final bool hasShows;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.onAccent : (hasShows ? AppColors.textPrimary : AppColors.textTertiary);
    return Semantics(
      selected: selected,
      button: true,
      label: '${Fmt.relativeDay(date)}, ${Fmt.longDate(date)}${hasShows ? '' : ', no showtimes'}',
      excludeSemantics: true,
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.curve,
          width: 64,
          padding: const EdgeInsets.symmetric(vertical: Space.sm),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : AppColors.surface,
            borderRadius: Radii.lgAll,
            border: Border.all(color: selected ? AppColors.accent : AppColors.outlineSoft),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Fmt.relativeDay(date) == 'Today' ? 'TODAY' : Fmt.dayShort(date).toUpperCase(),
                style: AppText.label.copyWith(color: fg.withValues(alpha: selected ? 1 : 0.75), fontSize: 11),
              ),
              const SizedBox(height: 4),
              Text(Fmt.dayNumber(date), style: AppText.h2.copyWith(color: fg)),
              const SizedBox(height: 2),
              Text(
                Fmt.monthShort(date),
                style: AppText.label.copyWith(color: fg.withValues(alpha: 0.75), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Time pill. Selected = coral fill, available = outline, unavailable =
/// dimmed + struck through with a reason ("Sold out" / "Started").
class ShowtimeChip extends StatelessWidget {
  const ShowtimeChip({super.key, required this.showtime, required this.selected, required this.onTap});

  final Showtime showtime;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final started = showtime.hasStarted();
    final available = showtime.isBookable();
    final reason = showtime.soldOut ? 'Sold out' : (started ? 'Started' : null);
    final fg = selected ? AppColors.onAccent : (available ? AppColors.textPrimary : AppColors.textTertiary);

    return Semantics(
      button: true,
      enabled: available,
      selected: selected,
      label: '${showtime.time}, ${showtime.format}${reason != null ? ', $reason' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.curve,
          constraints: const BoxConstraints(minWidth: 84, minHeight: Space.touchTarget + 4),
          padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : (available ? Colors.transparent : AppColors.surface),
            borderRadius: Radii.mdAll,
            border: Border.all(
              color: selected ? AppColors.accent : (available ? AppColors.outline : AppColors.outlineSoft),
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                showtime.time,
                style: AppText.bodyStrong.copyWith(
                  color: fg,
                  fontSize: 16,
                  decoration: available ? null : TextDecoration.lineThrough,
                  decorationColor: AppColors.textTertiary,
                ),
              ),
              Text(
                reason ?? Fmt.baht(showtime.priceStandard),
                style: AppText.label.copyWith(
                  color: selected ? AppColors.onAccent.withValues(alpha: 0.8) : AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A cinema with its showtimes for the selected day, grouped by format.
class CinemaShowtimesCard extends StatelessWidget {
  const CinemaShowtimesCard({
    super.key,
    required this.cinema,
    required this.showtimes,
    required this.selectedId,
    required this.onSelect,
  });

  final Cinema cinema;
  final List<Showtime> showtimes;
  final String? selectedId;
  final ValueChanged<Showtime> onSelect;

  @override
  Widget build(BuildContext context) {
    final byFormat = <String, List<Showtime>>{};
    for (final s in showtimes) {
      byFormat.putIfAbsent(s.format, () => []).add(s);
    }
    final hasSelection = showtimes.any((s) => s.id == selectedId);
    return AnimatedContainer(
      duration: Motion.medium,
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: Radii.lgAll,
        border: Border.all(color: hasSelection ? AppColors.accent.withValues(alpha: 0.6) : AppColors.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: AppColors.accentSoft, borderRadius: Radii.mdAll),
                child: const Icon(Icons.theaters_rounded, color: AppColors.accent, size: 22),
              ),
              Space.gap12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cinema.name, style: AppText.h3),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 14, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${cinema.area}, ${cinema.city}',
                            style: AppText.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          for (final entry in byFormat.entries) ...[
            Space.gap16,
            Row(
              children: [
                FormatBadge(entry.key),
                Space.gap8,
                Text(entry.value.first.hallName, style: AppText.caption),
              ],
            ),
            Space.gap12,
            Wrap(
              spacing: Space.xs,
              runSpacing: Space.xs,
              children: [
                for (final s in entry.value)
                  ShowtimeChip(showtime: s, selected: s.id == selectedId, onTap: () => onSelect(s)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Line-by-line price breakdown, ending with the total.
class PriceBreakdownView extends StatelessWidget {
  const PriceBreakdownView({super.key, required this.price});

  final PriceBreakdown price;

  @override
  Widget build(BuildContext context) {
    Widget line(String label, String value, {bool strong = false, Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: strong ? AppText.bodyStrong : AppText.bodyMuted)),
          Text(value, style: (strong ? AppText.price : AppText.bodyStrong).copyWith(color: color)),
        ],
      ),
    );
    return Column(
      children: [
        if (price.standardCount > 0)
          line(
            'Standard  ×${price.standardCount}  ·  ${Fmt.baht(price.priceStandard)}',
            Fmt.baht(price.standardSubtotal),
          ),
        if (price.deluxeCount > 0)
          line('Deluxe  ×${price.deluxeCount}  ·  ${Fmt.baht(price.priceDeluxe)}', Fmt.baht(price.deluxeSubtotal)),
        line('Booking fee  ×${price.tickets}  ·  ${Fmt.baht(price.bookingFeePerTicket)}', Fmt.baht(price.bookingFee)),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: Space.xs),
          child: Divider(),
        ),
        line('Total', Fmt.baht(price.total), strong: true, color: AppColors.textPrimary),
      ],
    );
  }
}

/// Key/value row used on review and ticket screens.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.icon, required this.label, required this.value, this.sublabel});

  final IconData icon;
  final String label;
  final String value;
  final String? sublabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(color: AppColors.surfaceRaised, borderRadius: Radii.smAll),
            child: Icon(icon, size: 18, color: AppColors.textSecondary),
          ),
          Space.gap12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.label),
                const SizedBox(height: 2),
                Text(value, style: AppText.bodyStrong),
                if (sublabel != null) Text(sublabel!, style: AppText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
