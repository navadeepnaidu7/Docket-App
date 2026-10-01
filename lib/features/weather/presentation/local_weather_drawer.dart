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
  });
  final ValueNotifier<double> offset;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final VoidCallback onDragCancel;
  final List<PassportProfile> passports;
  final List<IdDocument> idDocs;
  final double panelHeight;
  @override
  ConsumerState<LocalWeatherDrawer> createState() => _LocalWeatherDrawerState();
}

class _LocalWeatherDrawerState extends ConsumerState<LocalWeatherDrawer>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;
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

  void _refresh() {
    if (mounted &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      unawaited(ref.read(weatherProvider.notifier).refresh());
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
    final state = ref.watch(weatherProvider);
    return EasterEggDrawer(
      dragOffsetNotifier: widget.offset,
      panelHeight: widget.panelHeight,
      onDragStart: widget.onDragStart,
      onDragUpdate: widget.onDragUpdate,
      onDragEnd: widget.onDragEnd,
      onDragCancel: widget.onDragCancel,
      passports: widget.passports,
      idDocs: widget.idDocs,
      initialPreviewMode: kDebugMode
          ? ref.watch(skyPreviewProvider)
          : SkyPreviewMode.automatic,
      weatherState: state,
      onWeatherAction: () {
        if (state.status == WeatherStatus.deniedForever) {
          unawaited(Geolocator.openAppSettings());
        } else if (state.status == WeatherStatus.locationOff) {
          unawaited(Geolocator.openLocationSettings());
        } else {
          unawaited(
            ref.read(weatherProvider.notifier).refresh(requestPermission: true),
          );
        }
      },
    );
  }
}
