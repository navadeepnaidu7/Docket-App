import 'package:flutter/material.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/wallet/wallet_card_metrics.dart';
import '../../../../shared/widgets/pill_segmented.dart';
import '../../domain/flight_format.dart';
import '../../domain/flight_pass_models.dart';
import '../../domain/flight_trip.dart';
import '../../domain/pass_catalog.dart';
import '../../domain/pass_code.dart';
import '../pass_code_row.dart';
import '../pass_code_screen.dart';
import '../pass_info_card.dart';
import '../pass_detail_header.dart';
import '../pass_detail_tab_content.dart';
import '../share/pass_share_actions.dart';
import 'flight_ticket_code_screen.dart';
import 'flight_ticket_face.dart';
import 'flight_trip_card.dart';
import 'flight_updates_tab.dart';

/// Fullscreen boarding pass — the face, the code row, then Details | Updates.
///
/// Details is the bus and train screens' grouped rows, plus the aircraft.
/// Updates is [FlightUpdatesTab]: map, status sheet, aircraft, changes. Every
/// fact there is one the pass or the feed reported. Specs in
/// `docs/features/flight-pass.md` and `flight-pass-design.md`.
class FlightPassDetailScreen extends StatefulWidget {
  const FlightPassDetailScreen({
    super.key,
    required this.pass,
    this.clock = DateTime.now,
  });

  final FlightPass pass;
  final DateTime Function() clock;

  @override
  State<FlightPassDetailScreen> createState() => _FlightPassDetailScreenState();
}

class _FlightPassDetailScreenState extends State<FlightPassDetailScreen> {
  int _tab = 0; // 0 Details, 1 Updates

  void _openCodes(BuildContext context) {
    showPassCodeScreen(
      context,
      builder: (_) => FlightTicketCodeScreen(pass: widget.pass),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color ink = scheme.onSurface;
    final Color muted = AppTokens.secondaryLabel(scheme);
    final FlightPass pass = widget.pass;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            PassDetailHeader(
              item: FlightPassItem(pass),
              title: 'Boarding Pass',
              copyLabel: 'Copy PNR',
              copyValue: pass.bookingRef,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                physics: const BouncingScrollPhysics(),
                children: <Widget>[
                  AspectRatio(
                    aspectRatio: WalletCardMetrics.trainAspect,
                    child: WalletCardCanvas(
                      designSize: WalletCardMetrics.trainCanvas,
                      child: FlightTicketFace(
                        pass: pass,
                        useBrandColors: true,
                        clock: widget.clock,
                      ),
                    ),
                  ),
                  if (pass.passCode case final PassCode code) ...<Widget>[
                    const SizedBox(height: 18),
                    PassCodeRow(code: code, onTap: () => _openCodes(context)),
                  ],
                  const SizedBox(height: 22),
                  PillSegmented<int>(
                    value: _tab,
                    segments: const <(int, String)>[
                      (0, 'Details'),
                      (1, 'Updates'),
                    ],
                    onChanged: (int i) {
                      HapticService.select();
                      setState(() => _tab = i);
                    },
                  ),
                  const SizedBox(height: 16),
                  // Same motion as the train screen: the pill carries it, the
                  // content cross-fades while the height eases.
                  PassDetailTabContent(
                    child: _tab == 0
                        ? _DetailsTab(
                            key: const ValueKey<String>('details'),
                            pass: pass,
                            ink: ink,
                            muted: muted,
                            isDark: isDark,
                          )
                        : FlightUpdatesTab(
                            key: const ValueKey<String>('updates'),
                            pass: pass,
                            now: widget.clock(),
                          ),
                  ),
                  const SizedBox(height: 24),
                  PassShareActions(item: FlightPassItem(pass)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Details ───────────────────────────────────────────────────────────────────

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({
    super.key,
    required this.pass,
    required this.ink,
    required this.muted,
    required this.isDark,
  });

  final FlightPass pass;
  final Color ink;
  final Color muted;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final FlightPass p = pass;
    final int dayOffset = FlightFormat.arrivalDayOffset(p.departAt, p.arriveAt);
    final String arrival = FlightFormat.time(p.arriveAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (p.trip case final FlightTrip trip) ...<Widget>[
          FlightTripCard(trip: trip),
          const SizedBox(height: 12),
        ],
        PassInfoCard(
          title: 'Flight',
          ink: ink,
          muted: muted,
          isDark: isDark,
          rows: <(String, String)>[
            ('Airline', p.airline),
            ('Flight', p.flightNumber),
            ('Date', FlightFormat.date(p.departAt)),
            ('Duration', FlightFormat.duration(p.departAt, p.arriveAt)),
            ('Cabin', p.cabin),
          ],
        ),
        if ((p.live?.aircraft.trim().isNotEmpty ?? false) ||
            (p.live?.registration.trim().isNotEmpty ?? false)) ...<Widget>[
          const SizedBox(height: 12),
          FlightAircraftCard(pass: p, detailed: true),
        ],
        const SizedBox(height: 12),
        PassInfoCard(
          title: 'Departure',
          ink: ink,
          muted: muted,
          isDark: isDark,
          rows: <(String, String)>[
            ('Airport', _airportLine(p.origin)),
            ('Scheduled', FlightFormat.time(p.departAt)),
            ('Terminal', p.resolvedDepartTerminal),
            ('Gate', p.resolvedGate),
            ('Boarding', FlightFormat.time(p.boardingAt)),
          ],
        ),
        const SizedBox(height: 12),
        PassInfoCard(
          title: 'Arrival',
          ink: ink,
          muted: muted,
          isDark: isDark,
          rows: <(String, String)>[
            ('Airport', _airportLine(p.destination)),
            (
              'Scheduled',
              dayOffset > 0 && arrival.isNotEmpty
                  ? '$arrival  (+$dayOffset day${dayOffset == 1 ? '' : 's'})'
                  : arrival,
            ),
            ('Terminal', p.resolvedArriveTerminal),
            ('Baggage belt', p.live?.baggageBelt ?? ''),
          ],
        ),
        if (p.passengers.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          PassInfoCard(
            title: p.passengers.length == 1 ? 'Passenger' : 'Passengers',
            ink: ink,
            muted: muted,
            isDark: isDark,
            labelWidth: 150,
            rows: <(String, String)>[
              for (final FlightPassenger x in p.passengers)
                (x.name, x.seat.isEmpty ? '—' : 'Seat ${x.seat}'),
            ],
          ),
        ],
        const SizedBox(height: 12),
        PassInfoCard(
          title: 'Booking',
          ink: ink,
          muted: muted,
          isDark: isDark,
          rows: <(String, String)>[
            ('PNR', p.bookingRef),
            ('Group', p.boardingGroup),
            ('Sequence', p.sequence),
          ],
        ),
      ],
    );
  }

  static String _airportLine(FlightAirport a) {
    final String name = a.airport.trim().isNotEmpty ? a.airport.trim() : a.city;
    return name.trim().isEmpty ? a.code : '$name (${a.code})';
  }
}
