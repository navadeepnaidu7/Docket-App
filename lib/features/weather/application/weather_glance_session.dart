import 'dart:async';

import 'package:flutter/foundation.dart';

enum WeatherGlancePhase { idle, waiting, weather, upcoming }

/// Owns the short glance's timing, independently of network and drag motion.
class WeatherGlanceSession extends ChangeNotifier {
  WeatherGlanceSession({required this.onOpen, required this.onClose});

  final VoidCallback onOpen;
  final VoidCallback onClose;
  Timer? _opening;
  Timer? _upcoming;
  Timer? _closing;
  WeatherGlancePhase _phase = WeatherGlancePhase.idle;
  bool _refreshing = false;
  bool _paused = false;
  bool _showUpcoming = false;
  bool _openingScheduled = false;

  WeatherGlancePhase get phase => _phase;
  // Retain the last content while the closing glide runs; do not flash back
  // to weather underneath an outgoing event.
  bool get showUpcoming => _showUpcoming;
  bool get isShowing =>
      _phase == WeatherGlancePhase.weather ||
      _phase == WeatherGlancePhase.upcoming;

  void scheduleOpening() {
    if (_openingScheduled) return;
    _openingScheduled = true;
    cancel();
    _setPhase(WeatherGlancePhase.waiting);
    _opening = Timer(const Duration(seconds: 1), () {
      _refreshing = true;
      _setPhase(WeatherGlancePhase.weather);
      onOpen();
    });
  }

  void openedManually() {
    _opening?.cancel();
    _paused = false;
    _setPhase(WeatherGlancePhase.weather);
    if (!_refreshing) _startReadingTime();
  }

  void setRefreshing(bool refreshing) {
    if (_refreshing == refreshing) return;
    _refreshing = refreshing;
    _cancelReadingTime();
    if (!isShowing) return;
    if (refreshing) {
      _setPhase(WeatherGlancePhase.weather);
    } else if (!_paused) {
      _startReadingTime();
    }
  }

  /// Touch and navigation take priority over any scheduled movement.
  void pause() {
    _opening?.cancel();
    _cancelReadingTime();
    _paused = true;
    if (_phase == WeatherGlancePhase.waiting) {
      _setPhase(WeatherGlancePhase.idle);
    }
  }

  void resume() {
    _paused = false;
    if (isShowing && !_refreshing) _startReadingTime();
  }

  void _startReadingTime() {
    _cancelReadingTime();
    _upcoming = Timer(const Duration(seconds: 3), () {
      _setPhase(WeatherGlancePhase.upcoming);
    });
    _closing = Timer(const Duration(seconds: 7), () {
      cancel();
      onClose();
    });
  }

  void _cancelReadingTime() {
    _upcoming?.cancel();
    _closing?.cancel();
  }

  void cancel() {
    _opening?.cancel();
    _cancelReadingTime();
    _paused = false;
    _setPhase(WeatherGlancePhase.idle);
  }

  void _setPhase(WeatherGlancePhase phase) {
    if (_phase == phase) return;
    _phase = phase;
    if (phase == WeatherGlancePhase.weather) _showUpcoming = false;
    if (phase == WeatherGlancePhase.upcoming) _showUpcoming = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _opening?.cancel();
    _cancelReadingTime();
    super.dispose();
  }
}
