import 'dart:math' as math;

/// A point on the earth, degrees.
class GeoPoint {
  const GeoPoint(this.lat, this.lon);

  final double lat;
  final double lon;
}

/// Coordinates for the airports Docket's flights use most, so the route map
/// can draw without the server sending them. The server's coordinates win
/// when present; an airport in neither has no map.
abstract final class FlightAirportCoordinates {
  FlightAirportCoordinates._();

  static const Map<String, GeoPoint> _known = <String, GeoPoint>{
    'AMD': GeoPoint(23.0772, 72.6347),
    'ATQ': GeoPoint(31.7096, 74.7973),
    'BBI': GeoPoint(20.2444, 85.8178),
    'BLR': GeoPoint(13.1986, 77.7066),
    'BOM': GeoPoint(19.0896, 72.8656),
    'CCU': GeoPoint(22.6547, 88.4467),
    'CJB': GeoPoint(11.0300, 77.0434),
    'COK': GeoPoint(10.1520, 76.4019),
    'DEL': GeoPoint(28.5562, 77.1000),
    'GAU': GeoPoint(26.1061, 91.5859),
    'GOI': GeoPoint(15.3808, 73.8314),
    'GOX': GeoPoint(15.7300, 73.8600),
    'HYD': GeoPoint(17.2403, 78.4294),
    'IXB': GeoPoint(26.6812, 88.3286),
    'IXC': GeoPoint(30.6735, 76.7885),
    'IXE': GeoPoint(12.9613, 74.8901),
    'IXM': GeoPoint(9.8345, 78.0934),
    'IXR': GeoPoint(23.3143, 85.3217),
    'IXZ': GeoPoint(11.6412, 92.7297),
    'JAI': GeoPoint(26.8242, 75.8122),
    'LKO': GeoPoint(26.7606, 80.8893),
    'MAA': GeoPoint(12.9941, 80.1709),
    'NAG': GeoPoint(21.0922, 79.0472),
    'PAT': GeoPoint(25.5913, 85.0880),
    'PNQ': GeoPoint(18.5821, 73.9197),
    'SXR': GeoPoint(33.9871, 74.7742),
    'TRV': GeoPoint(8.4821, 76.9201),
    'VNS': GeoPoint(25.4524, 82.8593),
    'VTZ': GeoPoint(17.7212, 83.2245),
  };

  static GeoPoint? of(String iata) => _known[iata.trim().toUpperCase()];
}

/// Great-circle distance in kilometres.
double greatCircleKm(GeoPoint a, GeoPoint b) {
  const double r = 6371;
  final double p1 = _rad(a.lat), p2 = _rad(b.lat);
  final double dp = _rad(b.lat - a.lat), dl = _rad(b.lon - a.lon);
  final double h =
      math.sin(dp / 2) * math.sin(dp / 2) +
      math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(h)));
}

/// The sun's elevation above the horizon at [at], in degrees.
///
/// The NOAA approximation, good to a fraction of a degree, which is plenty
/// for shading a map. Negative is below the horizon; -6 is the end of civil
/// twilight.
double solarElevation(GeoPoint p, DateTime at) {
  final DateTime utc = at.toUtc();
  final int dayOfYear = utc.difference(DateTime.utc(utc.year)).inDays + 1;
  final double g = 2 * math.pi / 365 * (dayOfYear - 81);
  final double declination = _rad(23.44 * math.sin(g));
  final double equationOfTime =
      9.87 * math.sin(2 * g) - 7.53 * math.cos(g) - 1.5 * math.sin(g);
  final double minutes = utc.hour * 60 + utc.minute + utc.second / 60;
  final double solarMinutes = minutes + 4 * p.lon + equationOfTime;
  final double hourAngle = _rad(solarMinutes / 4 - 180);
  final double phi = _rad(p.lat);
  final double sinElevation =
      math.sin(phi) * math.sin(declination) +
      math.cos(phi) * math.cos(declination) * math.cos(hourAngle);
  return math.asin(sinElevation.clamp(-1.0, 1.0)) * 180 / math.pi;
}

double _rad(double deg) => deg * math.pi / 180;
