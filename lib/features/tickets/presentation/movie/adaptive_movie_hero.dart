import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/movie_pass_models.dart';
import 'movie_artwork_contrast.dart';

/// One result coordinates the backdrop and foreground, including their first
/// frame. Detail and classic faces never mount this scope or analyze their art.
class MovieArtworkContrastScope extends StatefulWidget {
  const MovieArtworkContrastScope({
    super.key,
    required this.pass,
    required this.heroBottom,
    required this.child,
  });

  final MoviePass pass;
  final double heroBottom;
  final Widget child;

  static ({MovieArtworkContrastResult result, double heroBottom})? maybeOf(
    BuildContext context,
  ) {
    final data = context.dependOnInheritedWidgetOfExactType<_ContrastData>();
    return data == null
        ? null
        : (result: data.result, heroBottom: data.heroBottom);
  }

  @override
  State<MovieArtworkContrastScope> createState() =>
      _MovieArtworkContrastScopeState();
}

class _MovieArtworkContrastScopeState extends State<MovieArtworkContrastScope> {
  late MovieArtworkContrastKey _key;
  MovieArtworkContrastResult? _result;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant MovieArtworkContrastScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (MovieArtworkContrastKey.forPass(widget.pass) != _key) _reset();
  }

  void _reset() {
    _key = MovieArtworkContrastKey.forPass(widget.pass);
    final generation = ++_generation;
    final service = MovieArtworkContrastService.instance;
    _result = _key.logo == null
        ? MovieArtworkContrastResult.title
        : service.getCached(_key);
    if (_result == null) unawaited(_prepare(generation));
  }

  Future<void> _prepare(int generation) async {
    final result = await MovieArtworkContrastService.instance.resolveContrast(
      widget.pass,
    );
    if (!mounted || generation != _generation) return;
    setState(() {
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) => _ContrastData(
    result: _result ?? MovieArtworkContrastResult.title,
    heroBottom: widget.heroBottom,
    child: widget.child,
  );
}

class _ContrastData extends InheritedWidget {
  const _ContrastData({
    required this.result,
    required this.heroBottom,
    required super.child,
  });
  final MovieArtworkContrastResult result;
  final double heroBottom;

  @override
  bool updateShouldNotify(_ContrastData oldWidget) =>
      result != oldWidget.result || heroBottom != oldWidget.heroBottom;
}

/// Readability applies only to the decorative wallet hero, never the one-sheet.
class AdaptiveMovieHero extends StatelessWidget {
  const AdaptiveMovieHero({
    super.key,
    required this.pass,
    required this.height,
  });
  final MoviePass pass;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final key = MovieArtworkContrastKey.forPass(pass);
    final source = key.logo;
    final result =
        MovieArtworkContrastScope.maybeOf(context)?.result ??
        MovieArtworkContrastResult.title;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) => Padding(
          padding: EdgeInsets.symmetric(
            horizontal: constraints.maxWidth * .10,
            vertical: constraints.maxHeight * .16,
          ),
          child: source == null
              ? _fallback()
              : Image(
                  key: ValueKey(key),
                  image: ResizeImage(
                    source,
                    width: 780,
                    height: 780,
                    policy: ResizeImagePolicy.fit,
                  ),
                  fit: BoxFit.contain,
                  semanticLabel: pass.movieTitle,
                  errorBuilder: (context, error, stack) => _fallback(),
                  frameBuilder: (context, child, frame, synchronous) {
                    final ready = result.showLogo && frame != null;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Opacity(opacity: ready ? 1 : 0, child: child),
                        if (!ready) _fallback(),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _fallback() => Center(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: 280,
        child: Text(
          pass.movieTitle,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -.55,
            height: 1.15,
          ),
        ),
      ),
    ),
  );
}
