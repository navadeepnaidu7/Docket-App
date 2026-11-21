import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/flight_format.dart';
import '../../domain/flight_pass_models.dart';
import '../movie/movie_ticket_chrome.dart';
import 'airline_logo.dart';
import 'flight_aircraft_painter.dart';
import 'flight_brand_style.dart';
import 'flight_journey_status.dart';
import 'flight_pass_theme.dart';

/// Flight pass face — the train and bus layout on one solid airline surface,
/// the airline's logo, and the airport codes as the hero under an arc that
/// fills as the flight goes.
///
/// Laid out against a fixed canvas and scaled by `WalletCardCanvas`. The face
/// never draws a code; the detail screen shows it under the card. Spec in
/// `docs/features/flight-pass.md`.
class FlightTicketFace extends StatelessWidget {
  const FlightTicketFace({
    super.key,
    required this.pass,
    this.useBrandColors = false,
    this.showShadow = true,
    this.clock = DateTime.now,
  });

  final FlightPass pass;

  /// Force the live palette on a pass the wallet considers expired.
  final bool useBrandColors;
  final bool showShadow;

  /// Injected for tests so the status sentence is deterministic.
  final DateTime Function() clock;

  @visibleForTesting
  static const Key originKey = Key('flight_pass.origin');
  @visibleForTesting
  static const Key destinationKey = Key('flight_pass.destination');
  @visibleForTesting
  static const Key arcKey = Key('flight_pass.arc');
  @visibleForTesting
  static const Key durationKey = Key('flight_pass.duration');

  @override
  Widget build(BuildContext context) {
    final FlightPass p = pass;
    final FlightBrandStyle c = FlightBrandStyle.forPass(
      p,
      useBrandColors: useBrandColors,
    );
    final FlightJourneyStatus status = resolveFlightJourneyStatus(p, clock());

    const double inset = FlightPassMetrics.inset;
    const double width = FlightPassMetrics.contentWidth;
    const double half = FlightPassMetrics.halfWidth;

    final String duration = FlightFormat.duration(p.departAt, p.arriveAt);
    final int dayOffset = FlightFormat.arrivalDayOffset(
      p.departAt,
      p.live?.arriveRevised ?? p.arriveAt,
    );
    final String depTerminal = p.resolvedDepartTerminal;
    final String arrTerminal = p.resolvedArriveTerminal;

    return Container(
      width: FlightPassMetrics.width,
      height: FlightPassMetrics.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FlightPassMetrics.cornerR),
        boxShadow: showShadow
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: c.shadowAlpha),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                  spreadRadius: -4,
                ),
              ]
            : const <BoxShadow>[],
      ),
      child: ClipPath(
        clipper: const TicketShapeClipper(
          cornerR: FlightPassMetrics.cornerR,
          notchR: FlightPassMetrics.notchR,
          notchFromBottom: FlightPassMetrics.notchFromBottom,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(child: ColoredBox(color: c.surface)),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 1,
              child: ColoredBox(color: c.edge),
            ),
            // ── Header ──
            _Baselined(
              baseline: FlightPassMetrics.nameBaseline,
              left: inset,
              width: width,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Expanded(
                    child: _Wordmark(pass: p, style: c),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _orDash(FlightFormat.day(p.departAt)),
                    maxLines: 1,
                    style: FlightPassType.date(c.ink),
                  ),
                ],
              ),
            ),
            _Baselined(
              baseline: FlightPassMetrics.flightBaseline,
              left: inset,
              width: width,
              child: Row(
                children: <Widget>[
                  Text(
                    p.flightNumber,
                    maxLines: 1,
                    style: FlightPassType.small(c.muted),
                  ),
                  if (p.bookingRef.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(width: 14),
                    Flexible(
                      child: Text(
                        'PNR ${p.bookingRef.trim()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FlightPassType.small(c.muted),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Journey ──
            _Baselined(
              baseline: FlightPassMetrics.cityBaseline,
              left: inset,
              width: width,
              child: _Ends(
                start: Text(
                  p.origin.displayCity,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FlightPassType.small(c.muted),
                ),
                end: Text(
                  p.destination.displayCity,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: FlightPassType.small(c.muted),
                ),
              ),
            ),
            Positioned(
              left: inset,
              right: inset,
              top: FlightPassMetrics.arcTop,
              height: FlightPassMetrics.arcHeight,
              child: ExcludeSemantics(
                child: CustomPaint(
                  key: FlightTicketFace.arcKey,
                  painter: _ArcPainter(
                    progress: status.progress,
                    landed: status.progress >= 1,
                    track: c.faint,
                    fill: c.ink,
                  ),
                ),
              ),
            ),
            // The codes and, between them, the flight time. One row, so a
            // wide pair of codes squeezes the time instead of overlapping it.
            _Baselined(
              baseline: FlightPassMetrics.codeBaseline,
              left: inset - 1,
              width: width + 2,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  _Code(p.origin.code, c, key: FlightTicketFace.originKey),
                  Expanded(
                    child: Transform.translate(
                      offset: const Offset(
                        0,
                        FlightPassMetrics.durationBaseline -
                            FlightPassMetrics.codeBaseline,
                      ),
                      child: Text(
                        duration,
                        key: FlightTicketFace.durationKey,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        textAlign: TextAlign.center,
                        style: FlightPassType.duration(c.muted),
                      ),
                    ),
                  ),
                  _Code(
                    p.destination.code,
                    c,
                    key: FlightTicketFace.destinationKey,
                  ),
                ],
              ),
            ),
            _Baselined(
              baseline: FlightPassMetrics.timeBaseline,
              left: inset,
              width: half,
              child: _Times(
                scheduled: p.departAt,
                revised: p.live?.departRevised,
                style: c,
              ),
            ),
            _Baselined(
              baseline: FlightPassMetrics.timeBaseline,
              right: inset,
              width: half,
              child: _Times(
                scheduled: p.arriveAt,
                revised: p.live?.arriveRevised,
                style: c,
                alignEnd: true,
              ),
            ),
            if (dayOffset > 0)
              _Baselined(
                baseline: FlightPassMetrics.dayMarkerBaseline,
                left:
                    FlightPassMetrics.contentRight +
                    FlightPassMetrics.dayMarkerGap,
                child: Text(
                  '+$dayOffset',
                  maxLines: 1,
                  softWrap: false,
                  style: FlightPassType.dayMarker(c.muted),
                ),
              ),
            if (depTerminal.isNotEmpty)
              _Baselined(
                baseline: FlightPassMetrics.terminalBaseline,
                left: inset,
                width: half,
                child: Text(
                  'Terminal $depTerminal',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FlightPassType.small(c.muted),
                ),
              ),
            if (arrTerminal.isNotEmpty)
              _Baselined(
                baseline: FlightPassMetrics.terminalBaseline,
                right: inset,
                width: half,
                child: Text(
                  'Terminal $arrTerminal',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: FlightPassType.small(c.muted),
                ),
              ),

            // ── Status ──
            _Baselined(
              baseline: status.detail.isEmpty
                  ? (FlightPassMetrics.leadBaseline +
                            FlightPassMetrics.detailBaseline) /
                        2
                  : FlightPassMetrics.leadBaseline,
              left: inset,
              width: width,
              child: Text.rich(
                TextSpan(
                  children: <TextSpan>[
                    if (status.lead.isNotEmpty)
                      TextSpan(
                        text: '${status.lead} ',
                        style: FlightPassType.lead(c.muted),
                      ),
                    TextSpan(
                      text: status.emphasis,
                      style: FlightPassType.lead(
                        c.ink,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (status.detail.isNotEmpty)
              _Baselined(
                baseline: FlightPassMetrics.detailBaseline,
                left: inset,
                width: width,
                child: Text(
                  status.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FlightPassType.detail(c.muted),
                ),
              ),

            // ── Stub ──
            Positioned(
              left: FlightPassMetrics.notchR + 6,
              right: FlightPassMetrics.notchR + 6,
              top: FlightPassMetrics.tearY - 1.5,
              height: 3,
              child: CustomPaint(painter: _DotRulePainter(c.faint)),
            ),
            ..._stubColumn(
              label: 'Gate',
              value: _orDash(p.resolvedGate),
              left: inset,
              style: c,
            ),
            ..._stubColumn(
              label: 'Seat',
              value: _orDash(_seat(p)),
              left: FlightPassMetrics.seatLeft,
              style: c,
            ),
            ..._stubColumn(
              label: 'Boards',
              value: _orDash(FlightFormat.time(p.boardingAt)),
              right: inset,
              style: c,
            ),
            _Baselined(
              baseline: FlightPassMetrics.passengerLabelBaseline,
              left: inset,
              child: Text(
                p.passengers.length > 1 ? 'Passengers' : 'Passenger',
                style: FlightPassType.label(c.muted),
              ),
            ),
            _Baselined(
              baseline: FlightPassMetrics.passengerBaseline,
              left: inset,
              width: FlightPassMetrics.passengerWidth,
              child: Text(
                _passengers(p),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FlightPassType.value(c.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<Widget> _stubColumn({
    required String label,
    required String value,
    required FlightBrandStyle style,
    double? left,
    double? right,
  }) {
    return <Widget>[
      _Baselined(
        baseline: FlightPassMetrics.stubLabelBaseline,
        left: left,
        right: right,
        child: Text(label, style: FlightPassType.label(style.muted)),
      ),
      _Baselined(
        baseline: FlightPassMetrics.stubValueBaseline,
        left: left,
        right: right,
        child: Text(
          value,
          maxLines: 1,
          softWrap: false,
          style: FlightPassType.stub(style.ink),
        ),
      ),
    ];
  }
}

// ── Pieces ────────────────────────────────────────────────────────────────────

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.pass, required this.style});

  final FlightPass pass;
  final FlightBrandStyle style;

  @override
  Widget build(BuildContext context) {
    final String name = pass.airline.trim().isNotEmpty
        ? pass.airline.trim()
        : (pass.brand?.name ?? '');
    // The logo stands on the name baseline, level with the date beside it;
    // the name in type holds its place until the logo arrives.
    return AirlineLogo(
      code: pass.resolvedAirlineCode,
      color: style.ink,
      semanticsLabel: name,
      fallback: Text(
        _orDash(name),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: FlightPassType.name(style.ink),
      ),
    );
  }
}

class _Code extends StatelessWidget {
  const _Code(this.code, this.style, {super.key});

  final String code;
  final FlightBrandStyle style;

  @override
  Widget build(BuildContext context) => Text(
    code.trim().isEmpty ? _absent : code.trim(),
    maxLines: 1,
    softWrap: false,
    style: FlightPassType.code(style.ink),
  );
}

/// The scheduled time, or — when the feed moved it by five minutes or more —
/// the revision in ink beside the scheduled time struck through. A smaller
/// change is noise on the face; the Updates tab still lists it.
class _Times extends StatelessWidget {
  const _Times({
    required this.scheduled,
    required this.revised,
    required this.style,
    this.alignEnd = false,
  });

  final AirportTime? scheduled;
  final AirportTime? revised;
  final FlightBrandStyle style;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final AirportTime? s = scheduled;
    final AirportTime? r = revised;
    final bool moved =
        s != null &&
        r != null &&
        r.instant.difference(s.instant).inMinutes.abs() >=
            kFlightDelayThresholdMinutes;
    // The struck schedule gives way first: the revision is the time that
    // matters, so it is never the one clipped.
    final List<Widget> runs = moved
        ? <Widget>[
            Flexible(
              child: Text(
                FlightFormat.time(s),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: FlightPassType.timeStruck(style.muted),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              FlightFormat.time(r),
              maxLines: 1,
              style: FlightPassType.time(style.ink),
            ),
          ]
        : <Widget>[
            Text(
              _orDash(FlightFormat.time(s)),
              maxLines: 1,
              style: FlightPassType.time(style.ink),
            ),
          ];
    return Row(
      mainAxisAlignment: alignEnd
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: runs,
    );
  }
}

// ── Formatting ────────────────────────────────────────────────────────────────

const String _absent = '—';

String _orDash(String value) => value.trim().isEmpty ? _absent : value.trim();

/// The pass seat, else the lead passenger's.
String _seat(FlightPass p) {
  if (p.seat.trim().isNotEmpty) return p.seat.trim();
  for (final FlightPassenger x in p.passengers) {
    if (x.seat.trim().isNotEmpty) return x.seat.trim();
  }
  return '';
}

/// "Navadeep Nagella" alone; "Navadeep and 1 other" for a group, as on the
/// train and bus faces.
String _passengers(FlightPass pass) {
  if (pass.passengers.isEmpty) return _absent;
  final String lead = pass.passengers.first.name.trim();
  if (pass.passengers.length == 1) return _orDash(lead);
  final String first = lead.isEmpty ? 'Traveller' : lead.split(' ').first;
  final int others = pass.passengers.length - 1;
  return '$first and $others ${others == 1 ? 'other' : 'others'}';
}

// ── Layout helpers ────────────────────────────────────────────────────────────
//
// The bus face's helpers, kept local as that face keeps the train's.

class _Baselined extends StatelessWidget {
  const _Baselined({
    required this.baseline,
    required this.child,
    this.left,
    this.right,
    this.width,
  });

  final double baseline;
  final Widget child;
  final double? left;
  final double? right;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final Widget sized = width == null
        ? child
        : SizedBox(width: width, child: child);
    return Positioned(
      left: left,
      right: right,
      width: width,
      top: 0,
      child: Baseline(
        baseline: baseline,
        baselineType: TextBaseline.alphabetic,
        child: sized,
      ),
    );
  }
}

class _Ends extends StatelessWidget {
  const _Ends({required this.start, required this.end});

  final Widget start;
  final Widget end;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Expanded(child: _side(start, MainAxisAlignment.start)),
        const SizedBox(width: FlightPassMetrics.columnGap),
        Expanded(child: _side(end, MainAxisAlignment.end)),
      ],
    );
  }

  static Widget _side(Widget child, MainAxisAlignment alignment) => Row(
    mainAxisAlignment: alignment,
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: <Widget>[Flexible(child: child)],
  );
}

/// The route over the codes: a quadratic arc from above one code to above
/// the other, dotted ahead, solid behind, the plane riding the boundary and
/// turning with the curve. The feet are dots: the origin filled, the
/// destination an open ring until the flight has landed.
class _ArcPainter extends CustomPainter {
  const _ArcPainter({
    required this.progress,
    required this.landed,
    required this.track,
    required this.fill,
  });

  final double progress;
  final bool landed;
  final Color track;
  final Color fill;

  static const double _plane = 15;

  @override
  void paint(Canvas canvas, Size size) {
    const double foot = FlightPassMetrics.arcFootInset;
    final double baseY = size.height - 6;
    final Offset a = Offset(foot, baseY);
    final Offset b = Offset(size.width - foot, baseY);
    // Crown at baseY - arcRise: a quadratic's apex is halfway to its control.
    final Offset c = Offset(
      size.width / 2,
      baseY - 2 * FlightPassMetrics.arcRise,
    );
    Offset at(double t) =>
        a * ((1 - t) * (1 - t)) + c * (2 * (1 - t) * t) + b * (t * t);
    final double p = progress.clamp(0.0, 1.0);

    // Ahead: dots at an even pitch along the curve.
    final Paint dot = Paint()..color = track;
    double carry = 0;
    Offset prev = at(p);
    for (int i = 1; i <= 160; i++) {
      final Offset q = at(p + (1 - p) * i / 160);
      carry += (q - prev).distance;
      prev = q;
      if (carry >= 6) {
        carry = 0;
        if ((q - at(p)).distance > _plane * 0.7) canvas.drawCircle(q, 1, dot);
      }
    }
    // Behind: solid, fading in from the origin.
    if (p > 0) {
      final Path flown = Path()..moveTo(a.dx, a.dy);
      for (int i = 1; i <= 80; i++) {
        final Offset q = at(p * i / 80);
        flown.lineTo(q.dx, q.dy);
      }
      canvas.drawPath(
        flown,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            colors: <Color>[fill.withValues(alpha: 0.3), fill],
          ).createShader(Rect.fromPoints(a, at(p)).inflate(1)),
      );
    }
    canvas.drawCircle(a, 3, Paint()..color = fill);
    canvas.drawCircle(
      b,
      3,
      landed
          ? (Paint()..color = fill)
          : (Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = fill),
    );

    final Offset o = at(p);
    final Offset d = at(math.min(1, p + 0.01)) - at(math.max(0, p - 0.01));
    canvas.save();
    canvas.translate(o.dx, o.dy);
    canvas.rotate(math.atan2(d.dy, d.dx));
    canvas.scale(_plane / 12);
    canvas.translate(-6, -6);
    canvas.drawPath(flightGlyphPath(), Paint()..color = fill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) =>
      old.progress != progress ||
      old.landed != landed ||
      old.track != track ||
      old.fill != fill;
}

class _DotRulePainter extends CustomPainter {
  const _DotRulePainter(this.color);

  final Color color;

  static const double _pitch = 8;
  static const double _radius = 1.1;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    final int count = (size.width / _pitch).floor();
    final double start = (size.width - (count - 1) * _pitch) / 2;
    for (int i = 0; i < count; i++) {
      canvas.drawCircle(
        Offset(start + i * _pitch, size.height / 2),
        _radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DotRulePainter old) => old.color != color;
}
