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
    this.tileMode = ui.TileMode.clamp,
  });

  final double progress;
  final double maxBlur;
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
        : maxBlur * (1 - clarity);
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

/// Keeps the current summary while fetching, then softly exchanges changed
/// conditions. The child key describes visible content, not loading activity.
class WeatherSoftSwap extends StatelessWidget {
  const WeatherSoftSwap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: Duration(milliseconds: reduced ? 0 : 320),
      reverseDuration: Duration(milliseconds: reduced ? 0 : 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, ?current],
      ),
      transitionBuilder: (content, animation) => AnimatedBuilder(
        animation: animation,
        child: content,
        builder: (context, content) {
          final leaving = animation.status == AnimationStatus.reverse;
          final sigma = reduced ? 0.0 : 4 * (1 - animation.value);
          return IgnorePointer(
            ignoring: leaving || animation.value < 0.95,
            child: ExcludeSemantics(
              excluding: leaving,
              child: ImageFiltered(
                enabled: sigma > 0.01,
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: sigma,
                  sigmaY: sigma,
                  tileMode: ui.TileMode.decal,
                ),
                child: Opacity(opacity: animation.value, child: content),
              ),
            ),
          );
        },
      ),
      child: child,
    );
  }
}
