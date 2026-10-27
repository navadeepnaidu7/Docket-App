import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/dev/sky_preview.dart';
import '../../../weather/application/weather_provider.dart';
import '../../../weather/domain/weather_snapshot.dart';
import '../../../weather/domain/weather_glance_event.dart';
export '../../../../core/dev/sky_preview.dart' show SkyPreviewMode;

import '../../../ids/domain/id_document.dart';
import '../../../passport/domain/passport_profile.dart';
import 'easter_egg_constants.dart';
import 'travel_weather_glance.dart';
import 'weather_soft_transition.dart';

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
    this.refreshing = false,
    this.event,
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
  final bool refreshing;
  final WeatherGlanceEvent? event;

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

    final event = widget.event;
    final busy = widget.refreshing || state.status == WeatherStatus.loading;
    final copyKey = event != null
        ? 'event:${event.id}:${event.title}:${event.detail}'
        : snapshot == null
        ? '$greeting:${state.status}:${widget.onWeatherAction != null}:$count'
        : '$greeting:${snapshot.temperatureC.round()}:${snapshot.code}:${snapshot.isDay}:${state.stale}';

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
          final reveal = Curves.easeInOutCubic.transform(
            ((progress - 0.25) / 0.75).clamp(0.0, 1.0),
          );
          final safeTop = MediaQuery.paddingOf(context).top;
          final contentHeight = (widget.panelHeight - safeTop - 28).clamp(
            48.0,
            widget.panelHeight,
          );
          // Bound both filters to the exposed strip and its corner allowance.
          return ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: double.infinity,
                height: (offset + 48).clamp(48, widget.panelHeight * 2 + 48),
                child: WeatherRefreshVeil(
                  refreshing: busy,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        child: ClipRect(
                          child: WeatherActivityBackdrop(
                            key: const ValueKey('weather_sky_blur'),
                            active: event != null,
                            progress: progress,
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
                        ),
                      ),
                      Positioned(
                        left: 24,
                        right: 24,
                        top: safeTop + 14,
                        height: contentHeight,
                        child: IgnorePointer(
                          ignoring: progress < 0.95,
                          child: ExcludeSemantics(
                            excluding: progress < 0.95,
                            child: WeatherRevealBlur(
                              key: const ValueKey('weather_text_blur'),
                              progress: progress,
                              maxBlur: 6,
                              tileMode: ui.TileMode.decal,
                              child: Opacity(
                                opacity: reveal,
                                child: Transform.translate(
                                  offset: Offset(
                                    0,
                                    reduced ? 0 : 5 * (1 - reveal),
                                  ),
                                  child: SingleChildScrollView(
                                    physics:
                                        MediaQuery.textScalerOf(
                                              context,
                                            ).scale(14) >
                                            18
                                        ? null
                                        : const NeverScrollableScrollPhysics(),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight: contentHeight,
                                      ),
                                      child: WeatherSoftSwap(
                                        child: WeatherCopy(
                                          key: ValueKey(copyKey),
                                          heading: Text(
                                            event?.title ?? greeting,
                                            style: TextStyle(
                                              fontFamily: font,
                                              fontSize: 21,
                                              height: 1.2,
                                              decoration: TextDecoration.none,
                                              fontWeight: FontWeight.w500,
                                              letterSpacing: -0.45,
                                              color: Colors.white,
                                            ),
                                          ),
                                          detail: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (event != null) ...[
                                                const SizedBox(height: 6),
                                                Text(
                                                  event.detail,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: _bodyStyle(font),
                                                ),
                                              ] else
                                                ..._weatherSummary(
                                                  state,
                                                  snapshot,
                                                  count,
                                                  font,
                                                ),
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
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  TextStyle _bodyStyle(String? font) => TextStyle(
    fontFamily: font,
    fontSize: 18,
    height: 1.2,
    decoration: TextDecoration.none,
    color: Colors.white,
  );

  List<Widget> _weatherSummary(
    WeatherState state,
    WeatherSnapshot? snapshot,
    int count,
    String? font,
  ) {
    if (snapshot != null) {
      return [
        const SizedBox(height: 6),
        Text(
          '${snapshot.temperatureC.round()}°C · ${snapshot.description}',
          style: _bodyStyle(font),
        ),
        if (state.stale) ...[
          const SizedBox(height: 8),
          const Text(
            'Updated earlier',
            style: TextStyle(
              fontSize: 12,
              decoration: TextDecoration.none,
              color: Color(0xE0FFFFFF),
            ),
          ),
        ],
      ];
    }
    if (state.status == WeatherStatus.loading) return const [];
    if (widget.onWeatherAction != null) {
      return [
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
            onPressed: state.status == WeatherStatus.loading
                ? null
                : widget.onWeatherAction,
            child: Text(switch (state.status) {
              WeatherStatus.loading => '',
              WeatherStatus.deniedForever => 'Allow location in Settings',
              WeatherStatus.locationOff => 'Turn on location for weather',
              WeatherStatus.unavailable => 'Retry local weather',
              WeatherStatus.denied => 'Use location for weather',
              _ => 'Show local weather',
            }, style: const TextStyle(color: Color(0xE0FFFFFF))),
          ),
        ),
      ];
    }
    return [
      const SizedBox(height: 7),
      Text(
        count == 0
            ? 'No documents yet'
            : '$count ${count == 1 ? 'document' : 'documents'} in your wallet',
        style: TextStyle(
          fontFamily: font,
          fontSize: 14,
          height: 1.35,
          decoration: TextDecoration.none,
          color: const Color(0xE0FFFFFF),
        ),
      ),
    ];
  }
}
