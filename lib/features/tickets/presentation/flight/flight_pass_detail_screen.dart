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
import '../pass_code_view.dart';
import '../pass_info_card.dart';
import '../pass_remove_flow.dart';
import '../pass_typography.dart';
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
    HapticService.tap();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => FlightTicketCodeScreen(pass: widget.pass),
      ),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      'Boarding Pass',
                      textAlign: TextAlign.center,
                      style: PassType.screenTitle(ink),
                    ),
                  ),
                  PassOverflowButton(
                    item: FlightPassItem(pass),
                    copyLabel: 'Copy PNR',
                    copyValue: pass.bookingRef,
                  ),
                ],
              ),
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
                    _CodeRow(
                      code: code,
                      ink: ink,
                      muted: muted,
                      isDark: isDark,
                      onTap: () => _openCodes(context),
                    ),
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
                  AnimatedSize(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      reverseDuration: const Duration(milliseconds: 120),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      layoutBuilder: (Widget? current, List<Widget> previous) {
                        return Stack(
                          alignment: Alignment.topCenter,
                          children: <Widget>[...previous, ?current],
                        );
                      },
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

/// The ticket's code on a white tile, opening it fullscreen — the movie
/// face's code row, set on a card because it sits under the face rather than
/// on it.
class _CodeRow extends StatelessWidget {
  const _CodeRow({
    required this.code,
    required this.ink,
    required this.muted,
    required this.isDark,
    required this.onTap,
  });

  final PassCode code;
  final Color ink;
  final Color muted;
  final bool isDark;
  final VoidCallback onTap;

  /// Side of the white tile. Linear symbols get the same footprint so the row
  /// keeps its height whatever the ticket carries.
  static const double _tile = 88;

  @override
  Widget build(BuildContext context) {
    final Color surface = isDark
        ? AppTheme.elevated(Brightness.dark)
        : Colors.white;
    final Color border = ink.withValues(alpha: isDark ? 0.08 : 0.06);
    final bool isQr = code.format == PassCodeFormat.qr;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                Container(
                  width: _tile,
                  height: _tile,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Center(
                    child: PassCodeView(code: code, width: _tile - 16),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        isQr ? 'QR code' : 'Barcode',
                        style: PassType.sectionTitle(ink),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to open full screen for scanning',
                        style: PassType.caption(muted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: muted, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
