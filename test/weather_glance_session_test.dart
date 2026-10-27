import 'package:docket/features/weather/application/weather_glance_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'automatic opening is consumed even after cancel or route return',
    (tester) async {
      var opens = 0;
      final session = WeatherGlanceSession(
        onOpen: () => opens++,
        onClose: () {},
      );
      addTearDown(session.dispose);
      session.scheduleOpening();
      await tester.pump(const Duration(seconds: 1));
      expect(opens, 1);
      session.cancel();
      session.scheduleOpening();
      await tester.pump(const Duration(seconds: 2));
      expect(opens, 1);
      session.openedManually();
      expect(session.isShowing, isTrue);
    },
  );

  testWidgets(
    'opens after one second and gives settled content seven seconds',
    (tester) async {
      var opens = 0;
      var closes = 0;
      final session = WeatherGlanceSession(
        onOpen: () => opens++,
        onClose: () => closes++,
      );
      addTearDown(session.dispose);
      session.scheduleOpening();
      await tester.pump(const Duration(milliseconds: 999));
      expect(opens, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(opens, 1);
      await tester.pump(const Duration(seconds: 20));
      expect(session.phase, WeatherGlancePhase.weather);
      expect(closes, 0, reason: 'Loading must not consume the reading time.');
      session.setRefreshing(false);
      await tester.pump(const Duration(seconds: 3));
      expect(session.phase, WeatherGlancePhase.upcoming);
      await tester.pump(const Duration(seconds: 4));
      expect(closes, 1);
      expect(session.phase, WeatherGlancePhase.idle);
    },
  );

  testWidgets('touch cancels a pending automatic reveal; manual still works', (
    tester,
  ) async {
    var opens = 0;
    var closes = 0;
    final session = WeatherGlanceSession(
      onOpen: () => opens++,
      onClose: () => closes++,
    );
    addTearDown(session.dispose);
    session.scheduleOpening();
    session.pause();
    session.resume();
    await tester.pump(const Duration(seconds: 2));
    expect(opens, 0);
    session.openedManually();
    expect(session.isShowing, isTrue);
    session.pause();
    await tester.pump(const Duration(seconds: 10));
    expect(closes, 0, reason: 'Never close while the user is interacting.');
    session.resume();
    await tester.pump(const Duration(seconds: 7));
    expect(closes, 1);
  });

  testWidgets('refresh resets the cycle and cancellation removes every timer', (
    tester,
  ) async {
    var closes = 0;
    final session = WeatherGlanceSession(
      onOpen: () {},
      onClose: () => closes++,
    );
    session.openedManually();
    await tester.pump(const Duration(seconds: 3));
    expect(session.phase, WeatherGlancePhase.upcoming);
    session.setRefreshing(true);
    expect(session.phase, WeatherGlancePhase.weather);
    await tester.pump(const Duration(seconds: 10));
    expect(closes, 0);
    session.setRefreshing(false);
    session.cancel();
    await tester.pump(const Duration(seconds: 10));
    expect(closes, 0);
    session.scheduleOpening();
    session.dispose();
    await tester.pump(const Duration(seconds: 10));
  });
}
