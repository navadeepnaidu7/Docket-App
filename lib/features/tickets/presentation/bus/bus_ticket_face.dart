import 'package:flutter/material.dart';

import '../../domain/bus_pass_models.dart';
import '../../domain/pass_activity_date.dart';
import '../../domain/pass_status.dart';
import 'bus_brand_style.dart';
import 'bus_pass_theme.dart';

/// Bus pass face — brand header over a paper body.
///
/// One clean rounded rectangle. Real coach tickets have a die-cut notch
/// between the stub and the body; it is skipped here deliberately, because on
/// a phone it reads as decoration and costs a custom clipper plus a border
/// that has to trace the same path.
///
/// The chrome is per-operator and comes from [BusBrandStyle], so adding an
/// operator does not touch this file. An operator with no style of its own
/// gets a neutral slate header rather than someone else's branding.
///
/// No icons. Every mark on the card is either type or a plain geometric rule,
/// which is what keeps it reading as a printed ticket rather than as app UI.
class BusTicketFace extends StatelessWidget {
  const BusTicketFace({
    super.key,
    required this.pass,
    this.useBrandColors = false,
  });

  final BusPass pass;

  /// Force the live palette on a pass the wallet considers expired.
  final bool useBrandColors;

  @override
  Widget build(BuildContext context) {
    final BusBrandStyle brand =
        BusBrandStyle.forPass(pass, useBrandColors: useBrandColors);

    return Container(
      width: BusPassMetrics.width,
      height: BusPassMetrics.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BusPassMetrics.cornerR),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: brand.shadowAlpha),
            blurRadius: 30,
            offset: const Offset(0, 16),
            spreadRadius: -6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BusPassMetrics.cornerR),
        child: ColoredBox(
          color: brand.bodySurface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                height: BusPassMetrics.headerHeight,
                child: _Header(pass: pass, brand: brand),
              ),
              Expanded(child: _Body(pass: pass, brand: brand)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.pass, required this.brand});

  final BusPass pass;
  final BusBrandStyle brand;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: brand.headerGradient,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          if (brand.coachAsset != null)
            Positioned(
              right: -BusPassMetrics.coachOverflow,
              bottom: BusPassMetrics.coachBottom,
              width: BusPassMetrics.coachWidth,
              child: Opacity(
                opacity: brand.coachOpacity,
                child: Image.asset(
                  brand.coachAsset!,
                  fit: BoxFit.contain,
                  // The coach is decorative; the route it illustrates is
                  // already stated in type directly beneath it.
                  excludeFromSemantics: true,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                BusPassMetrics.inset,
                34,
                BusPassMetrics.inset,
                26,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _Wordmark(pass: pass, brand: brand),
                  const SizedBox(height: 14),
                  Text(
                    brand.tagline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BusPassType.tagline(brand.headerMuted),
                  ),
                  const Spacer(),
                  Text(
                    'FROM',
                    style: BusPassType.label(brand.headerMuted),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _routeLine(pass),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: BusPassType.headerRoute(brand.headerInk),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.pass, required this.brand});

  final BusPass pass;
  final BusBrandStyle brand;

  @override
  Widget build(BuildContext context) {
    if (!brand.hasWordmark) {
      return Text(
        _orDash(pass.operator),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: BusPassType.operatorName(brand.headerInk),
      );
    }

    // Two runs on one baseline, so "redBus" keeps its light-then-bold lockup.
    return Text.rich(
      TextSpan(
        children: <TextSpan>[
          TextSpan(
            text: brand.wordmarkLead,
            style: BusPassType.wordmarkLead(brand.headerInk),
          ),
          TextSpan(
            text: brand.wordmarkTail,
            style: BusPassType.wordmarkTail(brand.headerInk),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({required this.pass, required this.brand});

  final BusPass pass;
  final BusBrandStyle brand;

  @override
  Widget build(BuildContext context) {
    final String platform = pass.platform.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BusPassMetrics.inset,
        22,
        BusPassMetrics.inset,
        20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _StopRow(pass: pass, brand: brand),
          _Rule(brand: brand, top: 13, bottom: 13),
          _TripleField(
            brand: brand,
            fields: <(String, String)>[
              ('DATE', _orDash(pass.date)),
              ('DEPARTURE', _orDash(pass.departTime)),
              ('SEAT', _seatLabel(pass)),
            ],
          ),
          _Rule(brand: brand, top: 13, bottom: 13),
          _BoardingRow(pass: pass, brand: brand, platform: platform),
          _Rule(brand: brand, top: 13, bottom: 11),
          Text(
            _advisory(pass),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: BusPassType.note(brand.muted),
          ),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.brand, required this.top, required this.bottom});

  final BusBrandStyle brand;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: bottom),
      child: SizedBox(height: 1, child: ColoredBox(color: brand.rule)),
    );
  }
}

/// FROM and TO either side of a short vertical rail.
class _StopRow extends StatelessWidget {
  const _StopRow({required this.pass, required this.brand});

  final BusPass pass;
  final BusBrandStyle brand;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: _Stop(
              label: 'FROM',
              name: _stationOf(pass.boardingLocation, pass.boardingPoint),
              city: pass.resolvedFromCity,
              brand: brand,
              leadingDot: true,
            ),
          ),
          SizedBox(
            width: BusPassMetrics.stopRailWidth,
            child: _StopRail(brand: brand),
          ),
          Expanded(
            child: _Stop(
              label: 'TO',
              name: _stationOf(pass.dropLocation, ''),
              city: pass.resolvedToCity,
              brand: brand,
              leadingDot: false,
            ),
          ),
        ],
      ),
    );
  }
}

/// A dot at each end joined by a hairline, in the brand accent.
class _StopRail extends StatelessWidget {
  const _StopRail({required this.brand});

  final BusBrandStyle brand;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _Dot(color: brand.accent),
          Expanded(
            child: SizedBox(
              width: 2,
              child: ColoredBox(color: brand.accent),
            ),
          ),
          _Dot(color: brand.accent),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: BusPassMetrics.stopDotSize,
      height: BusPassMetrics.stopDotSize,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({
    required this.label,
    required this.name,
    required this.city,
    required this.brand,
    required this.leadingDot,
  });

  final String label;
  final String name;
  final String city;
  final BusBrandStyle brand;
  final bool leadingDot;

  @override
  Widget build(BuildContext context) {
    // A stop with no comma yields the same string for both lines; printing it
    // twice looks like a bug, so the city line drops out.
    final bool showCity =
        city.trim().isNotEmpty && city.trim() != name.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (leadingDot) ...<Widget>[
              _Dot(color: brand.accent),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BusPassType.label(brand.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: BusPassType.stopName(brand.ink),
        ),
        if (showCity) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            city,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BusPassType.secondary(brand.muted),
          ),
        ],
      ],
    );
  }
}

/// Three label/value fields split by hairlines.
class _TripleField extends StatelessWidget {
  const _TripleField({required this.brand, required this.fields});

  final BusBrandStyle brand;
  final List<(String, String)> fields;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[];
    for (int i = 0; i < fields.length; i++) {
      if (i > 0) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SizedBox(width: 1, child: ColoredBox(color: brand.rule)),
          ),
        );
      }
      final (String label, String value) = fields[i];
      children.add(
        Expanded(
          child: _Field(label: label, value: value, brand: brand),
        ),
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    required this.brand,
  });

  final String label;
  final String value;
  final BusBrandStyle brand;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: BusPassType.label(brand.muted),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: BusPassType.value(brand.ink),
        ),
      ],
    );
  }
}

/// Boarding point with its bay, beside the fare.
class _BoardingRow extends StatelessWidget {
  const _BoardingRow({
    required this.pass,
    required this.brand,
    required this.platform,
  });

  final BusPass pass;
  final BusBrandStyle brand;
  final String platform;

  @override
  Widget build(BuildContext context) {
    final String fare = pass.fare.trim();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'BOARDING POINT',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BusPassType.label(brand.muted),
                ),
                const SizedBox(height: 10),
                Text(
                  _stationOf(pass.boardingLocation, pass.boardingPoint),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BusPassType.stopName(brand.ink),
                ),
                if (platform.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    platform,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BusPassType.secondary(brand.muted),
                  ),
                ],
              ],
            ),
          ),
          if (fare.isNotEmpty) ...<Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(width: 1, child: ColoredBox(color: brand.rule)),
            ),
            Expanded(
              flex: 2,
              child: _Field(label: 'FARE', value: fare, brand: brand),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Formatting ────────────────────────────────────────────────────────────────

const String _absent = '—';

String _orDash(String value) => value.trim().isEmpty ? _absent : value.trim();

/// "Bengaluru to Mysuru" for the header.
///
/// An en-dash arrow rather than an icon: the brief rules out icons, and an
/// arrow set in the same face as the words beside it stays on the baseline at
/// every scale, which a glyph from an icon font does not.
String _routeLine(BusPass pass) {
  final String from = pass.resolvedFromCity;
  final String to = pass.resolvedToCity;
  if (from.isEmpty && to.isEmpty) return _absent;
  if (from.isEmpty) return to;
  if (to.isEmpty) return from;
  return '$from  →  $to';
}

/// The station part of a free-text stop.
///
/// Operators write the stop as "city, station" ("Bengaluru, Kempegowda Bus
/// Station"), and it is the station a traveller needs at the kerb, so the
/// trailing segment is the headline and the city sits under it. An explicit
/// boarding point from the payload wins outright.
String _stationOf(String location, String explicitPoint) {
  final String point = explicitPoint.trim();
  if (point.isNotEmpty) return point;

  final String value = location.trim();
  if (value.isEmpty) return _absent;

  final int i = value.indexOf(',');
  if (i < 0) return value;

  final String tail = value.substring(i + 1).trim();
  return tail.isEmpty ? value : tail;
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

/// The closing line. A spent ticket gets a statement of fact instead of an
/// instruction to be somewhere.
String _advisory(BusPass pass) {
  if (pass.status == TicketStatus.expired) {
    return 'This journey is complete. Kept for your records.';
  }
  return 'Please be at the boarding point at least 30 minutes '
      'before departure.';
}

/// Calendar days the arrival lands past the departure, for callers that show
/// an overnight marker.
///
/// Prefers the ISO instants and falls back to the display dates. Returns 0
/// when neither parses — an unmarked arrival beats a wrong one.
int busArrivalDayOffset(BusPass pass) {
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

/// Journey length, e.g. "8h 15m", or empty when it cannot be computed.
///
/// The display times carry no date, so an overnight run computed from them
/// alone would come out negative; only the ISO instants are trustworthy.
String busDurationLabel(BusPass pass) {
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
