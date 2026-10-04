import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/formatters.dart';
import '../models/movie.dart';
import 'meta_chips.dart';
import 'poster_image.dart';
import 'pressable.dart';

/// Poster card: image, title, genres, rating. Used in rails and grids.
/// The poster is a Hero so it flies into the details screen.
class MovieCard extends StatelessWidget {
  const MovieCard({super.key, required this.movie, required this.onTap, this.width, this.heroTagPrefix = 'card'});

  final Movie movie;
  final VoidCallback onTap;
  final double? width;
  final String heroTagPrefix;

  @override
  Widget build(BuildContext context) {
    final release = movie.releaseDate;
    final semantic = StringBuffer(movie.title)
      ..write(', ${movie.genres.take(2).join(', ')}')
      ..write(movie.rating != null ? ', rated ${movie.rating!.toStringAsFixed(1)}' : '')
      ..write(movie.isComingSoon && release != null ? ', releases ${Fmt.releaseDate(release)}' : '');

    return SizedBox(
      width: width,
      child: PressableScale(
        onTap: onTap,
        semanticLabel: semantic.toString(),
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 2 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: Radii.lgAll,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Hero(
                        tag: '$heroTagPrefix-poster-${movie.id}',
                        child: PosterImage(
                          url: movie.posterUrl,
                          title: movie.title,
                          accentHex: movie.accentHex,
                          memCacheWidth: 400,
                        ),
                      ),
                    ),
                    Positioned(
                      left: Space.xs,
                      top: Space.xs,
                      child: movie.isComingSoon
                          ? _ReleaseBadge(date: release)
                          : RatingBadge(rating: movie.rating, compact: true, onImage: true),
                    ),
                  ],
                ),
              ),
              Space.gap12,
              Text(movie.title, style: AppText.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              GenreLine(movie.genres),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReleaseBadge extends StatelessWidget {
  const _ReleaseBadge({required this.date});

  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(color: AppColors.accent, borderRadius: Radii.pillAll),
      child: Text(
        date == null ? 'SOON' : '${Fmt.dayNumber(date!)} ${Fmt.monthShort(date!).toUpperCase()}',
        style: AppText.label.copyWith(color: AppColors.onAccent, fontWeight: FontWeight.w800),
      ),
    );
  }
}
