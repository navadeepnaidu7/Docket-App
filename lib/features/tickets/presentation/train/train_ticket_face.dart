import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/pass_activity_date.dart';
import '../../domain/ticket_models.dart';
import '../movie/movie_ticket_chrome.dart';
import 'train_journey_status.dart';
import 'train_pass_theme.dart';

/// How dense the shared train face should render.
///
/// Both densities draw the *same* face on the same [TrainPassMetrics.canvas];
/// the enum survives so call sites keep saying which context they are in.
enum TrainTicketDensity {
  /// Passes stack — the card in the wallet carousel.
  glance,

  /// Fullscreen detail — identical layout, scaled up.
  detail,
}

/// Train pass face — one graphite surface, type and spacing only.
///
/// Laid out against a fixed canvas and scaled by `WalletCardCanvas`. Every line
/// is placed by baseline; see `docs/features/train-pass-redesign.md`.
class TrainTicketFace extends StatelessWidget {
  const TrainTicketFace({
    super.key,
    required this.ticket,
    required this.density,
    this.useBrandColors = false,
    this.widthFactor,
    this.showShadow = true,
    this.clock = DateTime.now,
  });

  final MockTicket ticket;
  final TrainTicketDensity density;

  /// Force the live palette on a pass the wallet considers expired.
  final bool useBrandColors;

  /// Retained for callers that inset the face inside its box.
  final double? widthFactor;

  final bool showShadow;

  /// Injected for tests so the status sentence is deterministic.
  final DateTime Function() clock;

  @visibleForTesting
  static const Key departureKey = Key('train_pass.departure');
  @visibleForTesting
  static const Key arrivalKey = Key('train_pass.arrival');
  @visibleForTesting
  static const Key routeKey = Key('train_pass.route');

  @override
  Widget build(BuildContext context) {
    final MockTicket t = ticket;
    final bool isExpired = !useBrandColors && t.status == TicketStatus.expired;
    final TrainPassColors c = TrainPassColors.of(isExpired: isExpired);
    final TrainJourneyStatus status = resolveTrainJourneyStatus(t, clock());

    final int? depShift = status.departureShiftMinutes;
    final int? arrShift = status.arrivalShiftMinutes;
    final String dep = _faceTime(t.departTime, depShift);
    final String arr = _faceTime(t.arriveTime, arrShift);
    final int dayOffset = trainArrivalDayOffset(t);

    const double inset = TrainPassMetrics.inset;
    const double width = TrainPassMetrics.contentWidth;

    final Widget card = Container(
      width: TrainPassMetrics.width,
      height: TrainPassMetrics.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TrainPassMetrics.cornerR),
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
          cornerR: TrainPassMetrics.cornerR,
          notchR: TrainPassMetrics.notchR,
          notchFromBottom: TrainPassMetrics.notchFromBottom,
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
              baseline: TrainPassMetrics.nameBaseline,
              left: inset,
              width: width,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      t.trainName.trim().isEmpty
                          ? 'Train ticket'
                          : t.trainName.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TrainPassType.name(c.ink),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _headerDate(t.date),
                    maxLines: 1,
                    style: TrainPassType.date(c.ink),
                  ),
                ],
              ),
            ),
            _Baselined(
              baseline: TrainPassMetrics.numberBaseline,
              left: inset,
              width: width,
              child: Text(
                _orDash(t.trainNumber.trim()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TrainPassType.small(c.muted),
              ),
            ),

            // ── Journey ──
            _Baselined(
              baseline: TrainPassMetrics.cityBaseline,
              left: inset,
              width: width,
              child: _Ends(
                start: Text(
                  _orDash(t.fromName.trim()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TrainPassType.small(c.muted),
                ),
                end: Text(
                  _orDash(t.toName.trim()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TrainPassType.small(c.muted),
                ),
              ),
            ),

            // The route rule spans exactly the gap the two times leave, with
            // the duration centred above it. The times are laid out again
            // inside the delegate, invisibly, so the rule's ends come from
            // layout rather than from a TextPainter measured in build — which
            // would run once, before Geist resolves, and keep the fallback
            // face's widths forever.
            Positioned(
              left: inset,
              right: inset,
              top: TrainPassMetrics.ruleY - 0.5 - TrainPassMetrics.ruleLift,
              height: TrainPassMetrics.ruleLift + 1,
              child: CustomMultiChildLayout(
                delegate: _BetweenTimesDelegate(),
                children: <Widget>[
                  LayoutId(id: _Slot.departure, child: _Ghost(dep)),
                  LayoutId(id: _Slot.arrival, child: _Ghost(arr)),
                  LayoutId(
                    id: _Slot.rule,
                    child: CustomPaint(
                      key: TrainTicketFace.routeKey,
                      painter: _RoutePainter(
                        progress: status.progress,
                        track: c.faint,
                        fill: c.ink,
                      ),
                    ),
                  ),
                  if (t.duration.trim().isNotEmpty)
                    LayoutId(
                      id: _Slot.duration,
                      child: Text(
                        t.duration.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                        style: TrainPassType.duration(c.muted),
                      ),
                    ),
                ],
              ),
            ),
            _Baselined(
              baseline: TrainPassMetrics.timeBaseline,
              left: inset - TrainTimeOptics.leftPull(dep),
              child: Text(
                dep,
                key: TrainTicketFace.departureKey,
                maxLines: 1,
                softWrap: false,
                style: TrainPassType.time(depShift != null ? c.warning : c.ink),
              ),
            ),
            _Baselined(
              baseline: TrainPassMetrics.timeBaseline,
              right: inset - TrainTimeOptics.rightPush(arr),
              child: Text(
                arr,
                key: TrainTicketFace.arrivalKey,
                maxLines: 1,
                softWrap: false,
                style: TrainPassType.time(arrShift != null ? c.warning : c.ink),
              ),
            ),
            if (dayOffset > 0)
              _Baselined(
                baseline: TrainPassMetrics.dayMarkerBaseline,
                left: TrainPassMetrics.contentRight +
                    TrainPassMetrics.dayMarkerGap,
                child: Text(
                  '+$dayOffset',
                  maxLines: 1,
                  softWrap: false,
                  style: TrainPassType.dayMarker(c.muted),
                ),
              ),
            _Baselined(
              baseline: TrainPassMetrics.codeBaseline,
              left: inset,
              width: width,
              child: _Ends(
                start: _CodeWithWas(
                  code: _code(t.fromCode),
                  was: depShift == null ? null : trainClock24(t.departTime),
                  colors: c,
                ),
                end: _CodeWithWas(
                  code: _code(t.toCode),
                  was: arrShift == null ? null : trainClock24(t.arriveTime),
                  colors: c,
                  trailing: true,
                ),
              ),
            ),

            // ── Status ──
            _Baselined(
              // A lone lead line drops to the middle of the two-line block, so
              // a card with nothing more to say keeps even space to the tear.
              baseline: status.details.isEmpty
                  ? (TrainPassMetrics.leadBaseline +
                            TrainPassMetrics.detailBaseline) /
                        2
                  : TrainPassMetrics.leadBaseline,
              left: inset,
              width: width,
              child: Text.rich(
                TextSpan(
                  children: <TextSpan>[
                    if (status.lead.isNotEmpty)
                      TextSpan(
                        text: '${status.lead} ',
                        style: TrainPassType.lead(c.muted),
                      ),
                    TextSpan(
                      text: status.emphasis,
                      style: TrainPassType.lead(
                        _tone(status.emphasisTone, c, c.ink),
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (status.details.isNotEmpty)
              _Baselined(
                baseline: TrainPassMetrics.detailBaseline,
                left: inset,
                width: width,
                child: Text.rich(
                  TextSpan(children: _detailSpans(status, c)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // ── Stub ──
            Positioned(
              left: TrainPassMetrics.notchR + 6,
              right: TrainPassMetrics.notchR + 6,
              top: TrainPassMetrics.tearY - 1.5,
              height: 3,
              child: CustomPaint(painter: _DotRulePainter(c.faint)),
            ),
            ..._field('Coach', _coaches(t), 0, c, left: inset),
            ..._field(
              'Berth',
              _berths(t),
              0,
              c,
              left: TrainPassMetrics.columnTwoX,
              width: TrainPassMetrics.berthWidth,
            ),
            ..._field('Class', _classCode(t.ticketClass), 0, c, end: true),
            ..._field(
              'Passengers',
              _passengers(t),
              1,
              c,
              left: inset,
              width: TrainPassMetrics.columnWidth * 2,
            ),
            ..._field('Platform', _platform(t.platformLabel), 1, c, end: true),
          ],
        ),
      ),
    );

    final double factor = widthFactor ?? 1.0;
    if (factor >= 0.999) return card;
    return Align(
      child: FractionallySizedBox(widthFactor: factor, child: card),
    );
  }

  List<Widget> _field(
    String label,
    String value,
    int row,
    TrainPassColors c, {
    double? left,
    double width = TrainPassMetrics.columnWidth,
    bool end = false,
  }) {
    final TextAlign align = end ? TextAlign.right : TextAlign.left;
    final double? right = end ? TrainPassMetrics.inset : null;
    return <Widget>[
      _Baselined(
        baseline: TrainPassMetrics.labelBaseline(row),
        left: left,
        right: right,
        width: width,
        child: Text(
          label,
          maxLines: 1,
          textAlign: align,
          style: TrainPassType.label(c.muted),
        ),
      ),
      _Baselined(
        baseline: TrainPassMetrics.valueBaseline(row),
        left: left,
        right: right,
        width: width,
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: TrainPassType.value(c.ink),
        ),
      ),
    ];
  }

  static List<TextSpan> _detailSpans(
    TrainJourneyStatus status,
    TrainPassColors c,
  ) {
    final List<TextSpan> out = <TextSpan>[];
    for (int i = 0; i < status.details.length; i++) {
      final TrainStatusPart part = status.details[i];
      final String text = i == 0
          ? part.text[0].toUpperCase() + part.text.substring(1)
          : part.text;
      if (i > 0) {
        out.add(TextSpan(text: ', ', style: TrainPassType.detail(c.muted)));
      }
      out.add(
        TextSpan(
          text: text,
          style: TrainPassType.detail(_tone(part.tone, c, c.muted)),
        ),
      );
    }
    return out;
  }

  static Color _tone(TrainStatusTone tone, TrainPassColors c, Color neutral) =>
      switch (tone) {
        TrainStatusTone.neutral => neutral,
        TrainStatusTone.warning => c.warning,
        TrainStatusTone.critical => c.critical,
      };
}

// ── Formatting ────────────────────────────────────────────────────────────────

const String _absent = '—';

String _orDash(String value) => value.isEmpty ? _absent : value;

String _code(String raw) => _orDash(raw.trim().toUpperCase());

/// A parseable time in 24-hour form, else a dash. Free text ("To be
/// announced") set at 50 dp would run straight off the card.
String _faceTime(String raw, int? shiftMinutes) =>
    parseTrainClock(raw) == null
    ? _absent
    : trainClock24(raw, shiftMinutes: shiftMinutes ?? 0);

const List<String> _weekdays = <String>[
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
];
const List<String> _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "16 Aug 2026" -> "Sun, 16 Aug". The year is noise on a live ticket; the
/// weekday is what people plan around.
String _headerDate(String raw) {
  final DateTime? d = PassActivityDate.parse(raw);
  if (d == null) return _orDash(raw.trim());
  return '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';
}

String _coaches(MockTicket t) {
  if (t.passengers.isEmpty) return _absent;
  final List<String> coaches = <String>{
    for (final TicketPassenger p in t.passengers)
      if (p.coach.trim().isNotEmpty) p.coach.trim(),
  }.toList();
  return coaches.isEmpty ? _absent : coaches.join(', ');
}

/// "32 Lower" for one traveller; seat numbers alone for a small group, and the
/// first seat plus a count past three — a cut-off list reads as broken.
String _berths(MockTicket t) {
  if (t.passengers.isEmpty) return _absent;
  if (t.passengers.length == 1) {
    final TicketPassenger p = t.passengers.first;
    return _orDash(
      <String>[p.seat.trim(), p.berth.trim()]
          .where((String s) => s.isNotEmpty && s != _absent)
          .join(' '),
    );
  }
  final List<String> seats = <String>[
    for (final TicketPassenger p in t.passengers)
      if (p.seat.trim().isNotEmpty) p.seat.trim(),
  ];
  if (seats.isEmpty) return _absent;
  if (seats.length <= 3) return seats.join(', ');
  return '${seats.first} and ${seats.length - 1} more';
}

String _passengers(MockTicket t) {
  if (t.passengers.isEmpty) return _absent;
  final String lead = t.passengers.first.name.trim();
  if (t.passengers.length == 1) return _orDash(lead);
  final String first = lead.split(' ').first;
  final int others = t.passengers.length - 1;
  return '$first and $others ${others == 1 ? 'other' : 'others'}';
}

/// The code printed on the ticket and the coach — "AC 3 Tier" -> "3A".
String _classCode(String raw) {
  final String v = raw.trim();
  if (v.isEmpty) return _absent;
  final String s = v.toLowerCase();
  if (v.length <= 3) return v.toUpperCase();
  if (s.contains('economy')) return '3E';
  if (s.contains('first') || s.contains('ac 1') || s.contains('1 tier')) {
    return '1A';
  }
  if (s.contains('ac 2') || s.contains('2 tier') || s.contains('two tier')) {
    return '2A';
  }
  if (s.contains('ac 3') || s.contains('3 tier') || s.contains('three tier')) {
    return '3A';
  }
  if (s.contains('executive')) return 'EC';
  if (s.contains('chair')) return 'CC';
  if (s.contains('sleeper')) return 'SL';
  if (s.contains('second sitting')) return '2S';
  return v;
}

/// "PF 3" / "Platform 3" / "3" -> "3".
String _platform(String? raw) {
  if (raw == null) return _absent;
  final String v = raw
      .trim()
      .replaceFirst(RegExp(r'^(platform|pf)[\s.:-]*', caseSensitive: false), '')
      .trim();
  return _orDash(v);
}

// ── Layout helpers ────────────────────────────────────────────────────────────

/// Positions [child] so its text baseline lands exactly on [baseline].
///
/// Placing by `top` instead would need each font's ascent, which differs
/// between Geist and the fallback face google_fonts uses before the real font
/// arrives — the card would shift on first launch and settle later.
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

  /// Width of the text column, passed to the child as a *tight* constraint.
  final double? width;

  @override
  Widget build(BuildContext context) {
    // RenderBaseline lays its child out under constraints.loosen() and pins it
    // at Offset(0, top). A Text child therefore shrink-wraps and sits flush
    // left no matter what, so `textAlign: TextAlign.right` silently does
    // nothing. The SizedBox restores a tight width so the child fills the
    // column and can align inside it.
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
        // Rows, not Align: an Align would expand to the full height Baseline
        // hands down and centre the text in it, losing the baseline.
        Expanded(child: _side(start, MainAxisAlignment.start)),
        const SizedBox(width: 16),
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

/// A station code, with the scheduled time struck through beside it when a
/// known delay has moved the time printed above.
class _CodeWithWas extends StatelessWidget {
  const _CodeWithWas({
    required this.code,
    required this.was,
    required this.colors,
    this.trailing = false,
  });

  final String code;
  final String? was;
  final TrainPassColors colors;

  /// The struck time goes before the code on the right-hand side, so the code
  /// itself keeps the shared right edge.
  final bool trailing;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = TrainPassType.small(colors.muted);
    final Widget codeText = Text(code, maxLines: 1, style: style);
    if (was == null || was!.isEmpty) return codeText;
    final Widget wasText = Text(
      was!,
      maxLines: 1,
      style: style.copyWith(
        decoration: TextDecoration.lineThrough,
        decorationColor: colors.muted,
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: trailing
          ? <Widget>[wasText, const SizedBox(width: 8), codeText]
          : <Widget>[codeText, const SizedBox(width: 8), wasText],
    );
  }
}

/// An invisible copy of a big time, laid out only to reserve its width.
class _Ghost extends StatelessWidget {
  const _Ghost(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        style: TrainPassType.time(const Color(0xFF000000)),
      ),
    );
  }
}

enum _Slot { departure, arrival, rule, duration }

/// Lays the route rule into the gap between the two times and centres the
/// duration above it.
///
/// A delegate rather than a Row because a Row asserts when its children do not
/// fit, and an unparseable time or the test font's full-em glyphs can make the
/// two times wider than the card. Here the rule just collapses to nothing.
class _BetweenTimesDelegate extends MultiChildLayoutDelegate {
  _BetweenTimesDelegate();

  @override
  void performLayout(Size size) {
    final BoxConstraints loose = BoxConstraints(maxWidth: size.width);
    final double dep = layoutChild(_Slot.departure, loose).width;
    final double arr = layoutChild(_Slot.arrival, loose).width;
    positionChild(_Slot.departure, Offset.zero);
    positionChild(_Slot.arrival, Offset.zero);

    final double start = dep + TrainPassMetrics.ruleGap;
    final double ruleWidth = math.max(
      0,
      size.width - arr - TrainPassMetrics.ruleGap - start,
    );
    layoutChild(
      _Slot.rule,
      BoxConstraints.tightFor(width: ruleWidth, height: 1),
    );
    positionChild(_Slot.rule, Offset(start, size.height - 1));

    if (hasChild(_Slot.duration)) {
      final Size d = layoutChild(
        _Slot.duration,
        BoxConstraints(maxWidth: ruleWidth),
      );
      positionChild(
        _Slot.duration,
        Offset(
          start + (ruleWidth - d.width) / 2,
          size.height - 1 - TrainPassMetrics.durationGap - d.height,
        ),
      );
    }
  }

  @override
  bool shouldRelayout(covariant MultiChildLayoutDelegate oldDelegate) => false;
}

// ── Painters ──────────────────────────────────────────────────────────────────

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
