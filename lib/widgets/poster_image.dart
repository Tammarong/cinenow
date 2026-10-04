import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/formatters.dart';
import 'shimmer_box.dart';

/// Network poster/backdrop with a shimmer while loading and a branded,
/// readable fallback (gradient + title) if the image can't be fetched.
/// Failed loads retry a few times with backoff, so artwork appears on its
/// own once the connection comes back.
class PosterImage extends StatefulWidget {
  const PosterImage({
    super.key,
    required this.url,
    required this.title,
    this.accentHex,
    this.borderRadius = Radii.lgAll,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.showTitleOnFallback = true,
    this.memCacheWidth,
    this.semanticLabel,
  });

  final String url;
  final String title;
  final String? accentHex;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final Alignment alignment;
  final bool showTitleOnFallback;
  final int? memCacheWidth;
  final String? semanticLabel;

  @override
  State<PosterImage> createState() => _PosterImageState();
}

class _PosterImageState extends State<PosterImage> {
  static const _retryDelays = [Duration(seconds: 4), Duration(seconds: 12), Duration(seconds: 30)];
  int _attempt = 0;
  Timer? _retry;

  @override
  void didUpdateWidget(covariant PosterImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _retry?.cancel();
      _attempt = 0;
    }
  }

  @override
  void dispose() {
    _retry?.cancel();
    super.dispose();
  }

  void _scheduleRetry() {
    if (_retry?.isActive ?? false) return;
    if (_attempt >= _retryDelays.length) return;
    _retry = Timer(_retryDelays[_attempt], () {
      if (mounted) setState(() => _attempt++);
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.fromHex(widget.accentHex);
    final fallback = _Fallback(title: widget.title, accent: accent, showTitle: widget.showTitleOnFallback);
    return Semantics(
      image: true,
      label: widget.semanticLabel ?? 'Poster for ${widget.title}',
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: widget.url.isEmpty
            ? fallback
            : CachedNetworkImage(
                // A new key forces a fresh attempt after a failure.
                key: ValueKey('${widget.url}#$_attempt'),
                imageUrl: widget.url,
                fit: widget.fit,
                alignment: widget.alignment,
                memCacheWidth: widget.memCacheWidth,
                fadeInDuration: Motion.slow,
                placeholder: (_, _) => const ShimmerScope(child: ShimmerBox(radius: BorderRadius.zero)),
                errorWidget: (_, _, _) {
                  _scheduleRetry();
                  return fallback;
                },
              ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.title, required this.accent, required this.showTitle});

  final String title;
  final Color accent;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(accent, AppColors.background, 0.25)!, Color.lerp(accent, AppColors.background, 0.85)!],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -24,
            top: -24,
            child: Icon(Icons.local_movies_rounded, size: 120, color: Colors.white.withValues(alpha: 0.07)),
          ),
          if (showTitle)
            Padding(
              padding: const EdgeInsets.all(Space.sm),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.movie_filter_rounded, color: AppColors.textPrimary.withValues(alpha: 0.8), size: 20),
                  Space.gap8,
                  Text(title, style: AppText.h3, maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Round profile photo with initials fallback.
class NetworkAvatar extends StatelessWidget {
  const NetworkAvatar({super.key, required this.name, this.url, this.size = 64});

  final String name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [AppColors.surfaceBright, AppColors.surfaceRaised]),
      ),
      child: Text(Fmt.initials(name), style: AppText.h3.copyWith(fontSize: size * 0.32)),
    );
    if (url == null || url!.isEmpty) return fallback;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: (size * 3).round(),
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}
