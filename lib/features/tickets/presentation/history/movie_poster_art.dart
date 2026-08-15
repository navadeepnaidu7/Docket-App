import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/movie_pass_models.dart';

/// The film's poster, with the poster-hint gradient underneath it.
///
/// "No poster" is a normal state, not an error: TMDB may have no match, or the
/// async lookup may not have finished. The gradient is painted first and never
/// removed, so it shows through while the image loads and stays as the art when
/// there is none. Another film's artwork is never substituted.
///
/// This is the full one-sheet — the archive and the folder chips both want the
/// poster, not the title logo the glance card uses.
class MoviePosterArt extends StatelessWidget {
  const MoviePosterArt({super.key, required this.pass, this.fallback});

  final MoviePass pass;

  /// Drawn over the gradient when there is no poster at all.
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    // Fixtures may pin a bundled asset; everything else comes from the
    // backend's TMDB image proxy. Either may be absent.
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
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          )
        else if (url != null)
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 180),
                // Decode to the size actually drawn. A 780px poster decoded at
                // full size across a grid is a real memory cost.
                memCacheWidth:
                    (constraints.maxWidth *
                            MediaQuery.devicePixelRatioOf(context))
                        .round(),
                // A spinner at this size reads as broken — the gradient below
                // is the placeholder.
                placeholder: (_, _) => const SizedBox.shrink(),
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              );
            },
          )
        else
          ?fallback,
      ],
    );
  }
}
