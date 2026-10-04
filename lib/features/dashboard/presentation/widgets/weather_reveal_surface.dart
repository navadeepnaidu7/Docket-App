import 'package:flutter/material.dart';

/// Uncovers the sky without resizing the wallet or separating its navigation.
class WeatherRevealSurface extends StatelessWidget {
  const WeatherRevealSurface({
    super.key,
    required this.offset,
    required this.panelHeight,
    required this.drawer,
    required this.child,
  });

  final ValueNotifier<double> offset;
  final double panelHeight;
  final Widget drawer;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: offset,
    // Isolate the expensive wallet paint; dragging only moves this layer.
    child: RepaintBoundary(child: child),
    builder: (context, distance, wallet) {
      return ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (distance > 0.5) Positioned.fill(child: drawer),
            Transform.translate(
              key: const ValueKey('weather_wallet_translation'),
              offset: Offset(0, distance),
              child: ClipRRect(
                // Keep the phone-proportioned curve throughout the slide,
                // including rest. The screen moves; its shape does not morph.
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(
                    (MediaQuery.sizeOf(context).width * 0.105).clamp(
                      32.0,
                      48.0,
                    ),
                  ),
                ),
                child: ColoredBox(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: wallet!,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
