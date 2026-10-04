import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/formatters.dart';
import '../models/reservation.dart';
import 'meta_chips.dart';
import 'poster_image.dart';
import 'pressable.dart';

/// Full digital ticket: backdrop + details, a perforated tear line with
/// side notches, then the (demo) QR and booking reference.
class TicketCard extends StatelessWidget {
  const TicketCard({super.key, required this.reservation, this.heroTag});

  final Reservation reservation;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final date = DateTime.tryParse(r.date) ?? r.startsAt;
    final top = ClipPath(
      clipper: const _TicketHalfClipper(notchAtBottom: true),
      child: ColoredBox(
        color: AppColors.surfaceRaised,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PosterImage(
                    url: r.backdropUrl,
                    title: r.movieTitle,
                    borderRadius: BorderRadius.zero,
                    showTitleOnFallback: false,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x0026262A), Color(0xCC26262A), AppColors.surfaceRaised],
                        stops: [0.2, 0.75, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: Space.md,
                    bottom: 0,
                    right: Space.md,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          width: 64,
                          height: 96,
                          decoration: BoxDecoration(
                            borderRadius: Radii.mdAll,
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 16)],
                          ),
                          child: heroTag == null ? _poster(r) : Hero(tag: heroTag!, child: _poster(r)),
                        ),
                        Space.gap12,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.movieTitle, style: AppText.h2, maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  FormatBadge(r.format),
                                  Space.gap8,
                                  Text(r.hallName, style: AppText.caption),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.lg),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _Field(label: 'DATE', value: Fmt.mediumDate(date)),
                      ),
                      Expanded(
                        child: _Field(label: 'TIME', value: r.time),
                      ),
                      Expanded(
                        child: _Field(label: 'TICKETS', value: '${r.seats.length}'),
                      ),
                    ],
                  ),
                  Space.gap16,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _Field(label: 'CINEMA', value: r.cinemaName),
                      ),
                      Expanded(
                        child: _Field(label: 'TOTAL', value: Fmt.baht(r.total)),
                      ),
                    ],
                  ),
                  Space.gap16,
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('SEATS', style: AppText.label.copyWith(color: AppColors.textTertiary)),
                  ),
                  Space.gap8,
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(spacing: 6, runSpacing: 6, children: [for (final s in r.seats) _SeatPill(s)]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final bottom = ClipPath(
      clipper: const _TicketHalfClipper(notchAtBottom: false),
      child: Container(
        color: AppColors.surfaceRaised,
        padding: const EdgeInsets.fromLTRB(Space.md, Space.lg, Space.md, Space.md),
        child: Row(
          children: [
            DemoQr(data: 'CINENOW-DEMO|${r.ref}|${r.showtimeId}|${r.seats.join(',')}'),
            Space.gap16,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('BOOKING REFERENCE', style: AppText.label.copyWith(color: AppColors.textTertiary)),
                  const SizedBox(height: 4),
                  SelectableText(r.ref, style: AppText.h2.copyWith(letterSpacing: 1.5)),
                  Space.gap8,
                  Text(
                    r.isDemo ? 'Saved on this device (demo mode)' : 'Show this reference at the counter',
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      container: true,
      label:
          'Ticket ${r.ref}: ${r.movieTitle}, ${Fmt.longDate(date)} at ${r.time}, '
          '${r.cinemaName}, ${r.hallName}, seats ${r.seats.join(', ')}',
      child: Column(children: [top, const _Perforation(), bottom]),
    );
  }

  Widget _poster(Reservation r) => PosterImage(
    url: r.posterUrl,
    title: r.movieTitle,
    borderRadius: Radii.mdAll,
    showTitleOnFallback: false,
    memCacheWidth: 200,
  );
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label.copyWith(color: AppColors.textTertiary)),
        const SizedBox(height: 4),
        Text(value, style: AppText.bodyStrong, maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _SeatPill extends StatelessWidget {
  const _SeatPill(this.seat);

  final String seat;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: const BoxDecoration(color: AppColors.accentSoft, borderRadius: Radii.smAll),
    child: Text(seat, style: AppText.bodyStrong.copyWith(color: AppColors.accent, fontSize: 14)),
  );
}

class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 0),
      color: AppColors.surfaceRaised,
      child: LayoutBuilder(
        builder: (context, c) {
          const dash = 7.0;
          const gap = 5.0;
          final count = ((c.maxWidth - 40) / (dash + gap)).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < count; i++)
                Container(
                  width: dash,
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: gap / 2),
                  color: AppColors.outline,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Rounded rectangle with semicircular bites on the tear-line edge.
class _TicketHalfClipper extends CustomClipper<Path> {
  const _TicketHalfClipper({required this.notchAtBottom});

  final bool notchAtBottom;
  static const _radius = 22.0;
  static const _notch = 14.0;

  @override
  Path getClip(Size size) {
    final rrect = RRect.fromRectAndCorners(
      Offset.zero & size,
      topLeft: notchAtBottom ? const Radius.circular(_radius) : Radius.zero,
      topRight: notchAtBottom ? const Radius.circular(_radius) : Radius.zero,
      bottomLeft: notchAtBottom ? Radius.zero : const Radius.circular(_radius),
      bottomRight: notchAtBottom ? Radius.zero : const Radius.circular(_radius),
    );
    final y = notchAtBottom ? size.height : 0.0;
    final notches = Path()
      ..addOval(Rect.fromCircle(center: Offset(0, y), radius: _notch))
      ..addOval(Rect.fromCircle(center: Offset(size.width, y), radius: _notch));
    return Path.combine(PathOperation.difference, Path()..addRRect(rrect), notches);
  }

  @override
  bool shouldReclip(covariant _TicketHalfClipper oldClipper) => oldClipper.notchAtBottom != notchAtBottom;
}

/// A real QR code (so it looks right), clearly stamped as a demo.
class DemoQr extends StatelessWidget {
  const DemoQr({super.key, required this.data, this.size = 104});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Demo QR code, not valid for cinema entry',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.white, borderRadius: Radii.mdAll),
                child: QrImageView(
                  data: data,
                  size: size,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: Color(0xFF121214)),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.circle,
                    color: Color(0xFF121214),
                  ),
                ),
              ),
              Transform.rotate(
                angle: -0.35,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: Radii.smAll,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6)],
                  ),
                  child: Text(
                    'DEMO',
                    style: AppText.label.copyWith(
                      color: AppColors.onAccent,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Not valid for entry', style: AppText.label.copyWith(fontSize: 11, color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}

/// Compact ticket for lists: poster, details, and a date stub separated by
/// a dashed tear line.
class TicketListCard extends StatelessWidget {
  const TicketListCard({super.key, required this.reservation, required this.onTap, this.past = false});

  final Reservation reservation;
  final VoidCallback onTap;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final date = DateTime.tryParse(r.date) ?? r.startsAt;
    return PressableScale(
      onTap: onTap,
      semanticLabel:
          '${r.movieTitle}, ${Fmt.longDate(date)} at ${r.time}, ${r.cinemaName}, '
          '${r.seats.length} ${r.seats.length == 1 ? 'seat' : 'seats'}. Open ticket.',
      child: ExcludeSemantics(
        child: Opacity(
          opacity: past ? 0.6 : 1,
          child: Container(
            height: 132,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: Radii.lgAll,
              border: Border.all(color: AppColors.outlineSoft),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(Space.sm),
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: Hero(
                      tag: 'ticket-poster-${r.id}',
                      child: PosterImage(
                        url: r.posterUrl,
                        title: r.movieTitle,
                        borderRadius: Radii.mdAll,
                        showTitleOnFallback: false,
                        memCacheWidth: 200,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(r.movieTitle, style: AppText.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(r.cinemaName, style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(
                          '${r.hallName} · ${r.format} · ${Fmt.seatList(r.seats)}',
                          style: AppText.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            MetaTag(
                              past ? 'Watched' : Fmt.countdown(r.startsAt),
                              icon: past ? Icons.check_circle_outline_rounded : Icons.schedule_rounded,
                              color: past ? AppColors.textTertiary : AppColors.accent,
                              filled: true,
                            ),
                            if (r.isDemo) ...[
                              Space.gap8,
                              const MetaTag('Demo', color: AppColors.warning, filled: true),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 2,
                  child: Column(
                    children: [
                      for (var i = 0; i < 9; i++)
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            color: i == 0 || i == 8 ? Colors.transparent : AppColors.outline,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        Fmt.dayShort(date).toUpperCase(),
                        style: AppText.label.copyWith(color: AppColors.textTertiary),
                      ),
                      Text(
                        Fmt.dayNumber(date),
                        style: AppText.h1.copyWith(color: past ? AppColors.textSecondary : AppColors.accent),
                      ),
                      Text(r.time, style: AppText.bodyStrong.copyWith(fontSize: 14)),
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
