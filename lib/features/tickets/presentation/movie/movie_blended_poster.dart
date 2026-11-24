import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/movie_pass_models.dart';
import 'movie_blurred_artwork.dart';
import 'movie_feathered_image.dart';
import 'movie_ticket_chrome.dart';

/// The full one-sheet, with only its perimeter fading into an aligned halo.
/// The parent retains the existing inset and clips the halo to the ticket.
class MovieBlendedPoster extends StatelessWidget {
  const MovieBlendedPoster({super.key, required this.pass});

  final MoviePass pass;

  static const double edgeFeather = 28;
  static const double bottomFeather = 42;

  static int decodeWidth(double width, double devicePixelRatio) =>
      math.min((width * devicePixelRatio).ceil(), 780);

  /// Prepare only the expanded poster and halo, without mounting a hidden route
  /// or waiting on a download when the user taps. ImageCache bounds their life.
  static Future<void> warmUp(MoviePass pass, BuildContext context) async {
    final width =
        MediaQuery.sizeOf(context).width -
        MediaQuery.paddingOf(context).horizontal -
        2 * MovieTicketMetrics.detailHorizontalPadding -
        2 * MovieTicketMetrics.heroHorizontalPadding;
    if (width <= 0) return;
    final asset = pass.resolvedPosterAsset;
    final url = pass.resolvedPosterUrl;
    if (asset == null && url == null) return;
    final sharp = imageFor(pass, width, MediaQuery.devicePixelRatioOf(context));
    final halo = MovieBlurredArtwork.imageFor(
      pass: pass,
      size: Size(width + 56, width / MovieTicketMetrics.posterAspect + 80),
      sigma: 25,
      fit: BoxFit.fill,
    )!;
    await Future.wait([
      precacheImage(sharp, context, onError: (error, stack) {}),
      precacheImage(sharp.fallback, context, onError: (error, stack) {}),
      precacheImage(halo, context, onError: (error, stack) {}),
    ]);
  }

  static MovieFeatheredImage imageFor(
    MoviePass pass,
    double width,
    double dpr,
  ) {
    final asset = pass.resolvedPosterAsset;
    final url = pass.resolvedPosterUrl;
    final pixels = decodeWidth(width, dpr);
    final height = width / MovieTicketMetrics.posterAspect;
    return MovieFeatheredImage(
      source: asset == null && url == null
          ? null
          : ResizeImage.resizeIfNeeded(
              pixels,
              null,
              asset != null
                  ? AssetImage(asset)
                  : CachedNetworkImageProvider(url!),
            ),
      colors: pass.posterHint.gradient,
      width: pixels,
      height: (pixels / MovieTicketMetrics.posterAspect).round(),
      sideFraction: (edgeFeather / width).clamp(0, .45),
      topFraction: (edgeFeather / height).clamp(0, .45),
      bottomFraction: (bottomFeather / height).clamp(0, .45),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final poster = imageFor(
          pass,
          constraints.maxWidth,
          MediaQuery.devicePixelRatioOf(context),
        );
        return RepaintBoundary(
          child: AspectRatio(
            aspectRatio: MovieTicketMetrics.posterAspect,
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: -25,
                  left: -28,
                  right: -28,
                  bottom: -55,
                  child: ExcludeSemantics(
                    child: MovieBlurredArtwork(
                      pass: pass,
                      sigma: 25,
                      fit: BoxFit.fill,
                    ),
                  ),
                ),
                Semantics(
                  image: true,
                  label: '${pass.movieTitle} poster',
                  child: ExcludeSemantics(
                    child: poster.source == null
                        ? Image(image: poster.fallback, fit: BoxFit.contain)
                        : Image(
                            key: ValueKey(poster.source),
                            image: poster,
                            fit: BoxFit.contain,
                            frameBuilder: (context, child, frame, synchronous) {
                              if (synchronous) return child;
                              return AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: frame == null
                                    ? Image(
                                        key: const ValueKey('poster-fallback'),
                                        image: poster.fallback,
                                        fit: BoxFit.contain,
                                      )
                                    : KeyedSubtree(
                                        key: const ValueKey('poster-loaded'),
                                        child: child,
                                      ),
                              );
                            },
                            errorBuilder: (context, error, stack) => Image(
                              image: poster.fallback,
                              fit: BoxFit.contain,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
