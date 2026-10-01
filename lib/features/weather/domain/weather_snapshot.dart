enum WeatherCondition {
  clear,
  partlyCloudy,
  cloudy,
  fog,
  drizzle,
  rain,
  snow,
  thunderstorm,
  unknown,
}

WeatherCondition conditionForCode(int code) => switch (code) {
  0 => WeatherCondition.clear,
  1 || 2 => WeatherCondition.partlyCloudy,
  3 => WeatherCondition.cloudy,
  45 || 48 => WeatherCondition.fog,
  51 || 53 || 55 || 56 || 57 => WeatherCondition.drizzle,
  61 || 63 || 65 || 66 || 67 || 80 || 81 || 82 => WeatherCondition.rain,
  71 || 73 || 75 || 77 || 85 || 86 => WeatherCondition.snow,
  95 || 96 || 99 => WeatherCondition.thunderstorm,
  _ => WeatherCondition.unknown,
};

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.temperatureC,
    required this.code,
    required this.isDay,
    required this.time,
    required this.fetchedAt,
    required this.utcOffsetSeconds,
    this.forecast = false,
  });
  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) {
    final temp = (json['temperatureC'] as num).toDouble();
    if (!temp.isFinite) {
      throw const FormatException('Invalid weather temperature');
    }
    return WeatherSnapshot(
      temperatureC: temp,
      code: json['code'] as int,
      isDay: json['isDay'] as bool,
      time: DateTime.parse(json['time'] as String).toUtc(),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String).toUtc(),
      utcOffsetSeconds: json['utcOffsetSeconds'] as int,
      forecast: json['forecast'] as bool? ?? false,
    );
  }
  final double temperatureC;
  final int code;
  final bool isDay;
  final DateTime time, fetchedAt;
  final int utcOffsetSeconds;
  final bool forecast;
  WeatherCondition get condition => conditionForCode(code);
  DateTime get localTime => time.add(Duration(seconds: utcOffsetSeconds));
  bool isRecent(DateTime now) =>
      now.toUtc().difference(fetchedAt) < const Duration(hours: 2);
  String get description => switch (condition) {
    WeatherCondition.clear => 'Clear',
    WeatherCondition.partlyCloudy =>
      code == 1 ? 'Mostly clear' : 'Partly cloudy',
    WeatherCondition.cloudy => 'Overcast',
    WeatherCondition.fog => 'Fog',
    WeatherCondition.drizzle => 'Drizzle',
    WeatherCondition.rain => code == 65 || code == 82 ? 'Heavy rain' : 'Rain',
    WeatherCondition.snow => 'Snow',
    WeatherCondition.thunderstorm => 'Thunderstorm',
    WeatherCondition.unknown => 'Conditions unavailable',
  };
}

// A trip/event can supply its own coordinates, label and UTC time. Weather
// selection is independent of wallet categories and never guesses a venue.
class WeatherTarget {
  const WeatherTarget({
    required this.latitude,
    required this.longitude,
    required this.label,
    this.at,
  });
  final double latitude, longitude;
  final String label;
  final DateTime? at;
}
