import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/faded_divider.dart';
import '../../domain/flight_format.dart';
import '../../domain/flight_geo.dart';
import '../../domain/flight_pass_models.dart';
import '../pass_typography.dart';
import '../train/train_journey_status.dart';
import 'flight_journey_status.dart';
import 'flight_route_map.dart';
import 'flight_tones.dart';

/// The Updates tab: the route map, a status sheet that answers "when do I
/// leave and land", the aircraft, then every change as a list.
///
/// Every number is a fact from the pass or the live feed. With no feed the
/// sheet prints the timetable and says tracking has not started. Spec in
/// `docs/features/flight-pass-design.md`.
class FlightUpdatesTab extends StatelessWidget {
  const FlightUpdatesTab({super.key, required this.pass, required this.now});

  final FlightPass pass;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final bool showAircraft =
        (pass.live?.aircraft.trim().isNotEmpty ?? false) ||
        (pass.live?.registration.trim().isNotEmpty ?? false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (FlightRouteMap.canDraw(pass)) ...<Widget>[
          FlightRouteMap(pass: pass, now: now),
          const SizedBox(height: 12),
        ],
        _StatusSheet(pass: pass, now: now),
        if (showAircraft) ...<Widget>[
          const SizedBox(height: 12),
          FlightAircraftCard(pass: pass),
        ],
        const SizedBox(height: 12),
        _UpdatesList(pass: pass, now: now),
      ],
    );
  }
}

// ── Type ──────────────────────────────────────────────────────────────────────

/// The detail screen's Inter ramp ([PassType]) plus the two sizes this tab
/// adds: the headline and the big clock times.
abstract final class _Type {
  static const List<FontFeature> _tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static TextStyle headline(Color c) => GoogleFonts.inter(
    color: c,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
    fontFeatures: _tabular,
  );

  static TextStyle clock(Color c) => GoogleFonts.inter(
    color: c,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.0,
    height: 1.0,
    fontFeatures: _tabular,
  );

  static TextStyle struck(Color c) => GoogleFonts.inter(
    color: c,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.0,
    decoration: TextDecoration.lineThrough,
    decorationColor: c,
    fontFeatures: _tabular,
  );

  static TextStyle body(Color c) => GoogleFonts.inter(
    color: c,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.45,
  );

  static TextStyle chip(Color c) => GoogleFonts.inter(
    color: c,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.0,
    fontFeatures: _tabular,
  );
}

/// Palette shared by the cards on this tab.
class _Palette {
  _Palette(BuildContext context)
    : isDark = Theme.of(context).brightness == Brightness.dark,
      ink = Theme.of(context).colorScheme.onSurface,
      muted = AppTokens.secondaryLabel(Theme.of(context).colorScheme),
      faint = AppTokens.tertiaryLabel(Theme.of(context).colorScheme),
      tones = FlightTones(
        isDark: Theme.of(context).brightness == Brightness.dark,
      );

  final bool isDark;
  final Color ink;
  final Color muted;
  final Color faint;
  final FlightTones tones;

  Color get surface =>
      isDark ? AppTheme.elevated(Brightness.dark) : Colors.white;
  Color get fill => ink.withValues(alpha: isDark ? 0.08 : 0.05);
}

/// The card every block on this tab sits on: the detail screens' surface.
class _Card extends StatelessWidget {
  const _Card({required this.palette, required this.child, this.padding});

  final _Palette palette;
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: palette.ink.withValues(alpha: palette.isDark ? 0.08 : 0.06),
        ),
      ),
      child: child,
    );
  }
}

/// "Updates" with an optional quiet note on the right, aligned on baseline.
class _CardTitle extends StatelessWidget {
  const _CardTitle({
    required this.title,
    required this.palette,
    this.note = '',
  });

  final String title;
  final String note;
  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Expanded(child: Text(title, style: PassType.sectionTitle(palette.ink))),
        if (note.isNotEmpty) Text(note, style: PassType.caption(palette.muted)),
      ],
    );
  }
}

// ── Status sheet ──────────────────────────────────────────────────────────────

class _StatusSheet extends StatelessWidget {
  const _StatusSheet({required this.pass, required this.now});

  final FlightPass pass;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final _Palette pal = _Palette(context);
    final FlightJourneyStatus status = resolveFlightJourneyStatus(pass, now);
    final Color accent = pal.tones.of(status.tone) ?? pal.ink;
    final String situation = flightSituationLine(pass, now);

    return _Card(
      palette: pal,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text.rich(
            TextSpan(
              children: <TextSpan>[
                if (status.lead.isNotEmpty) TextSpan(text: '${status.lead} '),
                TextSpan(
                  text: status.emphasis,
                  style: TextStyle(color: accent),
                ),
              ],
            ),
            style: _Type.headline(pal.ink),
          ),
          if (situation.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(situation, style: _Type.body(pal.muted)),
          ],
          const SizedBox(height: 16),
          const FadedDivider.section(),
          const SizedBox(height: 16),
          _Endpoint.departure(pass: pass, now: now, palette: pal),
          const SizedBox(height: 14),
          _Between(pass: pass, now: now, palette: pal),
          const SizedBox(height: 14),
          _Endpoint.arrival(pass: pass, now: now, palette: pal),
        ],
      ),
    );
  }
}

/// One airport: its name, the time in status colour with the schedule struck
/// beside it when they differ, what that means, and the gate or belt.
class _Endpoint extends StatelessWidget {
  const _Endpoint.departure({
    required this.pass,
    required this.now,
    required this.palette,
  }) : arrival = false;

  const _Endpoint.arrival({
    required this.pass,
    required this.now,
    required this.palette,
  }) : arrival = true;

  final FlightPass pass;
  final DateTime now;
  final _Palette palette;
  final bool arrival;

  @override
  Widget build(BuildContext context) {
    final _Palette pal = palette;
    final FlightPass p = pass;
    final FlightLive? live = p.live;
    final FlightAirport airport = arrival ? p.destination : p.origin;
    final AirportTime? scheduled = arrival ? p.arriveAt : p.departAt;
    final AirportTime? actual = arrival
        ? live?.arriveActualAt
        : live?.departActualAt;
    final AirportTime? estimated = arrival
        ? live?.arriveEstimatedAt
        : live?.departEstimatedAt;
    final AirportTime? shown = actual ?? estimated ?? scheduled;
    final int? shift = shown == null || scheduled == null
        ? null
        : shown.instant.difference(scheduled.instant).inMinutes;
    final bool moved =
        shift != null && shift.abs() >= kFlightDelayThresholdMinutes;

    final Color timeColor = actual != null || (estimated != null && moved)
        ? (shift != null && shift >= kFlightDelayThresholdMinutes
              ? pal.tones.amber
              : (arrival && actual == null ? pal.tones.blue : pal.tones.green))
        : pal.ink;

    final _Chip? chip = arrival ? _arrivalChip(p) : _departureChip(p);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              arrival
                  ? Icons.flight_land_rounded
                  : Icons.flight_takeoff_rounded,
              size: 16,
              color: pal.muted,
            ),
            const SizedBox(width: 6),
            Text(airport.code, style: PassType.value(pal.ink)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                airport.airport.trim().isNotEmpty
                    ? airport.airport.trim()
                    : airport.displayCity,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PassType.label(pal.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      Text(
                        FlightFormat.time(shown).isEmpty
                            ? '--:--'
                            : FlightFormat.time(shown),
                        style: _Type.clock(timeColor),
                      ),
                      if (moved) ...<Widget>[
                        const SizedBox(width: 8),
                        Text(
                          FlightFormat.time(scheduled),
                          style: _Type.struck(pal.faint),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text.rich(
                    _meaning(actual, estimated, shift),
                    style: PassType.caption(pal.muted),
                  ),
                ],
              ),
            ),
            if (chip != null) ...<Widget>[const SizedBox(width: 12), chip],
          ],
        ),
      ],
    );
  }

  /// What the time means, the coloured words carrying the news.
  TextSpan _meaning(AirportTime? actual, AirportTime? estimated, int? shift) {
    final _Palette pal = palette;
    TextSpan tone(String s, Color c) => TextSpan(
      text: s,
      style: TextStyle(color: c, fontWeight: FontWeight.w600),
    );
    final int s = shift ?? 0;
    final bool late = s >= kFlightDelayThresholdMinutes;
    final bool early = s <= -kFlightDelayThresholdMinutes;

    if (actual != null) {
      final String verb = arrival ? 'Landed' : 'Took off';
      if (late) {
        return TextSpan(
          children: <TextSpan>[
            TextSpan(text: '$verb '),
            tone('${formatTrainMinutes(s)} late', pal.tones.amber),
          ],
        );
      }
      if (early) {
        return TextSpan(
          children: <TextSpan>[
            TextSpan(text: '$verb '),
            tone('${formatTrainMinutes(-s)} early', pal.tones.green),
          ],
        );
      }
      return TextSpan(
        children: <TextSpan>[
          TextSpan(text: '$verb '),
          tone('on time', pal.tones.green),
        ],
      );
    }
    if (estimated != null) {
      final String noun = arrival ? 'Expected' : 'Now leaving';
      if (late) {
        return TextSpan(
          children: <TextSpan>[
            tone(
              arrival
                  ? 'Expected ${formatTrainMinutes(s)} late'
                  : 'Delayed ${formatTrainMinutes(s)}',
              pal.tones.amber,
            ),
          ],
        );
      }
      if (early) {
        return TextSpan(
          children: <TextSpan>[
            tone('$noun ${formatTrainMinutes(-s)} early', pal.tones.green),
          ],
        );
      }
      return TextSpan(
        children: <TextSpan>[
          tone(arrival ? 'Expected on time' : 'On time', pal.tones.green),
        ],
      );
    }
    final AirportTime? scheduled = arrival ? pass.arriveAt : pass.departAt;
    if (scheduled != null && now.isBefore(scheduled.instant)) {
      final Duration left = scheduled.instant.difference(now);
      if (left.inHours < 24) {
        return TextSpan(
          text:
              '${arrival ? 'Arrives' : 'Departs'} in '
              '${formatTrainMinutes(left.inMinutes)}',
        );
      }
      return TextSpan(text: FlightFormat.day(scheduled));
    }
    return const TextSpan(text: 'Scheduled');
  }

  _Chip? _departureChip(FlightPass p) {
    final String gate = p.resolvedGate;
    final String terminal = p.resolvedDepartTerminal;
    final bool changed = p.updates.any(
      (FlightUpdate u) => u.type == FlightUpdateType.gateChange,
    );
    if (gate.isNotEmpty) {
      return _Chip(
        value: gate,
        label: terminal.isEmpty ? 'Gate' : 'Terminal $terminal',
        icon: Icons.north_east_rounded,
        palette: palette,
        highlight: changed,
      );
    }
    if (terminal.isNotEmpty) {
      return _Chip(value: 'T$terminal', label: 'Terminal', palette: palette);
    }
    return null;
  }

  _Chip? _arrivalChip(FlightPass p) {
    final String belt = p.live?.baggageBelt.trim() ?? '';
    final String terminal = p.resolvedArriveTerminal;
    if (belt.isNotEmpty) {
      return _Chip(
        value: belt,
        label: 'Baggage belt',
        icon: Icons.luggage_rounded,
        palette: palette,
      );
    }
    if (terminal.isNotEmpty) {
      return _Chip(value: 'T$terminal', label: 'Terminal', palette: palette);
    }
    return null;
  }
}

/// The gate or terminal, set in a tinted capsule with its label under it.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.value,
    required this.label,
    required this.palette,
    this.icon,
    this.highlight = false,
  });

  final String value;
  final String label;
  final IconData? icon;
  final _Palette palette;

  /// Changed since it was printed: amber, so it is the first thing seen.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    // Dark text on the bright dark-mode amber, white on the deep light-mode
    // one: both keep the chip's value readable at a glance.
    final Color fg = highlight
        ? (palette.isDark ? const Color(0xFF16181D) : Colors.white)
        : palette.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: highlight ? palette.tones.amber : palette.fill,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 3),
              ],
              Text(value, style: _Type.chip(fg)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: PassType.micro(palette.muted)),
      ],
    );
  }
}

/// Between the airports: how long, and how far. Flown and left once in the
/// air.
class _Between extends StatelessWidget {
  const _Between({
    required this.pass,
    required this.now,
    required this.palette,
  });

  final FlightPass pass;
  final DateTime now;
  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    final FlightLive? live = pass.live;
    final GeoPoint? a = pass.origin.resolvedLocation;
    final GeoPoint? b = pass.destination.resolvedLocation;
    final GeoPoint? at = live?.position;
    final AirportTime? off = live?.departActualAt;
    final bool airborne =
        (live?.state.hasDeparted ?? false) && !(live?.state.hasLanded ?? false);

    final String time = airborne && off != null
        ? '${FlightFormat.compact(now.difference(off.instant))} flown'
        : FlightFormat.duration(pass.departAt, pass.arriveAt);
    final String distance = airborne && at != null && b != null
        ? '${_thousands(greatCircleKm(at, b).round())} km left'
        : (a != null && b != null
              ? '${_thousands(greatCircleKm(a, b).round())} km'
              : '');

    final TextStyle style = PassType.caption(palette.muted);
    return Row(
      children: <Widget>[
        if (time.isNotEmpty) ...<Widget>[
          Icon(Icons.schedule_rounded, size: 14, color: palette.muted),
          const SizedBox(width: 6),
          Text(time, style: style),
        ],
        if (time.isNotEmpty && distance.isNotEmpty) const SizedBox(width: 16),
        if (distance.isNotEmpty) ...<Widget>[
          Icon(Icons.straighten_rounded, size: 14, color: palette.muted),
          const SizedBox(width: 6),
          Text(distance, style: style),
        ],
        const SizedBox(width: 12),
        const Expanded(child: FadedDivider.item()),
      ],
    );
  }
}

// ── Aircraft ──────────────────────────────────────────────────────────────────

/// The aircraft flying this pass: a photo of the airline's aircraft of that
/// type, its type and registration, and who took the photo.
///
/// [detailed] adds the reference rows the Details tab lists.
class FlightAircraftCard extends StatelessWidget {
  const FlightAircraftCard({
    super.key,
    required this.pass,
    this.detailed = false,
  });

  final FlightPass pass;
  final bool detailed;

  /// Replaces the network image in previews and tests, which have no network
  /// and no cache-manager plugin. Never set in the app.
  static Widget Function(String url)? debugPhotoBuilder;

  @override
  Widget build(BuildContext context) {
    final _Palette pal = _Palette(context);
    final FlightLive? live = pass.live;
    final String type = live?.aircraft.trim() ?? '';
    final String reg = live?.registration.trim() ?? '';
    final String photo = live?.aircraftPhotoUrl.trim() ?? '';
    final String credit = live?.aircraftPhotoCredit.trim() ?? '';
    final FlightUpdate? found = pass.updates
        .where((FlightUpdate u) => u.type == FlightUpdateType.aircraftFound)
        .firstOrNull;
    final String note = found == null
        ? ''
        : 'Found ${FlightFormat.time(AirportTime(found.at, pass.departAt?.offset ?? Duration.zero))}';

    return _Card(
      palette: pal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _CardTitle(
            title: detailed ? 'Aircraft' : 'Your aircraft',
            note: detailed ? '' : note,
            palette: pal,
          ),
          if (photo.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 2,
                child:
                    debugPhotoBuilder?.call(photo) ??
                    CachedNetworkImage(
                      imageUrl: photo,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 200),
                      placeholder: (_, _) => ColoredBox(color: pal.fill),
                      errorWidget: (_, _, _) => ColoredBox(color: pal.fill),
                    ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (!detailed) ...<Widget>[
            Text.rich(
              TextSpan(
                children: <TextSpan>[
                  TextSpan(text: type.isEmpty ? 'Aircraft' : type),
                  if (reg.isNotEmpty)
                    TextSpan(
                      text: '  $reg',
                      style: TextStyle(color: pal.tones.blue),
                    ),
                ],
              ),
              style: PassType.itemTitle(pal.ink),
            ),
            const SizedBox(height: 4),
            Text(pass.airline, style: PassType.caption(pal.muted)),
          ] else ...<Widget>[
            for (final (String, String) row in <(String, String)>[
              ('Type', type),
              ('Registration', reg),
              ('Operator', pass.airline),
            ])
              if (row.$2.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 120,
                        child: Text(row.$1, style: PassType.label(pal.muted)),
                      ),
                      Expanded(
                        child: Text(row.$2, style: PassType.value(pal.ink)),
                      ),
                    ],
                  ),
                ),
          ],
          if (photo.isNotEmpty && credit.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(credit, style: PassType.micro(pal.faint)),
          ],
        ],
      ),
    );
  }
}

// ── Updates list ──────────────────────────────────────────────────────────────

class _UpdatesList extends StatelessWidget {
  const _UpdatesList({required this.pass, required this.now});

  final FlightPass pass;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final _Palette pal = _Palette(context);
    final List<FlightUpdateLine> feed = flightUpdateFeed(pass);

    return _Card(
      palette: pal,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _CardTitle(
            title: 'Updates',
            note: feed.isEmpty ? '' : '${feed.length}',
            palette: pal,
          ),
          const SizedBox(height: 4),
          if (feed.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 10),
              child: Text(_emptyLine(pass, now), style: _Type.body(pal.muted)),
            )
          else
            for (int i = 0; i < feed.length; i++) ...<Widget>[
              if (i > 0) const FadedDivider.item(indent: _Row.textInset),
              _Row(line: feed[i], palette: pal),
            ],
        ],
      ),
    );
  }

  /// What an empty list means depends on when you are looking at it.
  static String _emptyLine(FlightPass pass, DateTime now) {
    final DateTime? departs = pass.departAt?.instant;
    if (departs != null && now.isBefore(departs)) {
      return 'Nothing has changed yet. Take-off, landing and anything the '
          'feed reports will appear here.';
    }
    return 'No updates were reported for this flight.';
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.line, required this.palette});

  final FlightUpdateLine line;
  final _Palette palette;

  static const double _icon = 32;
  static const double _gap = 12;

  /// Where the text starts, so item dividers line up under it.
  static const double textInset = _icon + _gap;

  @override
  Widget build(BuildContext context) {
    final Color tint = palette.tones.of(line.tone) ?? palette.muted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: _icon,
            height: _icon,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: palette.isDark ? 0.18 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_iconFor(line.kind), size: 17, color: tint),
          ),
          const SizedBox(width: _gap),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(line.title, style: PassType.itemTitle(palette.ink)),
                  if (line.detail.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(line.detail, style: PassType.caption(palette.muted)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              line.time,
              style: PassType.caption(palette.muted).copyWith(
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(FlightUpdateKind kind) => switch (kind) {
    FlightUpdateKind.found => Icons.radar_rounded,
    FlightUpdateKind.takeoff => Icons.flight_takeoff_rounded,
    FlightUpdateKind.cruise => Icons.flight_rounded,
    FlightUpdateKind.descent => Icons.south_east_rounded,
    FlightUpdateKind.landing => Icons.flight_land_rounded,
    FlightUpdateKind.gate => Icons.door_front_door_outlined,
    FlightUpdateKind.delay => Icons.schedule_rounded,
    FlightUpdateKind.boarding => Icons.airline_seat_recline_normal_rounded,
    FlightUpdateKind.bags => Icons.luggage_rounded,
    FlightUpdateKind.alert => Icons.error_outline_rounded,
  };
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
