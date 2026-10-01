import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:docket/features/weather/application/weather_provider.dart';
import 'package:docket/features/weather/domain/weather_snapshot.dart';

class FakeLocation implements WeatherLocation {
  LocationPermission value = LocationPermission.denied;
  int requests = 0, fixes = 0;
  bool serviceEnabled = true;
  @override
  Future<bool> get enabled async => serviceEnabled;
  @override
  Future<LocationPermission> permission(bool request) async {
    if (request) {
      requests++;
      value = LocationPermission.whileInUse;
    }
    return value;
  }

  @override
  Future<WeatherTarget> locate() async {
    fixes++;
    return const WeatherTarget(
      latitude: 12.9716,
      longitude: 77.5946,
      label: 'Near you',
    );
  }
}

http.Response response({int code = 0, DateTime? fetchedAt}) => http.Response(
  jsonEncode({
    'temperatureC': 26.4,
    'code': code,
    'isDay': false,
    'time': '2026-09-30T13:00:00Z',
    'fetchedAt': (fetchedAt ?? DateTime.now().toUtc()).toIso8601String(),
    'utcOffsetSeconds': 19800,
    'forecast': false,
  }),
  200,
);

void main() {
  test('WMO mapping covers fog, freezing rain, snow and hail storms', () {
    expect(conditionForCode(48), WeatherCondition.fog);
    expect(conditionForCode(67), WeatherCondition.rain);
    expect(conditionForCode(86), WeatherCondition.snow);
    expect(conditionForCode(99), WeatherCondition.thunderstorm);
    expect(conditionForCode(999), WeatherCondition.unknown);
  });
  test('repository rounds location and preserves UTC forecast time', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/v1/weather');
      expect(request.url.queryParameters['latitude'], '12.97');
      expect(request.url.queryParameters['longitude'], '77.59');
      expect(request.url.queryParameters['at'], '2026-10-01T10:00:00.000Z');
      return response();
    });
    addTearDown(client.close);
    final value = await WeatherRepository('https://weather.test', client).fetch(
      WeatherTarget(
        latitude: 12.9716,
        longitude: 77.5946,
        label: 'Trip',
        at: DateTime.utc(2026, 10, 1, 10),
      ),
    );
    expect(value.localTime.hour, 18);
    expect(value.localTime.minute, 30);
    expect(value.isDay, isFalse);
  });
  test(
    'opening never prompts; explicit request fetches once and recent data is cached',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return response(code: 95);
      });
      final location = FakeLocation();
      final controller = WeatherController(
        WeatherRepository('https://weather.test', client),
        location,
      );
      addTearDown(controller.dispose);
      addTearDown(client.close);
      await controller.refresh();
      expect(controller.state.status, WeatherStatus.idle);
      expect(location.requests, 0);
      expect(calls, 0);
      await controller.refresh(requestPermission: true);
      expect(
        controller.state.snapshot!.condition,
        WeatherCondition.thunderstorm,
      );
      await controller.refresh();
      expect(calls, 1);
      expect(location.fixes, 1);
    },
  );
  test(
    'recent weather survives provider failure and is marked stale',
    () async {
      var calls = 0;
      final client = MockClient(
        (request) async => ++calls == 1 ? response() : http.Response('', 503),
      );
      final controller = WeatherController(
        WeatherRepository('https://weather.test', client),
        FakeLocation(),
      );
      addTearDown(controller.dispose);
      addTearDown(client.close);
      await controller.refresh(requestPermission: true);
      await controller.refresh(requestPermission: true);
      expect(controller.state.stale, isTrue);
      expect(controller.state.snapshot, isNotNull);
      expect(controller.state.status, WeatherStatus.unavailable);
    },
  );
  test(
    'switching forecast target ignores a late result for the previous destination',
    () async {
      final first = Completer<http.Response>();
      final client = MockClient(
        (request) async => request.url.queryParameters['latitude'] == '1.00'
            ? first.future
            : response(code: 71),
      );
      final controller = WeatherController(
        WeatherRepository('https://weather.test', client),
        FakeLocation(),
      );
      addTearDown(controller.dispose);
      addTearDown(client.close);
      final slow = controller.refresh(
        target: const WeatherTarget(
          latitude: 1,
          longitude: 1,
          label: 'First trip',
        ),
      );
      await controller.refresh(
        target: const WeatherTarget(
          latitude: 2,
          longitude: 2,
          label: 'Next event',
        ),
      );
      first.complete(response(code: 95));
      await slow;
      expect(controller.state.label, 'Next event');
      expect(controller.state.snapshot!.condition, WeatherCondition.snow);
    },
  );
  test('denied forever and location-off never call the provider', () async {
    final client = MockClient((request) async {
      fail('must not fetch without location');
    });
    final location = FakeLocation()..value = LocationPermission.deniedForever;
    final controller = WeatherController(
      WeatherRepository('https://weather.test', client),
      location,
    );
    addTearDown(controller.dispose);
    addTearDown(client.close);
    await controller.refresh();
    expect(controller.state.status, WeatherStatus.deniedForever);
    location.serviceEnabled = false;
    await controller.refresh(requestPermission: true);
    expect(controller.state.status, WeatherStatus.locationOff);
  });
}
