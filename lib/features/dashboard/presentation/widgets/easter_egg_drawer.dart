import 'dart:async';

import 'package:flutter/material.dart';

import '../../../ids/domain/id_document.dart';
import '../../../passport/domain/passport_profile.dart';
import 'easter_egg_constants.dart';
import 'travel_weather_glance.dart';

enum SkyPreviewMode {
  automatic('Auto'),
  sunlight('Sunlight'),
  clear('Clear sky'),
  cloudy('Cloudy'),
  drizzle('Drizzle'),
  heavyRain('Heavy rain'),
  thunderstorm('Thunderstorm'),
  sunset('Sunset'),
  night('Night');

  const SkyPreviewMode(this.label);
  final String label;
}

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
    this.onPreviewModeChanged,
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
  final ValueChanged<SkyPreviewMode>? onPreviewModeChanged;

  @override
  State<EasterEggDrawer> createState() => _EasterEggDrawerState();
}

class _EasterEggDrawerState extends State<EasterEggDrawer> {
  Timer? _clock;
  late SkyPreviewMode _previewMode = widget.initialPreviewMode;

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
    // A stable daily variation. This is atmosphere, not reported conditions.
    final autoWeather =
        widget.weather ??
        (now.day % 3 == 0 ? SkyWeather.drizzle : SkyWeather.sunlight);
    final weather = switch (_previewMode) {
      SkyPreviewMode.automatic => autoWeather,
      SkyPreviewMode.drizzle => SkyWeather.drizzle,
      SkyPreviewMode.clear => SkyWeather.clear,
      SkyPreviewMode.cloudy => SkyWeather.cloudy,
      SkyPreviewMode.heavyRain => SkyWeather.heavyRain,
      SkyPreviewMode.thunderstorm => SkyWeather.thunderstorm,
      _ => SkyWeather.sunlight,
    };
    final skyHour = switch (_previewMode) {
      SkyPreviewMode.automatic => now.hour,
      SkyPreviewMode.sunset => 18,
      SkyPreviewMode.night => 23,
      _ => 10,
    };
    final font = Theme.of(context).textTheme.bodyMedium?.fontFamily;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: widget.onDragUpdate,
      onVerticalDragEnd: widget.onDragEnd,
      onVerticalDragCancel: widget.onDragCancel,
      child: ValueListenableBuilder<double>(
        valueListenable: widget.dragOffsetNotifier,
        builder: (context, offset, _) {
          final progress = (offset / kEasterEggPanelHeight).clamp(0.0, 1.0);
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
                height: (offset + 32).clamp(
                  kEasterEggPanelHeight + 32,
                  kEasterEggPanelHeight + 150,
                ),
                child: RepaintBoundary(
                  child: TravelWeatherGlance(
                    hour: skyHour,
                    progress: progress,
                    weather: weather,
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                top: MediaQuery.paddingOf(context).top + 44,
                height:
                    (kEasterEggPanelHeight -
                            MediaQuery.paddingOf(context).top -
                            68)
                        .clamp(48.0, kEasterEggPanelHeight),
                child: ExcludeSemantics(
                  excluding: progress < 0.8,
                  child: Opacity(
                    opacity: reveal,
                    child: Transform.translate(
                      offset: Offset(0, reduced ? 0 : 5 * (1 - reveal)),
                      child: LayoutBuilder(
                        builder: (context, constraints) => SingleChildScrollView(
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
                                        const TextSpan(text: ' in your wallet'),
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
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top,
                right: 16,
                child: IgnorePointer(
                  ignoring: progress < 0.8,
                  child: ExcludeSemantics(
                    excluding: progress < 0.8,
                    child: Opacity(
                      opacity: reveal,
                      child: Material(
                        type: MaterialType.transparency,
                        child: PopupMenuButton<SkyPreviewMode>(
                          tooltip: 'Change sky scene',
                          initialValue: _previewMode,
                          position: PopupMenuPosition.under,
                          color: const Color(0xFF22364B),
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          onSelected: (mode) {
                            setState(() => _previewMode = mode);
                            widget.onPreviewModeChanged?.call(mode);
                          },
                          itemBuilder: (context) => [
                            for (final mode in SkyPreviewMode.values)
                              PopupMenuItem(
                                value: mode,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        mode.label,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    if (mode == _previewMode)
                                      const Icon(
                                        Icons.check_rounded,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                  ],
                                ),
                              ),
                          ],
                          child: Semantics(
                            label: 'Sky scene: ${_previewMode.label}',
                            button: true,
                            child: Container(
                              constraints: const BoxConstraints(
                                minHeight: 44,
                                minWidth: 44,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Scene',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xE6FFFFFF),
                                    ),
                                  ),
                                  SizedBox(width: 3),
                                  Icon(
                                    Icons.expand_more_rounded,
                                    size: 15,
                                    color: Color(0xE6FFFFFF),
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
            ],
          );
        },
      ),
    );
  }
}
