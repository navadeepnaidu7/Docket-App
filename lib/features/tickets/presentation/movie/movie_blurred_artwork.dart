import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/movie_pass_models.dart';

/// Prepares a small blurred raster once instead of applying a large image filter
/// on every route-animation frame. Flutter's ImageCache owns the derived images.
class MovieBlurredArtwork extends StatelessWidget {
  const MovieBlurredArtwork({
    super.key,
    required this.pass,
    required this.sigma,
    required this.fit,
    this.overscan = 1,
  });

  final MoviePass pass;
  final double sigma;
  final BoxFit fit;
  final double overscan;

  @override
  Widget build(BuildContext context) {
    final String? asset = pass.resolvedPosterAsset;
    final String? url = pass.resolvedPosterUrl;
    if (asset == null && url == null) return const SizedBox.shrink();
    final ImageProvider source = ResizeImage.resizeIfNeeded(
      360,
      null,
      asset != null ? AssetImage(asset) : CachedNetworkImageProvider(url!),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final Size size = constraints.biggest;
        if (!size.isFinite || size.isEmpty) return const SizedBox.shrink();
        // Preserve the filter's soft overflow. Cropping at the unblurred box
        // would leave a visible rectangle where the poster halo meets metadata.
        final Size expanded = Size(
          size.width + sigma * 6,
          size.height + sigma * 6,
        );
        final double scale = math.min(
          128 / expanded.width,
          256 / expanded.height,
        );
        return OverflowBox(
          minWidth: expanded.width,
          maxWidth: expanded.width,
          minHeight: expanded.height,
          maxHeight: expanded.height,
          child: Image(
            image: MovieBlurredImage(
              source: source,
              width: (expanded.width * scale).ceil().clamp(1, 128),
              height: (expanded.height * scale).ceil().clamp(1, 256),
              sigma: sigma * scale,
              fit: fit,
              overscan: overscan,
            ),
            fit: BoxFit.fill,
            filterQuality: FilterQuality.low,
            excludeFromSemantics: true,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

/// The key includes geometry and blur policy. Flutter's bounded ImageCache owns
/// reuse and disposal, including images finishing after a route has been popped.
@immutable
class MovieBlurredImage extends ImageProvider<MovieBlurredImage> {
  const MovieBlurredImage({
    required this.source,
    required this.width,
    required this.height,
    required this.sigma,
    required this.fit,
    required this.overscan,
  });

  final ImageProvider source;
  final int width;
  final int height;
  final double sigma;
  final BoxFit fit;
  final double overscan;

  @override
  Future<MovieBlurredImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<MovieBlurredImage>(this);

  @override
  ImageStreamCompleter loadImage(
    MovieBlurredImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(key._render());

  Future<ImageInfo> _render() async {
    final ImageStream stream = source.resolve(ImageConfiguration.empty);
    final completer = Completer<ImageInfo>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, synchronousCall) {
        stream.removeListener(listener);
        completer.complete(info);
      },
      onError: (Object error, StackTrace? stack) {
        stream.removeListener(listener);
        completer.completeError(error, stack);
      },
    );
    stream.addListener(listener);
    final ImageInfo info = await completer.future;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final bounds = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
      canvas.saveLayer(
        bounds.inflate(sigma * 3),
        Paint()
          ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      );
      final sourceBounds = bounds.deflate(sigma * 3);
      paintImage(
        canvas: canvas,
        rect: Rect.fromCenter(
          center: sourceBounds.center,
          width: sourceBounds.width * overscan,
          height: sourceBounds.height * overscan,
        ),
        image: info.image,
        fit: fit,
        filterQuality: FilterQuality.low,
      );
      canvas.restore();
      final picture = recorder.endRecording();
      try {
        return ImageInfo(image: await picture.toImage(width, height));
      } finally {
        picture.dispose();
      }
    } finally {
      info.dispose();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is MovieBlurredImage &&
      source == other.source &&
      width == other.width &&
      height == other.height &&
      sigma == other.sigma &&
      fit == other.fit &&
      overscan == other.overscan;

  @override
  int get hashCode => Object.hash(source, width, height, sigma, fit, overscan);
}
