import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/flight_geo.dart';
import '../../domain/flight_pass_models.dart';
import 'flight_aircraft_painter.dart';
import 'flight_map_land.dart';
import 'flight_tones.dart';

/// The Updates tab's map: India in dots, each lit by the real sun at that
/// place and time, the route bowed like a great circle, and the aircraft where
/// it last reported itself.
///
/// Coastlines only, never a national border. Draws nothing for an airport the
/// map does not cover; the rest of the tab stands without it. Spec in
/// `docs/features/flight-pass-design.md`.
class FlightRouteMap extends StatefulWidget {
  const FlightRouteMap({super.key, required this.pass, required this.now});

  final FlightPass pass;
  final DateTime now;

  /// Whether [pass] can be drawn: both airports known and on the map.
  static bool canDraw(FlightPass pass) {
    final GeoPoint? a = pass.origin.resolvedLocation;
    final GeoPoint? b = pass.destination.resolvedLocation;
    return a != null && b != null && _onMap(_project(a)) && _onMap(_project(b));
  }

  @override
  State<FlightRouteMap> createState() => _FlightRouteMapState();
}

class _FlightRouteMapState extends State<FlightRouteMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(FlightRouteMap old) {
    super.didUpdateWidget(old);
    _syncPulse();
  }

  bool get _tracking {
    final FlightLive? live = widget.pass.live;
    return live?.position != null && !(live!.state.hasLanded);
  }

  void _syncPulse() {
    final bool run = _tracking && !MediaQuery.disableAnimationsOf(context);
    if (run && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!run && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!FlightRouteMap.canDraw(widget.pass)) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final _MapColors colors = _MapColors(
      isDark: isDark,
      card: isDark ? AppTheme.elevated(Brightness.dark) : Colors.white,
      ink: theme.colorScheme.onSurface,
      tones: FlightTones(isDark: isDark),
    );
    final FlightPass p = widget.pass;
    final FlightLive? live = p.live;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: FlightMapLand.width / FlightMapLand.height,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            RepaintBoundary(
              child: CustomPaint(
                painter: _RoutePainter(
                  pass: p,
                  now: widget.now,
                  colors: colors,
                  pulse: _pulse,
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              right: 12,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _chips(p, live, colors),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _chips(FlightPass p, FlightLive? live, _MapColors colors) {
    final GeoPoint? at = live?.position;
    if (live != null && live.state.hasLanded) {
      return <Widget>[_MapChip(colors: colors, text: 'Landed')];
    }
    if (at == null) {
      final bool before =
          p.departAt != null && widget.now.isBefore(p.departAt!.instant);
      return <Widget>[
        _MapChip(
          colors: colors,
          text: before
              ? 'Tracking starts 30 min before departure'
              : 'Not tracking this flight',
        ),
      ];
    }
    return <Widget>[
      _MapChip(colors: colors, text: 'Live', dot: colors.tones.green),
      if (live!.groundSpeedKt case final int kt when kt > 0)
        _MapChip(colors: colors, text: '$kt', unit: 'kt'),
      if (live.altitudeFt case final int ft when ft > 0)
        _MapChip(colors: colors, text: _thousands(ft), unit: 'ft'),
    ];
  }
}

class _MapColors {
  const _MapColors({
    required this.isDark,
    required this.card,
    required this.ink,
    required this.tones,
  });

  final bool isDark;
  final Color card;
  final Color ink;
  final FlightTones tones;

  Color get sea => isDark ? const Color(0xFF101216) : const Color(0xFFECE8DF);
  Color get day => isDark ? const Color(0xFF7C8699) : const Color(0xFFBDB6A7);
  Color get night => isDark ? const Color(0xFF3A404D) : const Color(0xFF8A8478);
  Color get dusk => isDark ? const Color(0xFFC9844A) : const Color(0xFFE0995A);
  Color get route => ink.withValues(alpha: isDark ? 0.45 : 0.35);
}

/// A frosted capsule over the map: "Live", "452 kt", "36,000 ft".
class _MapChip extends StatelessWidget {
  const _MapChip({
    required this.colors,
    required this.text,
    this.unit,
    this.dot,
  });

  final _MapColors colors;
  final String text;
  final String? unit;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final TextStyle strong = GoogleFonts.inter(
      color: colors.ink,
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      height: 1.0,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: colors.card.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (dot != null) ...<Widget>[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
              ],
              Text(text, style: strong),
              if (unit != null) ...<Widget>[
                const SizedBox(width: 3),
                Text(
                  unit!,
                  style: strong.copyWith(
                    color: colors.ink.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Painting ──────────────────────────────────────────────────────────────────

Offset _project(GeoPoint g) => Offset(
  (g.lon - FlightMapLand.west) * FlightMapLand.xPerDegree,
  (FlightMapLand.north - g.lat) * FlightMapLand.yPerDegree,
);

bool _onMap(Offset o) =>
    o.dx >= 8 &&
    o.dx <= FlightMapLand.width - 8 &&
    o.dy >= 8 &&
    o.dy <= FlightMapLand.height - 8;

/// One land point of the 2 dp grid.
class _LandDot {
  const _LandDot(this.at, this.geo, this.row, this.col);

  final Offset at;
  final GeoPoint geo;
  final int row;
  final int col;
}

/// Land points in design space with their coordinates, built once.
final List<_LandDot> _landDots = () {
  final List<_LandDot> out = <_LandDot>[];
  const List<int> r = FlightMapLand.runs;
  const double s = FlightMapLand.pitch;
  for (int k = 0; k + 2 < r.length; k += 3) {
    for (int i = r[k + 1]; i <= r[k + 2]; i++) {
      final Offset o = Offset(s / 2 + i * s, s / 2 + r[k] * s);
      out.add(
        _LandDot(
          o,
          GeoPoint(
            FlightMapLand.north - o.dy / FlightMapLand.yPerDegree,
            FlightMapLand.west + o.dx / FlightMapLand.xPerDegree,
          ),
          r[k],
          i,
        ),
      );
    }
  }
  return out;
}();

/// The window of the map a route is shown through: all of India for a long
/// flight, closer in for a short one, so Mumbai to Goa is not a 50 dp stub.
class _View {
  const _View(this.origin, this.zoom);

  /// Design-space top-left of the window.
  final Offset origin;
  final double zoom;

  static const double maxZoom = 3;

  /// Land points sampled so dots sit about 6 dp apart on screen at any zoom.
  int get stride => math.max(1, (6 / (FlightMapLand.pitch * zoom)).round());

  /// Fits the route with room for the chips above and the code tags beside.
  static _View fit(Offset a, Offset b, Offset c) {
    const double w = FlightMapLand.width, h = FlightMapLand.height;
    const double padLeft = 40, padRight = 64, padTop = 64, padBottom = 36;
    final Rect r = Rect.fromPoints(a, b).expandToInclude(Rect.fromPoints(c, c));
    final double zoom = math
        .min(
          (w - padLeft - padRight) / math.max(r.width, 1),
          (h - padTop - padBottom) / math.max(r.height, 1),
        )
        .clamp(1.0, maxZoom);
    final double vw = w / zoom, vh = h / zoom;
    final Offset centre =
        r.center +
        Offset((padRight - padLeft) / 2, (padBottom - padTop) / 2) / zoom;
    return _View(
      Offset(
        (centre.dx - vw / 2).clamp(0.0, w - vw),
        (centre.dy - vh / 2).clamp(0.0, h - vh),
      ),
      zoom,
    );
  }
}

/// Land dots grouped by how lit they are, for one minute and one sampling
/// stride. The pulse repaints every frame; the sun moves a quarter of a
/// degree a minute, so the elevations are worked out once a minute.
class _Shading {
  _Shading._(this.lit, this.dusk);

  /// Shading steps; dots are batched per step, so the land is a handful of
  /// draw calls.
  static const int steps = 12;

  final List<List<Offset>> lit;

  /// Dots near the terminator, by warmth.
  final List<List<Offset>> dusk;

  static (DateTime, int)? _key;
  static _Shading? _cached;

  static _Shading at(DateTime now, int stride) {
    final DateTime u = now.toUtc();
    final (DateTime, int) key = (
      DateTime.utc(u.year, u.month, u.day, u.hour, u.minute),
      stride,
    );
    if (_key == key && _cached != null) return _cached!;
    final List<List<Offset>> lit = List<List<Offset>>.generate(
      steps + 1,
      (_) => <Offset>[],
    );
    final List<List<Offset>> dusk = List<List<Offset>>.generate(
      steps + 1,
      (_) => <Offset>[],
    );
    for (final _LandDot d in _landDots) {
      if (d.row % stride != 0 || d.col % stride != 0) continue;
      final double e = solarElevation(d.geo, now);
      final double warm = (1 - (e + 1).abs() / 5).clamp(0.0, 1.0);
      if (warm > 0.08) {
        dusk[(warm * steps).round()].add(d.at);
      } else {
        lit[(((e + 6) / 10).clamp(0.0, 1.0) * steps).round()].add(d.at);
      }
    }
    _key = key;
    return _cached = _Shading._(lit, dusk);
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter({
    required this.pass,
    required this.now,
    required this.colors,
    required this.pulse,
  }) : super(repaint: pulse);

  final FlightPass pass;
  final DateTime now;
  final _MapColors colors;
  final Animation<double> pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final double k = size.width / FlightMapLand.width;
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.sea);

    final Offset a = _project(pass.origin.resolvedLocation!);
    final Offset b = _project(pass.destination.resolvedLocation!);
    final Offset c = _control(a, b);
    final _View view = _View.fit(a, b, c);
    final double scale = k * view.zoom;
    Offset screen(Offset design) => (design - view.origin) * scale;
    Offset at(double t) =>
        screen(a * ((1 - t) * (1 - t)) + c * (2 * (1 - t) * t) + b * (t * t));

    _paintLand(canvas, view, scale);

    final FlightLive? live = pass.live;
    final GeoPoint? position = live?.position;
    final bool landed = live?.state.hasLanded ?? false;
    final Offset? plane = position != null
        ? screen(_project(position))
        : (landed ? screen(b) : null);
    final double flown = plane == null ? 0 : _nearestT(at, plane);

    _paintRoute(canvas, at, flown);
    _paintAirport(canvas, screen(a), pass.origin.code, size);
    _paintAirport(canvas, screen(b), pass.destination.code, size);
    if (plane != null) {
      final double t0 = math.max(0, flown - 0.02);
      final double t1 = math.min(1, flown + 0.02);
      final Offset dir = at(t1) - at(t0);
      _paintPlane(canvas, plane, math.atan2(dir.dy, dir.dx), pulsing: !landed);
    }
  }

  void _paintLand(Canvas canvas, _View view, double scale) {
    final _Shading shading = _Shading.at(now, view.stride);
    canvas.save();
    canvas.scale(scale);
    canvas.translate(-view.origin.dx, -view.origin.dy);
    final Paint paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.7 / view.zoom;
    for (int i = 0; i <= _Shading.steps; i++) {
      if (shading.lit[i].isNotEmpty) {
        paint.color = Color.lerp(colors.night, colors.day, i / _Shading.steps)!;
        canvas.drawPoints(ui.PointMode.points, shading.lit[i], paint);
      }
      if (shading.dusk[i].isNotEmpty) {
        paint.color = Color.lerp(
          colors.night,
          colors.dusk,
          0.35 + 0.65 * i / _Shading.steps,
        )!;
        canvas.drawPoints(ui.PointMode.points, shading.dusk[i], paint);
      }
    }
    canvas.restore();
  }

  /// Bow the chord the way a great circle reads on a flat map: poleward for
  /// an east-west route, westward for a north-south one.
  static Offset _control(Offset a, Offset b) {
    final Offset mid = (a + b) / 2;
    final Offset d = b - a;
    final double len = d.distance;
    if (len == 0) return mid;
    Offset n = Offset(-d.dy, d.dx) / len;
    if (n.dy.abs() > 0.5 ? n.dy > 0 : n.dx > 0) n = -n;
    return mid + n * (len * 0.16);
  }

  static double _nearestT(Offset Function(double) at, Offset p) {
    double best = 0, bestD = double.infinity;
    for (int i = 0; i <= 100; i++) {
      final double t = i / 100;
      final double d = (at(t) - p).distanceSquared;
      if (d < bestD) {
        bestD = d;
        best = t;
      }
    }
    return best;
  }

  /// Ahead dotted at an even on-screen pitch, flown solid in the live blue.
  void _paintRoute(Canvas canvas, Offset Function(double) at, double flown) {
    final Paint dot = Paint()..color = colors.route;
    double carry = 0;
    Offset prev = at(flown);
    for (int i = 1; i <= 200; i++) {
      final Offset q = at(flown + (1 - flown) * i / 200);
      carry += (q - prev).distance;
      prev = q;
      if (carry >= 6) {
        carry = 0;
        canvas.drawCircle(q, 1.1, dot);
      }
    }
    if (flown <= 0) return;
    final Offset start = at(0);
    final Path path = Path()..moveTo(start.dx, start.dy);
    for (int i = 1; i <= 80; i++) {
      final Offset q = at(flown * i / 80);
      path.lineTo(q.dx, q.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = colors.tones.blue,
    );
  }

  void _paintAirport(Canvas canvas, Offset o, String code, Size size) {
    canvas.drawCircle(o, 4.5, Paint()..color = colors.card);
    canvas.drawCircle(
      o,
      4.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = colors.ink,
    );
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: code,
        style: GoogleFonts.inter(
          color: colors.ink,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    const double padX = 6, h = 20;
    final double w = tp.width + padX * 2;
    final bool left = o.dx + 10 + w > size.width - 6;
    final Rect r = Rect.fromLTWH(
      left ? o.dx - 10 - w : o.dx + 10,
      o.dy - h / 2,
      w,
      h,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(6)),
      Paint()..color = colors.card,
    );
    tp.paint(canvas, Offset(r.left + padX, r.center.dy - tp.height / 2));
  }

  void _paintPlane(
    Canvas canvas,
    Offset o,
    double angle, {
    required bool pulsing,
  }) {
    if (pulsing) {
      final double v = pulse.value;
      canvas.drawCircle(
        o,
        10 + 16 * v,
        Paint()..color = colors.tones.blue.withValues(alpha: 0.3 * (1 - v)),
      );
    }
    canvas.save();
    canvas.translate(o.dx, o.dy);
    canvas.rotate(angle);
    canvas.scale(1.9);
    canvas.translate(-6, -6);
    final Path glyph = flightGlyphPath();
    canvas.drawPath(
      glyph.shift(const Offset(0, 0.8)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
    );
    canvas.drawPath(glyph, Paint()..color = colors.tones.blue);
    canvas.drawPath(
      glyph,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = colors.card,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) =>
      old.pass != pass ||
      old.now.minute != now.minute ||
      old.now.hour != now.hour ||
      old.colors.isDark != colors.isDark;
}

String _thousands(int v) {
  final String s = v.toString();
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}
