import 'package:flutter/material.dart';

import '../../domain/movie_pass_models.dart';
import 'movie_blurred_artwork.dart';

/// Soft artwork across the wallet face. Only the poster is blurred; the title,
/// ticket information, and original partner footer paint above this layer.
class MovieArtworkBackdrop extends StatelessWidget {
  const MovieArtworkBackdrop({super.key, required this.pass});

  final MoviePass pass;

  @override
  Widget build(BuildContext context) {
    final String? asset = pass.resolvedPosterAsset;
    final String? url = pass.resolvedPosterUrl;
    final Widget art = Stack(
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
        if (asset != null || url != null)
          MovieBlurredArtwork(
            pass: pass,
            sigma: 22,
            fit: BoxFit.cover,
            overscan: 1.18,
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0x1F000000),
                Color(0x40000000),
                Color(0xB8000000),
                Color(0xE6000000),
              ],
              stops: <double>[0, 0.28, 0.52, 1],
            ),
          ),
        ),
      ],
    );

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: pass.status == TicketStatus.expired
            ? ColorFiltered(
                colorFilter: const ColorFilter.matrix(<double>[
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                ]),
                child: art,
              )
            : art,
      ),
    );
  }
}
