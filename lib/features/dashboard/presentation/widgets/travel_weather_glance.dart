import 'package:flutter/material.dart';

/// Ambient local-time scenery, not a weather forecast.
class TravelWeatherGlance extends StatefulWidget {
  const TravelWeatherGlance({super.key, required this.hour, this.progress = 1});
  final int hour;
  final double progress;

  @override
  State<TravelWeatherGlance> createState() => _TravelWeatherGlanceState();
}

class _TravelWeatherGlanceState extends State<TravelWeatherGlance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 80),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      _drift.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final night = widget.hour < 6 || widget.hour >= 21;
    final evening = widget.hour >= 17 && widget.hour < 21;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return ExcludeSemantics(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF214C79)),
            AnimatedBuilder(
              animation: _drift,
              child: Image.asset(
                'assets/weather/docket_sky.png',
                fit: BoxFit.cover,
                alignment: const Alignment(0.3, -1),
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => const SizedBox.expand(),
              ),
              builder: (context, child) => Transform.scale(
                scale: reduced ? 1 : 1.10,
                child: Transform.translate(
                  offset: reduced
                      ? Offset.zero
                      : Offset(
                          -10 + _drift.value * 20,
                          (1 - widget.progress) * -10,
                        ),
                  child: child,
                ),
              ),
            ),
            if (night || evening)
              ColoredBox(
                color: night
                    ? const Color(0xCC08132E)
                    : const Color(0x665B355D),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x050A2344),
                    Color(0x66102748),
                    Color(0xFF132B48),
                  ],
                  stops: [0, 0.5, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
