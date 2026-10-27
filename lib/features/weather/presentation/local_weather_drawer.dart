import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/dev/sky_preview.dart';
import '../../dashboard/presentation/widgets/easter_egg_drawer.dart';
import '../../ids/domain/id_document.dart';
import '../../passport/domain/passport_profile.dart';
import '../application/weather_provider.dart';
import '../application/weather_glance_session.dart';
import '../domain/weather_glance_event.dart';
import '../domain/weather_snapshot.dart';
import '../../tickets/application/pass_list_provider.dart';

class LocalWeatherDrawer extends ConsumerStatefulWidget {
  const LocalWeatherDrawer({
    super.key,
    required this.offset,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
    required this.passports,
    required this.idDocs,
    required this.panelHeight,
    required this.session,
  });
  final ValueNotifier<double> offset;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final VoidCallback onDragCancel;
  final List<PassportProfile> passports;
  final List<IdDocument> idDocs;
  final double panelHeight;
  final WeatherGlanceSession session;
  @override
  ConsumerState<LocalWeatherDrawer> createState() => _LocalWeatherDrawerState();
}

class _LocalWeatherDrawerState extends ConsumerState<LocalWeatherDrawer>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;
  bool _refreshing = true;
  int _refreshGeneration = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refresh(),
    );
  }

  Future<void> _refresh({bool requestPermission = false}) async {
    if (!mounted ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    setState(() => _refreshing = true);
    final generation = ++_refreshGeneration;
    widget.session.setRefreshing(true);
    final preview = kDebugMode
        ? ref.read(weatherGlancePreviewProvider)
        : WeatherGlancePreview.live;
    try {
      if (preview == WeatherGlancePreview.live) {
        await ref
            .read(weatherProvider.notifier)
            .refresh(requestPermission: requestPermission);
      } else {
        // Explicit Developer preview only: exercise the complete flow offline.
        await Future<void>.delayed(const Duration(milliseconds: 900));
      }
    } finally {
      if (mounted && generation == _refreshGeneration) {
        setState(() => _refreshing = false);
        widget.session.setRefreshing(false);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = kDebugMode
        ? ref.watch(weatherGlancePreviewProvider)
        : WeatherGlancePreview.live;
    final now = DateTime.now();
    final state = preview == WeatherGlancePreview.live
        ? ref.watch(weatherProvider)
        : WeatherState(
            status: WeatherStatus.ready,
            snapshot: WeatherSnapshot(
              temperatureC: 24,
              code: 2,
              isDay: now.hour >= 6 && now.hour < 21,
              time: now.toUtc(),
              fetchedAt: now.toUtc(),
              utcOffsetSeconds: now.timeZoneOffset.inSeconds,
            ),
          );
    final event = switch (preview) {
      WeatherGlancePreview.movie => const WeatherGlanceEvent(
        id: 'preview-movie',
        title: 'Movie in 4 hours',
        detail: 'Preview · evening show',
        kind: 'Movie',
      ),
      WeatherGlancePreview.train => const WeatherGlanceEvent(
        id: 'preview-train',
        title: 'Train in 2 days',
        detail: 'Preview · upcoming journey',
        kind: 'Train',
      ),
      WeatherGlancePreview.live => WeatherGlanceEvent.next(
        ref.watch(passListProvider).valueOrNull ?? const [],
        now,
      ),
    };
    final skyPreview = kDebugMode
        ? ref.watch(skyPreviewProvider)
        : SkyPreviewMode.automatic;
    return ListenableBuilder(
      listenable: widget.session,
      builder: (context, _) => EasterEggDrawer(
        dragOffsetNotifier: widget.offset,
        panelHeight: widget.panelHeight,
        onDragStart: widget.onDragStart,
        onDragUpdate: widget.onDragUpdate,
        onDragEnd: widget.onDragEnd,
        onDragCancel: widget.onDragCancel,
        passports: widget.passports,
        idDocs: widget.idDocs,
        initialPreviewMode: skyPreview,
        weatherState: state,
        refreshing: _refreshing,
        event: widget.session.showUpcoming && state.snapshot != null
            ? event
            : null,
        onWeatherAction: () {
          if (state.status == WeatherStatus.deniedForever) {
            unawaited(Geolocator.openAppSettings());
          } else if (state.status == WeatherStatus.locationOff) {
            unawaited(Geolocator.openLocationSettings());
          } else {
            unawaited(_refresh(requestPermission: true));
          }
        },
      ),
    );
  }
}
