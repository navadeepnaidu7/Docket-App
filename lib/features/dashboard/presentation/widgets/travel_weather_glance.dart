import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'easter_egg_constants.dart';

/// Ambient scenes, deliberately independent of any unconnected weather API.
enum SkyWeather { sunlight, drizzle }

class TravelWeatherGlance extends StatefulWidget {
  const TravelWeatherGlance({
    super.key,
    required this.hour,
    this.progress = 1,
    this.weather = SkyWeather.sunlight,
  });

  final int hour;
  final double progress;
  final SkyWeather weather;

  static ui.FragmentProgram? _program;
  static Future<ui.FragmentProgram?>? _loading;

  /// Compile once while the dashboard is idle, before the first pull.
  static Future<ui.FragmentProgram?> warmUp() =>
      _program != null ? Future.value(_program) : (_loading ??= _loadProgram());

  static Future<ui.FragmentProgram?> _loadProgram() async {
    try {
      _program = await ui.FragmentProgram.fromAsset(
        'assets/shaders/docket_sky.frag',
      );
      return _program;
    } catch (error) {
      debugPrint('Ambient sky unavailable: $error');
      return null;
    }
  }

  @override
  State<TravelWeatherGlance> createState() => _TravelWeatherGlanceState();
}

class _TravelWeatherGlanceState extends State<TravelWeatherGlance>
    with TickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(days: 1),
  );
  ui.FragmentShader? _shader;
  late final AnimationController _sceneBlend = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
    value: 1,
  );
  late List<double> _from = _target;
  late List<double> _to = _target;

  List<double> get _target => [
    widget.hour < 6 || widget.hour >= 21 ? 1 : 0,
    widget.hour >= 17 && widget.hour < 21 ? 1 : 0,
    widget.weather == SkyWeather.drizzle ? 1 : 0,
  ];

  @override
  void didUpdateWidget(covariant TravelWeatherGlance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hour == widget.hour && oldWidget.weather == widget.weather) {
      return;
    }
    final t = Curves.easeInOut.transform(_sceneBlend.value);
    _from = List.generate(3, (i) => ui.lerpDouble(_from[i], _to[i], t)!);
    _to = _target;
    if (MediaQuery.disableAnimationsOf(context)) {
      _sceneBlend.value = 1;
    } else {
      _sceneBlend.forward(from: 0);
    }
  }

  @override
  void initState() {
    super.initState();
    _prepareSky();
  }

  Future<void> _prepareSky() async {
    final program = await TravelWeatherGlance.warmUp();
    if (mounted && program != null) {
      setState(() => _shader = program.fragmentShader());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _clock.stop();
      if (MediaQuery.disableAnimationsOf(context)) _sceneBlend.value = 1;
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    _sceneBlend.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ClipRect(
      child: CustomPaint(
        painter: _SkyPainter(
          shader: _shader,
          clock: _clock,
          sceneBlend: _sceneBlend,
          from: _from,
          to: _to,
          hour: widget.hour,
          weather: widget.weather,
          progress: MediaQuery.disableAnimationsOf(context)
              ? 1
              : widget.progress,
        ),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({
    required this.shader,
    required this.clock,
    required this.sceneBlend,
    required this.from,
    required this.to,
    required this.hour,
    required this.weather,
    required this.progress,
  }) : super(repaint: Listenable.merge([clock, sceneBlend]));

  final ui.FragmentShader? shader;
  final Animation<double> clock;
  final Animation<double> sceneBlend;
  final List<double> from;
  final List<double> to;
  final int hour;
  final SkyWeather weather;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final effect = shader;
    final night = hour < 6 || hour >= 21;
    if (effect == null) {
      // An inexpensive first frame while the compiled program loads.
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: night
                ? const [Color(0xFF23364E), Color(0xFF0C192C)]
                : const [Color(0xFF7A9CB7), Color(0xFF214569)],
          ).createShader(Offset.zero & size),
      );
      return;
    }
    final blend = Curves.easeInOut.transform(sceneBlend.value);
    effect
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, clock.value * 86400)
      ..setFloat(3, ui.lerpDouble(from[0], to[0], blend)!)
      ..setFloat(4, ui.lerpDouble(from[1], to[1], blend)!)
      ..setFloat(5, ui.lerpDouble(from[2], to[2], blend)!)
      ..setFloat(6, progress)
      ..setFloat(7, kEasterEggPanelHeight);
    canvas.drawRect(Offset.zero & size, Paint()..shader = effect);
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) =>
      old.shader != shader ||
      old.from != from ||
      old.to != to ||
      old.hour != hour ||
      old.weather != weather ||
      old.progress != progress;
}
