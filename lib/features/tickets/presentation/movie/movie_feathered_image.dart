import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'movie_blurred_artwork.dart';

/// Bakes the poster's intersecting alpha masks once, rather than compositing two
/// full-resolution ShaderMask layers during every route/scroll frame. This is
/// public film artwork only. Flutter's bounded ImageCache owns its lifetime.
@immutable
class MovieFeatheredImage extends ImageProvider<MovieFeatheredImage> {
  const MovieFeatheredImage({
    required this.source,
    required this.colors,
    required this.width,
    required this.height,
    required this.sideFraction,
    required this.topFraction,
    required this.bottomFraction,
  });

  final ImageProvider? source;
  final List<Color> colors;
  final int width;
  final int height;
  final double sideFraction;
  final double topFraction;
  final double bottomFraction;

  MovieFeatheredImage get fallback => MovieFeatheredImage(
    source: null,
    colors: colors,
    width: width,
    height: height,
    sideFraction: sideFraction,
    topFraction: topFraction,
    bottomFraction: bottomFraction,
  );

  @override
  Future<MovieFeatheredImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    MovieFeatheredImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(key._render());

  Future<ImageInfo> _render() async {
    // Failed source reads propagate to the image's fallback, so a failed network
    // result is not permanently cached as successful artwork under this key.
    final info = source == null ? null : await resolveMovieArtwork(source!);
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final bounds = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
      canvas.saveLayer(bounds, Paint());
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ).createShader(bounds),
      );
      if (info != null) {
        paintImage(
          canvas: canvas,
          rect: bounds,
          image: info.image,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.low,
        );
      }
      const mask = [
        Colors.transparent,
        Colors.white,
        Colors.white,
        Colors.transparent,
      ];
      canvas.drawRect(
        bounds,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = LinearGradient(
            colors: mask,
            stops: [0, sideFraction, 1 - sideFraction, 1],
          ).createShader(bounds),
      );
      canvas.drawRect(
        bounds,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: mask,
            stops: [0, topFraction, 1 - bottomFraction, 1],
          ).createShader(bounds),
      );
      canvas.restore();
      final picture = recorder.endRecording();
      try {
        return ImageInfo(image: await picture.toImage(width, height));
      } finally {
        picture.dispose();
      }
    } finally {
      info?.dispose();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is MovieFeatheredImage &&
      source == other.source &&
      listEquals(colors, other.colors) &&
      width == other.width &&
      height == other.height &&
      sideFraction == other.sideFraction &&
      topFraction == other.topFraction &&
      bottomFraction == other.bottomFraction;

  @override
  int get hashCode => Object.hash(
    source,
    Object.hashAll(colors),
    width,
    height,
    sideFraction,
    topFraction,
    bottomFraction,
  );
}
