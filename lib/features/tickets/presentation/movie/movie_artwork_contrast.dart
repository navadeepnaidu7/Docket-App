import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../domain/movie_pass_models.dart';
import 'movie_blurred_artwork.dart';

/// A local veil over decorative art; the original logo is never tinted.
@immutable
class MovieArtworkContrastResult {
  const MovieArtworkContrastResult({
    required this.showLogo,
    this.veilColor = 0xFF000000,
    this.opacity = .82,
    this.cacheable = true,
  });

  static const title = MovieArtworkContrastResult(showLogo: false);

  final bool showLogo;
  final int veilColor;
  final double opacity;
  final bool cacheable;
}

@immutable
class MovieArtworkContrastKey {
  const MovieArtworkContrastKey(this.poster, this.logo, this.hint);

  factory MovieArtworkContrastKey.forPass(MoviePass pass) =>
      MovieArtworkContrastKey(
        _source(pass.resolvedPosterAsset, pass.resolvedPosterUrl),
        _source(pass.resolvedLogoAsset, pass.resolvedLogoUrl),
        pass.posterHint,
      );

  final ImageProvider? poster;
  final ImageProvider? logo;
  final MoviePosterHint hint;

  static ImageProvider? _source(String? asset, String? url) => asset != null
      ? AssetImage(asset)
      : url != null
      ? CachedNetworkImageProvider(url)
      : null;

  @override
  bool operator ==(Object other) =>
      other is MovieArtworkContrastKey &&
      poster == other.poster &&
      logo == other.logo &&
      hint == other.hint;

  @override
  int get hashCode => Object.hash(poster, logo, hint);
}

/// Pure, bounded pixel analysis. RGBA inputs are straight (not premultiplied).
/// It checks the visible ink against a range of backdrop samples, rather than
/// averaging a multicolor logo into a color that none of its lettering uses.
class MovieArtworkContrastPolicy {
  const MovieArtworkContrastPolicy._();

  static const thumbnailSize = 48;
  static const minimumRatio = 3.0;
  static const requiredCoverage = .92;

  static double _linear(double channel) => channel <= .04045
      ? channel / 12.92
      : math.pow((channel + .055) / 1.055, 2.4).toDouble();

  static double luminance(double r, double g, double b) =>
      .2126 * _linear(r) + .7152 * _linear(g) + .0722 * _linear(b);

  static double contrastRatio(double a, double b) =>
      (math.max(a, b) + .05) / (math.min(a, b) + .05);

  static MovieArtworkContrastResult analyze({
    required Uint8List logoRgba,
    required Uint8List posterRgba,
    required List<int> fallbackColors,
  }) {
    // At most 48x48 input pixels. Quantization combines similar ink samples,
    // including alpha, while preserving the weights of dark and light elements.
    final ink = <int, double>{};
    for (var i = 0; i + 3 < logoRgba.length; i += 4) {
      final alpha = logoRgba[i + 3];
      if (alpha < 96) continue;
      final key =
          ((logoRgba[i] >> 4) << 12) |
          ((logoRgba[i + 1] >> 4) << 8) |
          ((logoRgba[i + 2] >> 4) << 4) |
          (alpha >> 4);
      ink.update(
        key,
        (weight) => weight + alpha / 255,
        ifAbsent: () => alpha / 255,
      );
    }
    if (ink.isEmpty) return MovieArtworkContrastResult.title;

    final backgrounds = <(double, double, double)>[];
    for (var i = 0; i + 3 < posterRgba.length; i += 4) {
      // Transparent poster pixels reveal the existing hint gradient.
      final alpha = posterRgba[i + 3] / 255;
      final fallback = fallbackColors.isEmpty
          ? 0xFF12121A
          : fallbackColors.first;
      backgrounds.add((
        posterRgba[i] / 255 * alpha +
            ((fallback >> 16) & 255) / 255 * (1 - alpha),
        posterRgba[i + 1] / 255 * alpha +
            ((fallback >> 8) & 255) / 255 * (1 - alpha),
        posterRgba[i + 2] / 255 * alpha + (fallback & 255) / 255 * (1 - alpha),
      ));
    }
    if (backgrounds.isEmpty) {
      for (final color in fallbackColors) {
        backgrounds.add((
          ((color >> 16) & 255) / 255,
          ((color >> 8) & 255) / 255,
          (color & 255) / 255,
        ));
      }
    }
    if (backgrounds.isEmpty) backgrounds.add((.07, .07, .10));
    backgrounds.sort(
      (a, b) =>
          luminance(a.$1, a.$2, a.$3).compareTo(luminance(b.$1, b.$2, b.$3)),
    );
    // Cover the range of image colors and the existing atmospheric dark scrim.
    // This intentionally errs toward a stronger veil on busy artwork.
    final backdrop = <(double, double, double)>[];
    for (final q in [0.0, .1, .5, .9, 1.0]) {
      final color = backgrounds[((backgrounds.length - 1) * q).round()];
      for (final shade in [.28, 1.0]) {
        backdrop.add((color.$1 * shade, color.$2 * shade, color.$3 * shade));
      }
    }
    final weight = ink.values.fold(0.0, (a, b) => a + b);

    bool readable(int color, double opacity) {
      // Logo padding ends at 84% of the hero height. Even its lowest visible
      // pixels receive at least 75% of the veil while the fade ends above text.
      final effectiveOpacity = opacity * .75;
      final red = ((color >> 16) & 255) / 255;
      final green = ((color >> 8) & 255) / 255;
      final blue = (color & 255) / 255;
      final adjusted = [
        for (final bg in backdrop)
          (
            bg.$1 * (1 - effectiveOpacity) + red * effectiveOpacity,
            bg.$2 * (1 - effectiveOpacity) + green * effectiveOpacity,
            bg.$3 * (1 - effectiveOpacity) + blue * effectiveOpacity,
          ),
      ];
      var passing = 0.0;
      for (final entry in ink.entries) {
        // Use the center of the quantization bin, preserving 0 and 255 endpoints.
        double channel(int nibble) => nibble == 0
            ? 0
            : nibble == 15
            ? 1
            : (nibble * 16 + 7.5) / 255;
        final r = channel((entry.key >> 12) & 15);
        final g = channel((entry.key >> 8) & 15);
        final b = channel((entry.key >> 4) & 15);
        final alpha = channel(entry.key & 15);
        var passes = true;
        for (final bg in adjusted) {
          final backgroundLuminance = luminance(bg.$1, bg.$2, bg.$3);
          final foregroundLuminance = luminance(
            r * alpha + bg.$1 * (1 - alpha),
            g * alpha + bg.$2 * (1 - alpha),
            b * alpha + bg.$3 * (1 - alpha),
          );
          if (contrastRatio(foregroundLuminance, backgroundLuminance) <
              minimumRatio) {
            passes = false;
            break;
          }
        }
        if (passes) passing += entry.value;
      }
      return passing / weight >= requiredCoverage;
    }

    if (readable(0xFF000000, 0)) {
      return const MovieArtworkContrastResult(showLogo: true, opacity: 0);
    }
    for (final opacity in [.16, .30, .45, .60, .72, .82, .90, .96, 1.0]) {
      for (final color in [0xFF000000, 0xFFFFFFFF, 0xFF777777]) {
        if (readable(color, opacity)) {
          return MovieArtworkContrastResult(
            showLogo: true,
            veilColor: color,
            opacity: opacity,
          );
        }
      }
    }
    return MovieArtworkContrastResult.title;
  }
}

class _ContrastPixels {
  const _ContrastPixels(this.logo, this.poster, this.colors);
  final Uint8List logo;
  final Uint8List poster;
  final List<int> colors;
}

MovieArtworkContrastResult _analyzePixels(_ContrastPixels input) =>
    MovieArtworkContrastPolicy.analyze(
      logoRgba: input.logo,
      posterRgba: input.poster,
      fallbackColors: input.colors,
    );

/// Only tiny metadata results live here; Flutter owns the actual image cache.
/// Both completed and pending requests have explicit limits. Failures can retry.
class MovieArtworkContrastService {
  MovieArtworkContrastService({
    this.capacity = 64,
    this.maxPending = 16,
    @visibleForTesting this.analyzeOverride,
  }) : assert(capacity > 0),
       assert(maxPending > 0);

  static final instance = MovieArtworkContrastService();
  final int capacity;
  final int maxPending;
  final Future<MovieArtworkContrastResult> Function(MoviePass)? analyzeOverride;
  final _cache = <MovieArtworkContrastKey, MovieArtworkContrastResult>{};
  final _pending =
      <MovieArtworkContrastKey, Future<MovieArtworkContrastResult>>{};
  var _epoch = 0;

  int get cachedCount => _cache.length;
  int get pendingCount => _pending.length;

  MovieArtworkContrastResult? getCached(MovieArtworkContrastKey key) {
    final value = _cache.remove(key);
    if (value != null) _cache[key] = value;
    return value;
  }

  void clear() {
    _epoch++;
    _cache.clear();
    // Pending work retains its slot until completion; clear cannot bypass the cap.
  }

  Future<MovieArtworkContrastResult> resolveContrast(MoviePass pass) {
    final key = MovieArtworkContrastKey.forPass(pass);
    final cached = getCached(key);
    if (cached != null) return SynchronousFuture(cached);
    final pending = _pending[key];
    if (pending != null) return pending;
    if (_pending.length >= maxPending) {
      return SynchronousFuture(
        const MovieArtworkContrastResult(showLogo: false, cacheable: false),
      );
    }
    final epoch = _epoch;
    late final Future<MovieArtworkContrastResult> future;
    future =
        Future<MovieArtworkContrastResult>.sync(
              () => analyzeOverride?.call(pass) ?? _analyze(pass, key),
            )
            .then(
              (result) {
                if (result.cacheable && epoch == _epoch) {
                  while (_cache.length >= capacity) {
                    _cache.remove(_cache.keys.first);
                  }
                  _cache[key] = result;
                }
                return result;
              },
              onError: (Object error, StackTrace stack) =>
                  const MovieArtworkContrastResult(
                    showLogo: false,
                    cacheable: false,
                  ),
            )
            .whenComplete(() {
              if (identical(_pending[key], future)) _pending.remove(key);
            });
    _pending[key] = future;
    return future;
  }

  Future<MovieArtworkContrastResult> _analyze(
    MoviePass pass,
    MovieArtworkContrastKey key,
  ) async {
    if (key.logo == null) return MovieArtworkContrastResult.title;
    final logo = await _pixels(key.logo!);
    var poster = Uint8List(0);
    var cacheable = true;
    if (key.poster != null) {
      try {
        poster = await _pixels(key.poster!);
      } catch (_) {
        cacheable = false;
      }
    }
    final result = await compute(
      _analyzePixels,
      _ContrastPixels(
        logo,
        poster,
        pass.posterHint.gradient.map((color) => color.toARGB32()).toList(),
      ),
    );
    return MovieArtworkContrastResult(
      showLogo: result.showLogo,
      veilColor: result.veilColor,
      opacity: result.opacity,
      cacheable: cacheable,
    );
  }

  Future<Uint8List> _pixels(ImageProvider provider) async {
    final source = ResizeImage(
      provider,
      width: MovieArtworkContrastPolicy.thumbnailSize,
      height: MovieArtworkContrastPolicy.thumbnailSize,
      policy: ResizeImagePolicy.fit,
    );
    final info = await resolveMovieArtwork(
      source,
      timeout: const Duration(seconds: 8),
    );
    try {
      final bytes = await info.image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (bytes == null) throw StateError('Artwork pixels unavailable');
      return Uint8List.sublistView(bytes);
    } finally {
      info.dispose();
    }
  }
}

/// A tiny cached veil with intersecting alpha fades. It reaches zero at every
/// edge, unlike a radial gradient clipped before its fade reaches transparency.
class MovieHeroVeil extends ImageProvider<MovieHeroVeil> {
  const MovieHeroVeil(this.color, this.opacity);
  final int color;
  final double opacity;

  @override
  Future<MovieHeroVeil> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    MovieHeroVeil key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(key._render());

  Future<ImageInfo> _render() async {
    const side = 64;
    const bounds = Rect.fromLTWH(0, 0, 64, 64);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..saveLayer(bounds, Paint());
    canvas.drawRect(
      bounds,
      Paint()..color = Color(color).withValues(alpha: opacity),
    );
    const colors = [
      Color(0x00000000),
      Color(0xFFFFFFFF),
      Color(0xFFFFFFFF),
      Color(0x00000000),
    ];
    canvas.drawRect(
      bounds,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = const LinearGradient(
          colors: colors,
          stops: [0, .08, .92, 1],
        ).createShader(bounds),
    );
    canvas.drawRect(
      bounds,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
          stops: [0, .14, .86, 1],
        ).createShader(bounds),
    );
    canvas.restore();
    final picture = recorder.endRecording();
    try {
      return ImageInfo(image: await picture.toImage(side, side));
    } finally {
      picture.dispose();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is MovieHeroVeil &&
      color == other.color &&
      opacity == other.opacity;
  @override
  int get hashCode => Object.hash(color, opacity);
}
