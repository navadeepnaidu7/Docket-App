import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../../core/dev/dev_flags_provider.dart';
import '../domain/weather_snapshot.dart';

enum WeatherStatus {
  idle,
  loading,
  ready,
  denied,
  deniedForever,
  locationOff,
  unavailable,
}

class WeatherState {
  const WeatherState({
    this.status = WeatherStatus.idle,
    this.snapshot,
    this.label = 'Near you',
    this.stale = false,
  });
  final WeatherStatus status;
  final WeatherSnapshot? snapshot;
  final String label;
  final bool stale;
}

class WeatherRepository {
  WeatherRepository(this.origin, this.client);
  final String origin;
  final http.Client client;
  Future<WeatherSnapshot> fetch(WeatherTarget target) async {
    final base = Uri.parse(origin);
    if (!base.hasAuthority ||
        (base.scheme != 'https' && base.scheme != 'http')) {
      throw const FormatException('Weather backend unavailable');
    }
    final uri = base.replace(
      path: '${base.path.replaceAll(RegExp(r'/$'), '')}/v1/weather',
      queryParameters: {
        'latitude': ((target.latitude * 100).round() / 100).toStringAsFixed(2),
        'longitude': ((target.longitude * 100).round() / 100).toStringAsFixed(
          2,
        ),
        if (target.at != null) 'at': target.at!.toUtc().toIso8601String(),
      },
    );
    final response = await client.get(uri).timeout(const Duration(seconds: 9));
    if (response.statusCode != 200) {
      throw const FormatException('Weather unavailable');
    }
    return WeatherSnapshot.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}

final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return WeatherRepository(
    ref.watch(devFlagsProvider.select((flags) => flags.apiBaseUrl)),
    client,
  );
});

abstract class WeatherLocation {
  Future<bool> get enabled;
  Future<LocationPermission> permission(bool request);
  Future<WeatherTarget> locate();
}

class DeviceWeatherLocation implements WeatherLocation {
  @override
  Future<bool> get enabled => Geolocator.isLocationServiceEnabled();
  @override
  Future<LocationPermission> permission(bool request) async {
    final permission = await Geolocator.checkPermission();
    return request && permission == LocationPermission.denied
        ? Geolocator.requestPermission()
        : permission;
  }

  @override
  Future<WeatherTarget> locate() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 8),
      ),
    );
    return WeatherTarget(
      latitude: position.latitude,
      longitude: position.longitude,
      label: 'Near you',
    );
  }
}

final weatherLocationProvider = Provider<WeatherLocation>(
  (ref) => DeviceWeatherLocation(),
);

final weatherProvider = StateNotifierProvider<WeatherController, WeatherState>(
  (ref) => WeatherController(
    ref.watch(weatherRepositoryProvider),
    ref.watch(weatherLocationProvider),
  ),
);

class WeatherController extends StateNotifier<WeatherState> {
  WeatherController(this.repository, this.location)
    : super(const WeatherState());
  final WeatherRepository repository;
  final WeatherLocation location;
  Future<void>? _pending;
  String? _pendingKey, _loadedKey;
  DateTime? _lastAttempt;
  int _generation = 0;
  Future<void> refresh({
    bool requestPermission = false,
    WeatherTarget? target,
  }) {
    final key = target == null
        ? 'local'
        : '${target.latitude}:${target.longitude}:${target.at}:${target.label}';
    if (_pending != null && _pendingKey == key) return _pending!;
    final now = DateTime.now();
    if (!requestPermission &&
        key == _loadedKey &&
        _lastAttempt != null &&
        now.difference(_lastAttempt!) < const Duration(minutes: 1)) {
      return Future.value();
    }
    _lastAttempt = now;
    final generation = ++_generation;
    _pendingKey = key;
    return _pending = _refresh(requestPermission, target, key, generation)
        .whenComplete(() {
          if (_generation == generation) {
            _pending = null;
            _pendingKey = null;
          }
        });
  }

  Future<void> _refresh(
    bool request,
    WeatherTarget? target,
    String key,
    int generation,
  ) async {
    final previous = state;
    void publish(WeatherState next) {
      if (mounted && generation == _generation) state = next;
    }

    publish(
      WeatherState(
        status: WeatherStatus.loading,
        snapshot: previous.snapshot,
        label: previous.label,
        stale: previous.stale,
      ),
    );
    try {
      if (target == null) {
        if (!await location.enabled) {
          publish(const WeatherState(status: WeatherStatus.locationOff));
          return;
        }
        final permission = await location.permission(request);
        if (permission == LocationPermission.deniedForever) {
          publish(const WeatherState(status: WeatherStatus.deniedForever));
          return;
        }
        if (permission != LocationPermission.always &&
            permission != LocationPermission.whileInUse) {
          publish(
            WeatherState(
              status: request ? WeatherStatus.denied : WeatherStatus.idle,
            ),
          );
          return;
        }
        if (!request &&
            _loadedKey == key &&
            previous.snapshot != null &&
            !previous.stale &&
            DateTime.now().toUtc().difference(previous.snapshot!.fetchedAt) <
                const Duration(minutes: 15)) {
          publish(previous);
          return;
        }
        target = await location.locate();
      }
      final snapshot = await repository.fetch(target);
      if (!mounted || generation != _generation) return;
      _loadedKey = key;
      publish(
        WeatherState(
          status: WeatherStatus.ready,
          snapshot: snapshot,
          label: target.label,
        ),
      );
    } catch (_) {
      final recent =
          _loadedKey == key &&
          (previous.snapshot?.isRecent(DateTime.now()) ?? false);
      publish(
        WeatherState(
          status: WeatherStatus.unavailable,
          snapshot: recent ? previous.snapshot : null,
          label: previous.label,
          stale: recent,
        ),
      );
    }
  }
}
