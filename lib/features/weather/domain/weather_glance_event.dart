import '../../tickets/domain/pass_catalog.dart';
import '../../tickets/domain/pass_display.dart';

class WeatherGlanceEvent {
  const WeatherGlanceEvent({
    required this.id,
    required this.title,
    required this.detail,
    required this.kind,
  });

  final String id;
  final String title;
  final String detail;
  final String kind;

  static WeatherGlanceEvent? next(List<WalletPassItem> passes, DateTime now) {
    final pass = nextUpcomingPass(passes, now);
    if (pass == null) return null;
    final start = passStartTime(pass)!;
    final kind = switch (pass) {
      MoviePassItem() => 'Movie',
      TrainPassItem() => 'Train',
      BusPassItem() => 'Bus',
    };
    final remaining = start.difference(now);
    final String when;
    if (remaining.inMinutes < 1) {
      when = 'starting now';
    } else if (remaining.inHours < 1) {
      final minutes = remaining.inMinutes;
      when = 'in $minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    } else if (remaining.inHours < 24) {
      final hours = (remaining.inSeconds / Duration.secondsPerHour).ceil();
      when = 'in $hours ${hours == 1 ? 'hour' : 'hours'}';
    } else {
      final days = (remaining.inSeconds / Duration.secondsPerDay).ceil();
      when = 'in $days ${days == 1 ? 'day' : 'days'}';
    }
    return WeatherGlanceEvent(
      id: pass.id,
      title: '$kind $when',
      detail: passTitle(pass),
      kind: kind,
    );
  }
}
