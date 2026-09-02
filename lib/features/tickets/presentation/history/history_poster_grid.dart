import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../../../../shared/widgets/bounce_tap.dart';
import '../../domain/movie_pass_models.dart';
import '../movie/movie_brand_style.dart';
import '../movie_pass_detail_screen.dart';
import 'movie_poster_art.dart';

/// Poster proportions. Every tile is a one-sheet, so the grid stays even
/// whether or not a given film resolved artwork.
const double kPosterAspect = 2 / 3;

/// Weight of the brand frame around a poster.
const double kPosterBorder = 3;

const double kPosterRadius = 16;

/// Opens [builder] with the tapped poster appearing to expand into the screen.
///
/// Deliberately not a [Hero]: the destination shows a full ticket face rather
/// than a bare poster, so there is no honest counterpart to fly into, and a
/// mistyped tag fails at runtime rather than at compile time.
PageRoute<T> posterScaleRoute<T>({required WidgetBuilder builder}) {
  return PageRouteBuilder<T>(
    fullscreenDialog: true,
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder:
        (BuildContext context, Animation<double> a, Animation<double> b) =>
            builder(context),
    transitionsBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondary,
          Widget child,
        ) {
          final CurvedAnimation curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curve,
            child: ScaleTransition(
              // Starts near the poster's own footprint and settles at full
              // size, so opening reads as the artwork growing into the page.
              scale: Tween<double>(begin: 0.86, end: 1).animate(curve),
              child: child,
            ),
          );
        },
  );
}

/// One archived film: its poster, framed in the ticket provider's colours.
class HistoryPosterTile extends StatelessWidget {
  const HistoryPosterTile({
    super.key,
    required this.pass,
    this.dateLabel,
    this.onLongPress,
  });

  final MoviePass pass;
  final String? dateLabel;
  final VoidCallback? onLongPress;

  void _open(BuildContext context) {
    HapticService.confirm();
    Navigator.of(context, rootNavigator: true).push(
      posterScaleRoute<void>(
        builder: (_) => MoviePassDetailScreen(pass: pass),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Archived passes are expired, and the expired palette is grey for every
    // brand — which would make the whole grid identical. Force brand chrome so
    // a BookMyShow ticket still reads as one.
    final MovieBrandStyle style = MovieBrandStyle.forPass(
      pass,
      useBrandColors: true,
    );

    return Semantics(
      button: true,
      label: dateLabel == null
          ? pass.movieTitle
          : '${pass.movieTitle}, $dateLabel',
      child: BounceTap(
        onTap: () => _open(context),
        onLongPress: onLongPress,
        scaleFactor: 0.96,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: style.bodyGradient,
            ),
            borderRadius: BorderRadius.circular(kPosterRadius),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: style.glow.withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(kPosterBorder),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                kPosterRadius - kPosterBorder,
              ),
              child: MoviePosterArt(
                pass: pass,
                // With no artwork the tile would be an anonymous gradient
                // rectangle, so name the film instead.
                fallback: _PosterTitleFallback(title: pass.movieTitle),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PosterTitleFallback extends StatelessWidget {
  const _PosterTitleFallback({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Center(
        child: Text(
          title,
          maxLines: 4,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            height: 1.25,
            color: Colors.white.withValues(alpha: 0.92),
          ),
        ),
      ),
    );
  }
}
