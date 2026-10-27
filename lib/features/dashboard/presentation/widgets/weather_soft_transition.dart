import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The exposed weather material resolves from a gentle haze as the pull opens.
/// This filters only its child; it never samples or blurs the wallet behind it.
class WeatherRevealBlur extends StatelessWidget {
  const WeatherRevealBlur({
    super.key,
    required this.progress,
    required this.child,
    this.maxBlur = 10,
    this.minimumBlur = 0,
    this.tileMode = ui.TileMode.clamp,
  });

  final double progress;
  final double maxBlur;
  final double minimumBlur;
  final ui.TileMode tileMode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Keep the material hazy while it is uncovered. Clearing too early makes
    // the transition disappear before the text clears the wallet's edge.
    final clarity = Curves.easeInCubic.transform(
      ((progress - 0.10) / 0.90).clamp(0.0, 1.0),
    );
    final sigma = MediaQuery.disableAnimationsOf(context)
        ? 0.0
        : math.max(minimumBlur, maxBlur * (1 - clarity));
    return ImageFiltered(
      enabled: sigma > 0.01,
      imageFilter: ui.ImageFilter.blur(
        sigmaX: sigma,
        sigmaY: sigma,
        tileMode: tileMode,
      ),
      child: child,
    );
  }
}

// The sky and copy start together, but the old words leave before new ones
// become legible. One material is changing focus, rather than changing scenes.
const _weatherRevealDuration = Duration(milliseconds: 760);

class WeatherActivityBackdrop extends StatelessWidget {
  const WeatherActivityBackdrop({
    super.key,
    required this.active,
    required this.progress,
    required this.child,
  });

  final bool active;
  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: active ? 8 : 0),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _weatherRevealDuration,
    curve: Curves.easeInOutCubic,
    child: child,
    builder: (context, frost, child) => WeatherRevealBlur(
      progress: progress,
      minimumBlur: frost,
      child: child!,
    ),
  );
}

/// A silent focus change over the existing scene. No tint or loading copy.
class WeatherRefreshVeil extends StatelessWidget {
  const WeatherRefreshVeil({
    super.key,
    required this.refreshing,
    required this.child,
  });

  final bool refreshing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: refreshing ? 1 : 0, end: refreshing ? 1 : 0),
      duration: Duration(milliseconds: reduced ? 0 : (refreshing ? 240 : 760)),
      curve: Curves.easeInOutCubic,
      child: child,
      builder: (context, amount, child) => Semantics(
        liveRegion: refreshing,
        label: refreshing ? 'Weather refreshing' : null,
        child: IgnorePointer(
          ignoring: refreshing || amount > 0.05,
          child: ExcludeSemantics(
            excluding: refreshing || amount > 0.05,
            child: ImageFiltered(
              key: const ValueKey('weather_refresh_blur'),
              enabled: !reduced && amount > 0.01,
              imageFilter: ui.ImageFilter.blur(
                sigmaX: 8 * amount,
                sigmaY: 8 * amount,
                tileMode: ui.TileMode.clamp,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Two typographic beats, so the heading resolves slightly before its detail.
class WeatherCopy extends StatelessWidget {
  const WeatherCopy({super.key, required this.heading, required this.detail});

  final Widget heading;
  final Widget detail;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [heading, detail],
  );
}

class WeatherSoftSwap extends StatelessWidget {
  const WeatherSoftSwap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduced ? Duration.zero : _weatherRevealDuration,
      reverseDuration: Duration(milliseconds: reduced ? 0 : 180),
      switchInCurve: Curves.linear,
      switchOutCurve: Curves.linear,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, ?current],
      ),
      transitionBuilder: (content, animation) => AnimatedBuilder(
        animation: animation,
        child: content,
        builder: (context, _) {
          final leaving = animation.status == AnimationStatus.reverse;
          final t = animation.value;
          final clarity = reduced
              ? 1.0
              : const Interval(
                  0.24,
                  1,
                  curve: Curves.easeOutCubic,
                ).transform(t);
          Widget line(Widget child, double start, double end) {
            final visibility = reduced
                ? 1.0
                : Interval(start, end, curve: Curves.easeOutCubic).transform(t);
            return Opacity(
              opacity: visibility,
              child: Transform.translate(
                offset: Offset(0, reduced ? 0 : 4 * (1 - visibility)),
                child: child,
              ),
            );
          }

          return IgnorePointer(
            ignoring: leaving || t < 0.95,
            child: ExcludeSemantics(
              excluding: leaving || t < 0.5,
              child: ImageFiltered(
                enabled: !reduced && clarity < 0.998,
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: 6 * (1 - clarity),
                  sigmaY: 6 * (1 - clarity),
                  tileMode: ui.TileMode.decal,
                ),
                child: content is WeatherCopy
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          line(content.heading, 0.24, 0.88),
                          line(content.detail, 0.32, 1),
                        ],
                      )
                    : line(content, 0.28, 1),
              ),
            ),
          );
        },
      ),
      child: child,
    );
  }
}
