import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/dev/sky_preview.dart';
import '../../../weather/application/weather_provider.dart';
import '../../../weather/domain/weather_snapshot.dart';
export '../../../../core/dev/sky_preview.dart' show SkyPreviewMode;

import '../../../ids/domain/id_document.dart';
import '../../../passport/domain/passport_profile.dart';
import 'easter_egg_constants.dart';
import 'travel_weather_glance.dart';

/// A brief, quiet glance behind the home surface.
class EasterEggDrawer extends StatefulWidget {
  const EasterEggDrawer({
    super.key,
    required this.dragOffsetNotifier,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
    required this.passports,
    required this.idDocs,
    this.now,
    this.weather,
    this.initialPreviewMode = SkyPreviewMode.automatic,
    this.onDragStart,
    this.weatherState = const WeatherState(),
    this.onWeatherAction,
    this.panelHeight = kEasterEggPanelHeight,
  });

  final ValueNotifier<double> dragOffsetNotifier;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final VoidCallback onDragCancel;
  final List<PassportProfile> passports;
  final List<IdDocument> idDocs;
  final DateTime? now;
  final SkyWeather? weather;
  final SkyPreviewMode initialPreviewMode;
  final GestureDragStartCallback? onDragStart;
  final WeatherState weatherState;
  final VoidCallback? onWeatherAction;
  final double panelHeight;

  @override
  State<EasterEggDrawer> createState() => _EasterEggDrawerState();
}

class _EasterEggDrawerState extends State<EasterEggDrawer> {
  Timer? _clock;
  SkyPreviewMode get _previewMode =>
      kDebugMode ? widget.initialPreviewMode : SkyPreviewMode.automatic;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final count = widget.passports.length + widget.idDocs.length;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final state = widget.weatherState;
    final snapshot = state.snapshot;
    final autoWeather =
        widget.weather ??
        switch (snapshot?.condition) {
          WeatherCondition.clear => SkyWeather.clear,
          WeatherCondition.partlyCloudy =>
            snapshot!.code == 1 ? SkyWeather.sunlight : SkyWeather.partlyCloudy,
          WeatherCondition.cloudy => SkyWeather.cloudy,
          WeatherCondition.fog => SkyWeather.fog,
          WeatherCondition.drizzle => SkyWeather.drizzle,
          WeatherCondition.rain =>
            snapshot!.code == 65 || snapshot.code == 82
                ? SkyWeather.heavyRain
                : SkyWeather.rain,
          WeatherCondition.snow => SkyWeather.snow,
          WeatherCondition.thunderstorm => SkyWeather.thunderstorm,
          _ => SkyWeather.clear,
        };
    final weather = switch (_previewMode) {
      SkyPreviewMode.automatic => autoWeather,
      SkyPreviewMode.drizzle => SkyWeather.drizzle,
      SkyPreviewMode.rain => SkyWeather.rain,
      SkyPreviewMode.clear => SkyWeather.clear,
      SkyPreviewMode.night => SkyWeather.clear,
      SkyPreviewMode.partlyCloudy => SkyWeather.partlyCloudy,
      SkyPreviewMode.mostlyCloudy => SkyWeather.mostlyCloudy,
      SkyPreviewMode.cloudy => SkyWeather.cloudy,
      SkyPreviewMode.fog => SkyWeather.fog,
      SkyPreviewMode.snow => SkyWeather.snow,
      SkyPreviewMode.heavyRain => SkyWeather.heavyRain,
      SkyPreviewMode.thunderstorm => SkyWeather.thunderstorm,
      _ => SkyWeather.sunlight,
    };
    final skyHour = switch (_previewMode) {
      SkyPreviewMode.automatic => snapshot?.localTime.hour ?? now.hour,
      SkyPreviewMode.sunset => 18,
      SkyPreviewMode.night => 23,
      _ => 10,
    };
    final font = Theme.of(context).textTheme.bodyMedium?.fontFamily;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: widget.onDragStart,
      onVerticalDragUpdate: widget.onDragUpdate,
      onVerticalDragEnd: widget.onDragEnd,
      onVerticalDragCancel: widget.onDragCancel,
      child: ValueListenableBuilder<double>(
        valueListenable: widget.dragOffsetNotifier,
        builder: (context, offset, _) {
          final progress = (offset / widget.panelHeight).clamp(0.0, 1.0);
          final reveal = Curves.easeOutCubic.transform(
            ((progress - 0.15) / 0.72).clamp(0.0, 1.0),
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              // Only shade the exposed pixels, including a small overpull margin.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: (offset + 48).clamp(48, widget.panelHeight * 2 + 48),
                child: RepaintBoundary(
                  child: TravelWeatherGlance(
                    hour: skyHour,
                    panelHeight: widget.panelHeight,
                    progress: progress,
                    weather: weather,
                    isDay: _previewMode == SkyPreviewMode.automatic
                        ? snapshot?.isDay
                        : null,
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                top: MediaQuery.paddingOf(context).top + 20,
                height:
                    (widget.panelHeight -
                            MediaQuery.paddingOf(context).top -
                            36)
                        .clamp(48.0, widget.panelHeight),
                child: IgnorePointer(
                  ignoring: progress < 0.8,
                  child: ExcludeSemantics(
                    excluding: progress < 0.8,
                    child: Opacity(
                      opacity: reveal,
                      child: Transform.translate(
                        offset: Offset(0, reduced ? 0 : 5 * (1 - reveal)),
                        child: LayoutBuilder(
                          builder: (context, constraints) => SingleChildScrollView(
                            physics:
                                MediaQuery.textScalerOf(context).scale(14) > 18
                                ? null
                                : const NeverScrollableScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    greeting,
                                    style: TextStyle(
                                      fontFamily: font,
                                      fontSize: 21,
                                      decoration: TextDecoration.none,
                                      height: 1.2,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: -0.45,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (snapshot != null) ...[
                                    const SizedBox(height: 6),
                                    AnimatedSwitcher(
                                      duration: Duration(
                                        milliseconds: reduced ? 0 : 260,
                                      ),
                                      child: Text(
                                        '${snapshot.temperatureC.round()}°C · ${snapshot.description}',
                                        key: ValueKey(
                                          '${snapshot.temperatureC.round()}:${snapshot.code}:${state.label}',
                                        ),
                                        style: TextStyle(
                                          fontFamily: font,
                                          fontSize: 18,
                                          height: 1.2,
                                          decoration: TextDecoration.none,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    if (state.stale) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Updated earlier',
                                        style: TextStyle(
                                          fontFamily: font,
                                          fontSize: 12,
                                          decoration: TextDecoration.none,
                                          color: const Color(0xE0FFFFFF),
                                        ),
                                      ),
                                    ],
                                  ] else if (widget.onWeatherAction !=
                                      null) ...[
                                    const SizedBox(height: 4),
                                    Material(
                                      color: Colors.transparent,
                                      child: TextButton(
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(44, 44),
                                          alignment: Alignment.centerLeft,
                                        ),
                                        onPressed:
                                            state.status ==
                                                WeatherStatus.loading
                                            ? null
                                            : widget.onWeatherAction,
                                        child: Text(
                                          switch (state.status) {
                                            WeatherStatus.loading =>
                                              'Finding local weather…',
                                            WeatherStatus.deniedForever =>
                                              'Allow location in Settings',
                                            WeatherStatus.locationOff =>
                                              'Turn on location for weather',
                                            WeatherStatus.unavailable =>
                                              'Weather unavailable · Retry',
                                            WeatherStatus.denied =>
                                              'Use location for weather',
                                            _ => 'Show local weather',
                                          },
                                          style: const TextStyle(
                                            color: Color(0xE0FFFFFF),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (snapshot == null) ...[
                                    const SizedBox(height: 7),
                                    Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: count == 0
                                                ? 'No documents yet'
                                                : '$count ${count == 1 ? 'document' : 'documents'}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (count > 0)
                                            const TextSpan(
                                              text: ' in your wallet',
                                            ),
                                        ],
                                      ),
                                      style: TextStyle(
                                        fontFamily: font,
                                        fontSize: 14,
                                        decoration: TextDecoration.none,
                                        height: 1.35,
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: -0.1,
                                        color: const Color(0xE0FFFFFF),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
