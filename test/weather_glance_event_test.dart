import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:docket/features/weather/domain/weather_glance_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 15, 12);

  test('uses the nearest real upcoming pass and its title', () {
    final event = WeatherGlanceEvent.next([
      TrainPassItem.fromJson({
        'id': 'train',
        'departAt': now.add(const Duration(days: 2)).toIso8601String(),
        'trainTitle': 'Coastal Express',
      }),
      MoviePassItem.fromJson({
        'id': 'movie',
        'showAt': now.add(const Duration(hours: 4)).toIso8601String(),
        'movieTitle': 'Evening show',
      }),
    ], now);
    expect(event?.title, 'Movie in 4 hours');
    expect(event?.detail, 'Evening show');
    expect(event?.id, 'movie');
  });

  test('formats days and singular minutes without inventing unknown dates', () {
    final train = TrainPassItem.fromJson({
      'id': 'train',
      'departAt': now.add(const Duration(days: 2)).toIso8601String(),
    });
    expect(WeatherGlanceEvent.next([train], now)?.title, 'Train in 2 days');
    expect(
      WeatherGlanceEvent.next([
        train,
      ], now.add(const Duration(seconds: 1)))?.title,
      'Train in 2 days',
    );
    final movie = MoviePassItem.fromJson({
      'id': 'soon',
      'showAt': now.add(const Duration(minutes: 1)).toIso8601String(),
    });
    expect(WeatherGlanceEvent.next([movie], now)?.title, 'Movie in 1 minute');
    expect(
      WeatherGlanceEvent.next([
        TrainPassItem.fromJson({'id': 'unknown'}),
      ], now),
      isNull,
    );
    expect(
      WeatherGlanceEvent.next([train], now.add(const Duration(days: 3))),
      isNull,
    );
  });
}
