import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/bus_pass_models.dart';
import '../../domain/pass_activity_date.dart';
import '../movie/movie_ticket_chrome.dart';
import '../train/train_pass_theme.dart';
import 'bus_brand_style.dart';
import 'bus_coach_painter.dart';
import 'bus_journey_status.dart';
import 'bus_pass_theme.dart';

export 'bus_journey_status.dart' show busArrivalDayOffset, busDurationLabel;

/// Bus pass face — the train pass's layout on one solid operator surface, with
/// a tone-on-tone coach pulling out of the stub's corner.
///
/// Laid out against a fixed canvas and scaled by `WalletCardCanvas`. Every line
/// is placed by baseline. The face never draws a code; the detail screen shows
/// it under the card. Spec in `docs/features/bus-pass-redesign.md`.
class BusTicketFace extends StatelessWidget {
  const BusTicketFace({
    super.key,
    required this.pass,
    this.useBrandColors = false,
    this.showShadow = true,
    this.clock = DateTime.now,
  });

  final BusPass pass;

  /// Force the live palette on a pass the wallet considers expired.
  final bool useBrandColors;

  final bool showShadow;

  /// Injected for tests so the status sentence is deterministic.
  final DateTime Function() clock;

  @visibleForTesting
  static const Key departureKey = Key('bus_pass.departure');
  @visibleForTesting
  static const Key arrivalKey = Key('bus_pass.arrival');
  @visibleForTesting
  static const Key coachKey = Key('bus_pass.coach');

  @override
  Widget build(BuildContext context) {
    final BusPass p = pass;
    final BusBrandStyle c = BusBrandStyle.forPass(
      p,
      useBrandColors: useBrandColors,
    );
    final BusJourneyStatus status = resolveBusJourneyStatus(p, clock());

    final ({String time, String meridiem})? dep = busClock12(p.departTime);
    final ({String time, String meridiem})? arr = busClock12(p.arriveTime);
    final int dayOffset = busArrivalDayOffset(p);
    final String duration = busDurationLabel(p);
    final String booking = p.bookingId.trim();
    final String fare = p.fare.trim();
    final String seat = _seatLabel(p);

    const double inset = BusPassMetrics.inset;
    const double width = BusPassMetrics.contentWidth;
    const double half = BusPassMetrics.halfWidth;

    final String fromCity = _orDash(p.resolvedFromCity);
    final String toCity = _orDash(p.resolvedToCity);
    final String fromStop = _stopUnder(
      _stationOf(p.boardingLocation, p.boardingPoint),
      fromCity,
    );
    final String toStop = _stopUnder(_stationOf(p.dropLocation, ''), toCity);

    return Container(
      width: BusPassMetrics.width,
      height: BusPassMetrics.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BusPassMetrics.cornerR),
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
          cornerR: BusPassMetrics.cornerR,
          notchR: BusPassMetrics.notchR,
          notchFromBottom: BusPassMetrics.notchFromBottom,
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

            // Under everything else, so a long value passes over it rather
            // than behind it.
            Positioned(
              left: BusPassMetrics.coachLeft,
              top: BusPassMetrics.coachTop,
              width: BusPassMetrics.coachWidth,
              height: BusPassMetrics.coachHeight,
              child: ExcludeSemantics(
                child: CustomPaint(
                  key: BusTicketFace.coachKey,
                  painter: BusCoachPainter(
                    body: c.coachBody,
                    shade: c.coachShade,
                    surface: c.surface,
                  ),
                ),
              ),
            ),

            // ── Header ──
            _Baselined(
              baseline: BusPassMetrics.nameBaseline,
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
                    _headerDate(p.date),
                    maxLines: 1,
                    style: BusPassType.date(c.ink),
                  ),
                ],
              ),
            ),
            if (booking.isNotEmpty)
              _Baselined(
                baseline: BusPassMetrics.bookingBaseline,
                left: inset,
                width: width,
                child: Text(
                  'Booking $booking',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BusPassType.small(c.muted),
                ),
              ),

            // ── Journey ──
            _Baselined(
              baseline: BusPassMetrics.cityBaseline,
              left: inset,
              width: width,
              child: _Ends(
                start: Text(
                  fromCity,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BusPassType.small(c.muted),
                ),
                end: Text(
                  toCity,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: BusPassType.small(c.muted),
                ),
              ),
            ),

            // The rule spans exactly the gap the two times leave, duration
            // centred above it. The times are laid out again inside the
            // delegate, invisibly, so the rule's ends come from layout rather
            // than a TextPainter measured once before Geist resolves.
            Positioned(
              left: inset,
              right: inset,
              top: BusPassMetrics.ruleY - 0.5 - BusPassMetrics.ruleLift,
              height: BusPassMetrics.ruleLift + 1,
              child: CustomMultiChildLayout(
                delegate: _BetweenTimesDelegate(),
                children: <Widget>[
                  LayoutId(
                    id: _Slot.departure,
                    child: Opacity(opacity: 0, child: _Time(dep, c)),
                  ),
                  LayoutId(
                    id: _Slot.arrival,
                    child: Opacity(opacity: 0, child: _Time(arr, c)),
                  ),
                  LayoutId(
                    id: _Slot.rule,
                    child: CustomPaint(
                      painter: _RoutePainter(
                        progress: status.progress,
                        track: c.faint,
                        fill: c.ink,
                      ),
                    ),
                  ),
                  if (duration.isNotEmpty)
                    LayoutId(
                      id: _Slot.duration,
                      child: Text(
                        duration,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                        style: BusPassType.duration(c.muted),
                      ),
                    ),
                ],
              ),
            ),
            _Baselined(
              baseline: BusPassMetrics.timeBaseline,
              left:
                  inset -
                  (dep == null ? 0 : TrainTimeOptics.leftPull(dep.time)),
              child: _Time(dep, c, key: BusTicketFace.departureKey),
            ),
            // The meridiem ends the row, so the arrival needs no bearing
            // correction: 14 dp capitals sit on the edge like the text above.
            _Baselined(
              baseline: BusPassMetrics.timeBaseline,
              right: inset,
              child: _Time(arr, c, key: BusTicketFace.arrivalKey),
            ),
            if (dayOffset > 0)
              _Baselined(
                baseline: BusPassMetrics.dayMarkerBaseline,
                left: BusPassMetrics.contentRight + BusPassMetrics.dayMarkerGap,
                child: Text(
                  '+$dayOffset',
                  maxLines: 1,
                  softWrap: false,
                  style: BusPassType.dayMarker(c.muted),
                ),
              ),
            if (fromStop.isNotEmpty)
              _Baselined(
                baseline: BusPassMetrics.stopBaseline,
                left: inset,
                width: half,
                child: Text(
                  fromStop,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: BusPassType.stop(c.muted),
                ),
              ),
            if (toStop.isNotEmpty)
              _Baselined(
                baseline: BusPassMetrics.stopBaseline,
                right: inset,
                width: half,
                child: Text(
                  toStop,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: BusPassType.stop(c.muted),
                ),
              ),

            // ── Status ──
            _Baselined(
              // A lone lead line drops to the middle of the two-line block, so
              // a card with nothing more to say keeps even space to the tear.
              baseline: status.detail.isEmpty
                  ? (BusPassMetrics.leadBaseline +
                            BusPassMetrics.detailBaseline) /
                        2
                  : BusPassMetrics.leadBaseline,
              left: inset,
              width: width,
              child: Text.rich(
                TextSpan(
                  children: <TextSpan>[
                    if (status.lead.isNotEmpty)
                      TextSpan(
                        text: '${status.lead} ',
                        style: BusPassType.lead(c.muted),
                      ),
                    TextSpan(
                      text: status.emphasis,
                      style: BusPassType.lead(
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
                baseline: BusPassMetrics.detailBaseline,
                left: inset,
                width: width,
                child: Text(
                  status.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BusPassType.detail(c.muted),
                ),
              ),

            // ── Stub ──
            Positioned(
              left: BusPassMetrics.notchR + 6,
              right: BusPassMetrics.notchR + 6,
              top: BusPassMetrics.tearY - 1.5,
              height: 3,
              child: CustomPaint(painter: _DotRulePainter(c.faint)),
            ),
            _Baselined(
              baseline: BusPassMetrics.seatLabelBaseline,
              left: inset,
              child: Text('Seat', style: BusPassType.label(c.muted)),
            ),
            _Baselined(
              baseline: BusPassMetrics.seatBaseline,
              left: inset,
              width: BusPassMetrics.seatWidth,
              child: Text(
                seat,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BusPassType.seat(
                  c.ink,
                  long: seat.length > BusPassType.seatShortLength,
                ),
              ),
            ),
            if (fare.isNotEmpty) ...<Widget>[
              _Baselined(
                baseline: BusPassMetrics.seatLabelBaseline,
                right: inset,
                child: Text('Fare', style: BusPassType.label(c.muted)),
              ),
              _Baselined(
                baseline: BusPassMetrics.seatBaseline,
                right: inset,
                child: Text(fare, maxLines: 1, style: BusPassType.value(c.ink)),
              ),
            ],
            _Baselined(
              baseline: BusPassMetrics.passengerLabelBaseline,
              left: inset,
              child: Text('Passengers', style: BusPassType.label(c.muted)),
            ),
            _Baselined(
              baseline: BusPassMetrics.passengerBaseline,
              left: inset,
              width: BusPassMetrics.passengerWidth,
              child: Text(
                _passengers(p),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BusPassType.value(c.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pieces ────────────────────────────────────────────────────────────────────

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.pass, required this.style});

  final BusPass pass;
  final BusBrandStyle style;

  @override
  Widget build(BuildContext context) {
    if (!style.hasWordmark) {
      return Text(
        _orDash(pass.operator.trim()),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: BusPassType.name(style.ink),
      );
    }
    // Two runs on one baseline, so "redBus" keeps its light-then-bold lockup.
    return Text.rich(
      TextSpan(
        children: <TextSpan>[
          TextSpan(
            text: style.wordmarkLead,
            style: BusPassType.nameLight(style.ink),
          ),
          TextSpan(
            text: style.wordmarkTail,
            style: BusPassType.name(style.ink),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// A big time with its meridiem on the same baseline, or a dash when the
/// ticket's time does not parse — free text at 44 dp would run off the card.
class _Time extends StatelessWidget {
  const _Time(this.clock, this.style, {super.key});

  final ({String time, String meridiem})? clock;
  final BusBrandStyle style;

  @override
  Widget build(BuildContext context) {
    final ({String time, String meridiem})? t = clock;
    if (t == null) {
      return Text(_absent, maxLines: 1, style: BusPassType.time(style.ink));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(
          t.time,
          maxLines: 1,
          softWrap: false,
          style: BusPassType.time(style.ink),
        ),
        const SizedBox(width: BusPassMetrics.meridiemGap),
        Text(
          t.meridiem,
          maxLines: 1,
          softWrap: false,
          style: BusPassType.meridiem(style.muted),
        ),
      ],
    );
  }
}

// ── Formatting ────────────────────────────────────────────────────────────────

const String _absent = '—';

String _orDash(String value) => value.trim().isEmpty ? _absent : value.trim();

const List<String> _weekdays = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];
const List<String> _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "16 Aug 2026" -> "Sun, 16 Aug". The year is noise on a live ticket; the
/// weekday is what people plan around.
String _headerDate(String raw) {
  final DateTime? d = PassActivityDate.parse(raw);
  if (d == null) return _orDash(raw);
  return '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';
}

/// The station part of a free-text stop.
///
/// Operators write the stop as "city, station" ("Bengaluru, Kempegowda Bus
/// Station"); the city already sits above the time, so the station is what
/// goes under it. An explicit boarding point from the payload wins outright.
String _stationOf(String location, String explicitPoint) {
  final String point = explicitPoint.trim();
  if (point.isNotEmpty) return point;

  final String value = location.trim();
  final int i = value.indexOf(',');
  if (i < 0) return value;

  final String tail = value.substring(i + 1).trim();
  return tail.isEmpty ? value : tail;
}

/// [station], unless it only repeats [city] — printing the same word above
/// and below a time looks like a bug.
String _stopUnder(String station, String city) =>
    station.toLowerCase() == city.toLowerCase() ? '' : station;

/// "12A" for one seat; a short list for a small group, and the first seat plus
/// a count past three — a cut-off list reads as broken.
String _seatLabel(BusPass pass) {
  final String explicit = pass.seatDetails.trim();
  final List<String> seats = explicit.isNotEmpty
      ? explicit
            .split(',')
            .map((String s) => s.trim())
            .where((String s) => s.isNotEmpty)
            .toList()
      : <String>[
          for (final BusPassenger p in pass.passengers)
            if (p.seat.trim().isNotEmpty) p.seat.trim(),
        ];
  if (seats.isEmpty) return _absent;
  if (seats.length <= 3) return seats.join(', ');
  return '${seats.first} and ${seats.length - 1} more';
}

/// "Navadeep Naidu" alone; "Navadeep and 1 other" for a group, as on the
/// train face.
String _passengers(BusPass pass) {
  if (pass.passengers.isEmpty) return _absent;
  final String lead = pass.passengers.first.name.trim();
  if (pass.passengers.length == 1) return _orDash(lead);
  final String first = lead.isEmpty ? 'Traveller' : lead.split(' ').first;
  final int others = pass.passengers.length - 1;
  return '$first and $others ${others == 1 ? 'other' : 'others'}';
}

// ── Layout helpers ────────────────────────────────────────────────────────────
//
// The same three helpers the train face uses, kept local rather than shared
// while that face has work in flight.

/// Positions [child] so its text baseline lands exactly on [baseline].
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

  /// Width of the text column, passed to the child as a *tight* constraint so
  /// `textAlign` has a box to align in — `Baseline` loosens its constraints.
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

/// Two texts pinned to opposite ends of one baseline-aligned row, each allowed
/// at most half the width so a long name ellipsizes instead of colliding.
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
        const SizedBox(width: BusPassMetrics.columnGap),
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

enum _Slot { departure, arrival, rule, duration }

/// Lays the route rule into the gap between the two times and centres the
/// duration above it. A delegate rather than a Row, because a Row asserts when
/// the times outgrow the card; here the rule just collapses.
class _BetweenTimesDelegate extends MultiChildLayoutDelegate {
  _BetweenTimesDelegate();

  @override
  void performLayout(Size size) {
    final BoxConstraints loose = BoxConstraints(maxWidth: size.width);
    final double dep = layoutChild(_Slot.departure, loose).width;
    final double arr = layoutChild(_Slot.arrival, loose).width;
    positionChild(_Slot.departure, Offset.zero);
    positionChild(_Slot.arrival, Offset.zero);

    final double start = dep + BusPassMetrics.ruleGap;
    final double ruleWidth = math.max(
      0,
      size.width - arr - BusPassMetrics.ruleGap - start,
    );
    layoutChild(
      _Slot.rule,
      BoxConstraints.tightFor(width: ruleWidth, height: 1),
    );
    positionChild(_Slot.rule, Offset(start, size.height - 1));

    if (hasChild(_Slot.duration)) {
      // The duration may use the clear space either side of the rule too; a
      // long overnight run on a short rule still prints whole.
      final double room = ruleWidth + 2 * BusPassMetrics.ruleGap - 4;
      final Size d = layoutChild(
        _Slot.duration,
        BoxConstraints(maxWidth: math.max(0, room)),
      );
      positionChild(
        _Slot.duration,
        Offset(
          start + (ruleWidth - d.width) / 2,
          size.height - 1 - BusPassMetrics.durationGap - d.height,
        ),
      );
    }
  }

  @override
  bool shouldRelayout(covariant MultiChildLayoutDelegate oldDelegate) => false;
}

/// The route line: a faint track with the travelled share drawn in ink.
class _RoutePainter extends CustomPainter {
  const _RoutePainter({
    required this.progress,
    required this.track,
    required this.fill,
  });

  final double progress;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final double y = size.height / 2;
    final Paint paint = Paint()..strokeWidth = 1;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint..color = track);
    if (progress > 0) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width * progress.clamp(0.0, 1.0), y),
        paint..color = fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) =>
      old.progress != progress || old.track != track || old.fill != fill;
}

/// The tear: round dots on an even pitch, centred so both ends match.
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
