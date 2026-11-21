import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/movie_pass_models.dart';
import 'movie_blurred_artwork.dart';
import 'movie_ticket_chrome.dart';

/// The full one-sheet, with only its perimeter fading into an aligned halo.
/// The parent retains the existing inset and clips the halo to the ticket.
class MovieBlendedPoster extends StatelessWidget {
  const MovieBlendedPoster({super.key, required this.pass});

  final MoviePass pass;

  static const double edgeFeather = 28;
  static const double bottomFeather = 42;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int decodeWidth = math.min(
          (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
              .ceil(),
          780,
        );
        return RepaintBoundary(
          child: AspectRatio(
            aspectRatio: MovieTicketMetrics.posterAspect,
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: <Widget>[
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
                // Alpha masks intersect: a narrow soft edge on every side,
                // with a longer bottom fade into the ticket information.
                ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (bounds) => LinearGradient(
                    colors: _maskColors,
                    stops: <double>[
                      0,
                      (edgeFeather / bounds.width).clamp(0, 0.45),
                      1 - (edgeFeather / bounds.width).clamp(0, 0.45),
                      1,
                    ],
                  ).createShader(bounds),
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (bounds) => LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: _maskColors,
                      stops: <double>[
                        0,
                        (edgeFeather / bounds.height).clamp(0, 0.45),
                        1 - (bottomFeather / bounds.height).clamp(0, 0.45),
                        1,
                      ],
                    ).createShader(bounds),
                    child: Semantics(
                      image: true,
                      label: '${pass.movieTitle} poster',
                      child: ExcludeSemantics(
                        child: _PosterLayer(
                          pass: pass,
                          decodeWidth: decodeWidth,
                          fit: BoxFit.contain,
                        ),
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

  static const List<Color> _maskColors = <Color>[
    Colors.transparent,
    Colors.white,
    Colors.white,
    Colors.transparent,
  ];
}

/// Both layers use the same artwork and keep a stable fallback during loading,
/// failure, or a missing TMDB match. The sharp layer never crops the one-sheet.
class _PosterLayer extends StatelessWidget {
  const _PosterLayer({
    required this.pass,
    required this.decodeWidth,
    required this.fit,
  });

  final MoviePass pass;
  final int decodeWidth;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final String? asset = pass.resolvedPosterAsset;
    final String? url = pass.resolvedPosterUrl;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: pass.posterHint.gradient,
            ),
          ),
        ),
        if (asset != null)
          Image.asset(
            asset,
            fit: fit,
            cacheWidth: decodeWidth,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          )
        else if (url != null)
          CachedNetworkImage(
            imageUrl: url,
            fit: fit,
            memCacheWidth: decodeWidth,
            fadeInDuration: const Duration(milliseconds: 220),
            placeholder: (context, url) => const SizedBox.shrink(),
            errorWidget: (context, url, error) => const SizedBox.shrink(),
          ),
      ],
    );
  }
}
