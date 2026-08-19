import 'package:flutter/material.dart';

import '../../domain/bus_pass_models.dart';
import '../../domain/pass_activity_date.dart';
import '../../domain/pass_status.dart';
import '../pass_code_block.dart';
import 'bus_pass_theme.dart';

export 'bus_pass_theme.dart' show BusPassPalette;

/// Bus pass face — cool mint paper, teal route rail, Geist throughout.
///
/// A sibling to the train face rather than a copy of it. The train sets its
/// station codes huge because Indian Railways gives every station a three
/// letter code that a traveller reads at a glance; a bus boarding point is a
/// place and a landmark ("Hyderabad" / "Miyapur, Bay 12") with no code to set,
/// so the *times* carry the hierarchy instead and the route runs as a vertical
/// rail. Setting long place names at code size would have wrapped or ellipsed
/// on most real bookings.
///
/// Laid out as a flow inside a fixed canvas, not by absolute baseline. The
/// train face is absolutely positioned because it was traced from a Figma
/// export and its baselines had to match it; there is no export for the bus
/// card, and a flow layout is what keeps a long operator name or a two-line
/// place from needing every constant below it re-measured.
class BusTicketFace extends StatelessWidget {
  const BusTicketFace({
    super.key,
    required this.pass,
    this.useBrandColors = false,
    this.onOpenCodes,
  });

  final BusPass pass;

  /// Force the live palette on a pass the wallet considers expired.
  final bool useBrandColors;

  /// Non-null makes the code block tappable — detail screen only.
  final VoidCallback? onOpenCodes;

  @override
  Widget build(BuildContext context) {
    final bool isExpired =
        !useBrandColors && pass.status == TicketStatus.expired;
    final BusPassColors c = BusPassColors.of(isExpired: isExpired);

    return Container(
      width: BusPassMetrics.width,
      height: BusPassMetrics.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BusPassMetrics.cornerR),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: c.shadowAlpha),
            blurRadius: 30,
            offset: const Offset(0, 16),
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BusPassMetrics.cornerR),
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: ColoredBox(color: c.surface)),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  BusPassMetrics.inset,
                  28,
                  BusPassMetrics.inset,
                  26,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _Header(pass: pass, colors: c),
                    const SizedBox(height: 20),
                    SizedBox(height: 1, child: ColoredBox(color: c.rule)),
                    const SizedBox(height: 30),
                    _RouteBlock(pass: pass, colors: c),
                    const Spacer(),
                    SizedBox(
                      height: 1.5,
                      child: PassDashedRule(color: c.rule),
                    ),
                    const SizedBox(height: 28),
                    _MetaRow(
                      leftLabel: 'Date',
                      leftValue: _orDash(pass.date),
                      rightLabel: 'Seat',
                      rightValue: _seatLabel(pass),
                      colors: c,
                    ),
                    const SizedBox(height: 26),
                    _Footer(
                      pass: pass,
                      colors: c,
                      onOpenCodes: onOpenCodes,
                    ),
                  ],
                ),
              ),
            ),

            // Border last so the clip never eats it.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(BusPassMetrics.cornerR),
                    border: Border.all(color: c.border),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pieces ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.pass, required this.colors});

  final BusPass pass;
  final BusPassColors colors;

  @override
  Widget build(BuildContext context) {
    final String operator = pass.operator.trim();
    final int seats = _seatCount(pass);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Text(
            (operator.isEmpty ? 'Bus' : operator).toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BusPassType.operatorName(colors.accent),
          ),
        ),
        if (seats > 0) ...<Widget>[
          const SizedBox(width: 12),
          _Chip(
            label: seats == 1 ? '1 seat' : '$seats seats',
            colors: colors,
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.colors});

  final String label;
  final BusPassColors colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.chipFill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(
          label,
          maxLines: 1,
          style: BusPassType.chip(colors.chipInk),
        ),
      ),
    );
  }
}

/// Departure over arrival on a dotted rail.
class _RouteBlock extends StatelessWidget {
  const _RouteBlock({required this.pass, required this.colors});

  final BusPass pass;
  final BusPassColors colors;

  @override
  Widget build(BuildContext context) {
    final int dayOffset = _arrivalDayOffset(pass);
    final String duration = _durationLabel(pass);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _RouteStop(
          time: pass.departTime,
          place: pass.boardingLocation,
          colors: colors,
          filled: true,
        ),
        // The rail: dashed run between the two dots, aligned under the first,
        // with the journey duration set beside its midpoint.
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const SizedBox(
              width: BusPassMetrics.timeColumnWidth +
                  BusPassMetrics.timeToRail,
            ),
            SizedBox(
              width: BusPassMetrics.railWidth,
              height: BusPassMetrics.connectorHeight,
              child: PassDashedRule(
                color: colors.rule,
                strokeWidth: 2,
                dash: 4,
                gap: 5,
                vertical: true,
              ),
            ),
            if (duration.isNotEmpty) ...<Widget>[
              const SizedBox(width: BusPassMetrics.railToPlace),
              Expanded(
                child: Text(
                  duration,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BusPassType.duration(colors.muted),
                ),
              ),
            ],
          ],
        ),
        _RouteStop(
          time: pass.arriveTime,
          place: pass.dropLocation,
          colors: colors,
          filled: false,
          dayOffset: dayOffset,
        ),
      ],
    );
  }
}

class _RouteStop extends StatelessWidget {
  const _RouteStop({
    required this.time,
    required this.place,
    required this.colors,
    required this.filled,
    this.dayOffset = 0,
  });

  final String time;
  final String place;
  final BusPassColors colors;

  /// Origin dot is solid, destination is a ring — the same read as a route map.
  final bool filled;

  /// Calendar days the arrival lands past the departure. 0 hides the marker.
  final int dayOffset;

  @override
  Widget build(BuildContext context) {
    final (String head, String detail) = _splitPlace(place);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: BusPassMetrics.timeColumnWidth,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Flexible(
                child: Text(
                  _orDash(time),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BusPassType.routeTime(colors.ink),
                ),
              ),
              if (dayOffset > 0) ...<Widget>[
                const SizedBox(width: 4),
                Text(
                  '+$dayOffset',
                  maxLines: 1,
                  style: BusPassType.dayOffset(colors.muted),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: BusPassMetrics.timeToRail),
        SizedBox(
          width: BusPassMetrics.railWidth,
          child: Center(
            child: _Dot(colors: colors, filled: filled),
          ),
        ),
        const SizedBox(width: BusPassMetrics.railToPlace),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                head,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BusPassType.placeName(colors.ink),
              ),
              if (detail.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: BusPassType.placeDetail(colors.muted),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.colors, required this.filled});

  final BusPassColors colors;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    // Sits on the cap line of the time beside it rather than the top of the
    // text box, so the dot reads as marking that row.
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: BusPassMetrics.dotSize,
        height: BusPassMetrics.dotSize,
        decoration: BoxDecoration(
          color: filled ? colors.accent : colors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: colors.accent, width: 2),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
    required this.colors,
  });

  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;
  final BusPassColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: _Field(
            label: leftLabel,
            value: leftValue,
            colors: colors,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _Field(
            label: rightLabel,
            value: rightValue,
            colors: colors,
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    required this.colors,
  });

  final String label;
  final String value;
  final BusPassColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: BusPassType.label(colors.muted),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: BusPassType.value(colors.ink),
        ),
      ],
    );
  }
}

/// Passenger and booking reference beside the code block.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.pass,
    required this.colors,
    this.onOpenCodes,
  });

  final BusPass pass;
  final BusPassColors colors;
  final VoidCallback? onOpenCodes;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Field(
                label: 'Passenger',
                value: _passengerLabel(pass),
                colors: colors,
              ),
              const SizedBox(height: 22),
              _Field(
                label: 'Booking ID',
                value: _orDash(pass.bookingId),
                colors: colors,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        PassCodeBlock(
          size: BusPassMetrics.codeSize,
          ink: colors.ink,
          borderColor: colors.codeBorder,
          onTap: onOpenCodes,
        ),
      ],
    );
  }
}

// ── Formatting ────────────────────────────────────────────────────────────────

const String _absent = '—';

String _orDash(String value) => value.trim().isEmpty ? _absent : value.trim();

/// Splits "Hyderabad, Miyapur" into a headline place and its landmark.
///
/// Operators write the boarding point as one free-text string and the city is
/// almost always first, so the leading segment is the part worth setting large.
/// A string with no separator keeps the whole thing as the headline rather than
/// inventing a detail line.
(String, String) _splitPlace(String raw) {
  final String value = raw.trim();
  if (value.isEmpty) return (_absent, '');

  final int i = value.indexOf(',');
  if (i <= 0) return (value, '');

  final String head = value.substring(0, i).trim();
  final String rest = value.substring(i + 1).trim();
  if (head.isEmpty) return (value, '');
  return (head, rest);
}

int _seatCount(BusPass pass) {
  if (pass.passengers.isNotEmpty) return pass.passengers.length;
  final String seats = pass.seatDetails.trim();
  if (seats.isEmpty) return 0;
  return seats.split(',').where((String s) => s.trim().isNotEmpty).length;
}

String _seatLabel(BusPass pass) {
  final String seats = pass.seatDetails.trim();
  if (seats.isNotEmpty) return seats;

  final Iterable<String> fromPassengers = pass.passengers
      .map((BusPassenger p) => p.seat.trim())
      .where((String s) => s.isNotEmpty);
  if (fromPassengers.isEmpty) return _absent;
  return fromPassengers.join(', ');
}

/// The lead passenger, with a count when they are not travelling alone — one
/// name standing for a group of six is worse than saying how many there are.
String _passengerLabel(BusPass pass) {
  if (pass.passengers.isEmpty) return _absent;
  final String lead = pass.passengers.first.name.trim();
  if (lead.isEmpty) return _absent;
  if (pass.passengers.length == 1) return lead;
  return '$lead  +${pass.passengers.length - 1}';
}

/// Journey length, e.g. "8h 15m".
///
/// Computed rather than stored: [BusPass] has no duration field, and the two
/// ISO instants are the only trustworthy source — the display times carry no
/// date, so an overnight run would otherwise compute as negative. Returns an
/// empty string when either instant is missing, and the rail simply runs
/// without a label.
String _durationLabel(BusPass pass) {
  final DateTime? depart = PassActivityDate.parse(pass.departAt);
  final DateTime? arrive = PassActivityDate.parse(pass.arriveAt);
  if (depart == null || arrive == null) return '';

  final Duration d = arrive.difference(depart);
  if (d.inMinutes <= 0) return '';

  final int hours = d.inHours;
  final int minutes = d.inMinutes % 60;
  if (hours == 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

/// Calendar days the arrival lands past the departure, for the "+1" marker on
/// an overnight coach.
///
/// Prefers the ISO fields and falls back to the display dates. Returns 0 when
/// either side is unparseable — an unmarked arrival is better than a wrong one.
int _arrivalDayOffset(BusPass pass) {
  final DateTime? depart =
      PassActivityDate.parse(pass.departAt) ?? PassActivityDate.parse(pass.date);
  final DateTime? arrive = PassActivityDate.parse(pass.arriveAt) ??
      PassActivityDate.parse(pass.arrivalDate);
  if (depart == null || arrive == null) return 0;

  final int days = DateTime(arrive.year, arrive.month, arrive.day)
      .difference(DateTime(depart.year, depart.month, depart.day))
      .inDays;
  return days > 0 ? days : 0;
}
