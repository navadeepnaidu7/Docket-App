import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/haptics/haptic_service.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/ticket_models.dart';
import 'train/train_ticket_face.dart';

/// Fullscreen train pass detail — ticket face, then Details | Live status.
class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({super.key, required this.ticket});

  final MockTicket ticket;

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  int _tab = 0; // 0 Details, 1 Live status

  void _openCodes(BuildContext context, MockTicket t) {
    HapticService.tap();
    _showQrSheet(context, t);
  }

  void _showQrSheet(BuildContext context, MockTicket t) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color ink = theme.colorScheme.onSurface;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ink.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Ticket QR',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: isDark
                        ? null
                        : Border.all(color: Colors.black.withValues(alpha: 0.06)),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    size: 140,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  t.pnr,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'PNR Number',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: ink.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final MockTicket t = widget.ticket;

    final Color cardSurface = isDark
        ? AppTheme.elevated(Brightness.dark)
        : Colors.white;
    final Color border = scheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.06);
    final Color ink = scheme.onSurface;
    final Color muted = AppTokens.secondaryLabel(scheme);

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
                      'E-Ticket',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                physics: const BouncingScrollPhysics(),
                children: <Widget>[
                  TrainTicketFace(
                    ticket: t,
                    density: TrainTicketDensity.detail,
                    useBrandColors: true,
                    onOpenCodes: () => _openCodes(context, t),
                  ),
                  const SizedBox(height: 18),
                  _SegmentedTabs(
                    index: _tab,
                    onChanged: (int i) {
                      HapticService.select();
                      setState(() => _tab = i);
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _tab == 0
                        ? _DetailsTab(
                            key: const ValueKey<String>('details'),
                            ticket: t,
                            cardSurface: cardSurface,
                            border: border,
                            ink: ink,
                            muted: muted,
                          )
                        : _LiveStatusTab(
                            key: const ValueKey<String>('live'),
                            ticket: t,
                            cardSurface: cardSurface,
                            border: border,
                            ink: ink,
                            muted: muted,
                            isDark: isDark,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ΓöÇΓöÇ Segmented control ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.index,
    required this.onChanged,
    required this.isDark,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final Color track = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE8E8ED);
    final Color selected = isDark
        ? AppTheme.elevated(Brightness.dark)
        : Colors.white;
    final Color ink = Theme.of(context).colorScheme.onSurface;

    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _SegButton(
              label: 'Details',
              selected: index == 0,
              selectedBg: selected,
              ink: ink,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _SegButton(
              label: 'Live status',
              selected: index == 1,
              selectedBg: selected,
              ink: ink,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegButton extends StatelessWidget {
  const _SegButton({
    required this.label,
    required this.selected,
    required this.selectedBg,
    required this.ink,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedBg;
  final Color ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? ink : ink.withValues(alpha: 0.55),
            letterSpacing: -0.15,
          ),
        ),
      ),
    );
  }
}

// ΓöÇΓöÇ Details tab ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({
    super.key,
    required this.ticket,
    required this.cardSurface,
    required this.border,
    required this.ink,
    required this.muted,
  });

  final MockTicket ticket;
  final Color cardSurface;
  final Color border;
  final Color ink;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final MockTicket t = ticket;
    final bool confirmed = t.status == TicketStatus.active;

    // Nested under the parent ListView (ticket face + tabs above).
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SurfaceCard(
          surface: cardSurface,
          border: border,
          child: Column(
            children: <Widget>[
              _InfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'Journey date',
                value: t.date,
                ink: ink,
                muted: muted,
              ),
              _InfoRow(
                icon: Icons.schedule_rounded,
                label: 'Boarding time',
                value: t.departTime,
                ink: ink,
                muted: muted,
              ),
              _InfoRow(
                icon: Icons.verified_outlined,
                label: 'Booking status',
                value: t.bookingStatus,
                ink: ink,
                muted: muted,
                valueColor: confirmed
                    ? const Color(0xFF30D158)
                    : muted,
                trailing: confirmed
                    ? const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: Color(0xFF30D158),
                      )
                    : null,
              ),
              _InfoRow(
                icon: Icons.confirmation_number_outlined,
                label: 'PNR',
                value: _formatPnr(t.pnr),
                ink: ink,
                muted: muted,
              ),
              _InfoRow(
                icon: Icons.list_alt_rounded,
                label: 'Chart status',
                value: t.chartStatus,
                ink: ink,
                muted: muted,
              ),
              _InfoRow(
                icon: Icons.timelapse_rounded,
                label: 'Travel time',
                value: t.duration,
                ink: ink,
                muted: muted,
              ),
              _InfoRow(
                icon: Icons.flag_outlined,
                label: 'Arrival',
                value: '${t.arrivalDate}, ${t.arriveTime}',
                ink: ink,
                muted: muted,
                showDivider: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SurfaceCard(
          surface: cardSurface,
          border: border,
          child: Column(
            children: <Widget>[
              if (t.passengerCount == 1) ...<Widget>[
                _InfoRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Passenger',
                  value: t.passengerName,
                  ink: ink,
                  muted: muted,
                ),
                _InfoRow(
                  icon: Icons.airline_seat_recline_normal_outlined,
                  label: 'Coach & Seat',
                  value: t.coachSeatLabel,
                  ink: ink,
                  muted: muted,
                ),
                _InfoRow(
                  icon: Icons.bed_outlined,
                  label: 'Berth type',
                  value: t.berth,
                  ink: ink,
                  muted: muted,
                  showDivider: false,
                ),
              ] else ...<Widget>[
                for (int i = 0; i < t.passengers.length; i++)
                  _PassengerInfoRow(
                    index: i + 1,
                    passenger: t.passengers[i],
                    ink: ink,
                    muted: muted,
                    showDivider: i < t.passengers.length - 1,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _formatPnr(String pnr) {
    if (pnr.length <= 4) return pnr;
    final StringBuffer b = StringBuffer();
    for (int i = 0; i < pnr.length; i++) {
      if (i > 0 && i % 4 == 0) b.write(' ');
      b.write(pnr[i]);
    }
    return b.toString();
  }
}

// ΓöÇΓöÇ Live status tab ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
//
// Transit-line rail: rounded vertical capsule + evenly spaced markers.
// 6px white dots ┬╖ 8px current with ring ┬╖ soft flat route colors.

const double _kRailWidth = 20;
/// Vertical space per station ΓÇö enough for name + subtitle without overflow.
const double _kStationPitch = 56;
const double _kDotSize = 6;
const double _kCurrentDotSize = 8;

// Soft flat route colors (no glossy gradients)
const Color _kRouteActive = Color(0xFF34C759);
const Color _kRouteTrackLight = Color(0xFFD8D8DE);
const Color _kRouteTrackDark = Color(0xFF3A3F4A);
const Color _kStatusGreen = Color(0xFF30D158);

class _LiveStatusTab extends StatelessWidget {
  const _LiveStatusTab({
    super.key,
    required this.ticket,
    required this.cardSurface,
    required this.border,
    required this.ink,
    required this.muted,
    required this.isDark,
  });

  final MockTicket ticket;
  final Color cardSurface;
  final Color border;
  final Color ink;
  final Color muted;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final MockTicket t = ticket;
    final List<TicketHalt> halts = t.halts;
    final TicketHalt? next = t.nextHalt;
    final bool completed = t.status == TicketStatus.expired;

    // Nested under the parent ListView (ticket face + tabs above).
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    t.trainTitle,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.liveStatusLabel,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: completed ? muted : _kStatusGreen,
                    ),
                  ),
                ],
              ),
            ),
            if (!completed)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: _kStatusGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Updated just now',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: muted,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (halts.isEmpty)
          _SurfaceCard(
            surface: cardSurface,
            border: border,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                completed
                    ? 'Journey completed. Live tracking is no longer available.'
                    : 'Live tracking will appear once the train departs.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: muted,
                  height: 1.4,
                ),
              ),
            ),
          )
        else
          _SurfaceCard(
            surface: cardSurface,
            border: border,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: _TransitRailMap(
                halts: halts,
                ink: ink,
                muted: muted,
                isDark: isDark,
              ),
            ),
          ),
        if (next != null && !completed) ...<Widget>[
          const SizedBox(height: 12),
          _SurfaceCard(
            surface: cardSurface,
            border: border,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Next halt',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          next.station,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${next.time} · ${next.dateLabel}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        next.state == HaltState.arriving ? 'Arriving' : 'Next',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _kStatusGreen,
                        ),
                      ),
                      if (next.platform != null)
                        Text(
                          next.platform!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: muted,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Center(
          child: Text(
            'All times are in IST',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: muted.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }
}

/// Vertical transit map: capsule rail + station labels (Citymapper-style).
class _TransitRailMap extends StatefulWidget {
  const _TransitRailMap({
    required this.halts,
    required this.ink,
    required this.muted,
    required this.isDark,
  });

  final List<TicketHalt> halts;
  final Color ink;
  final Color muted;
  final bool isDark;

  @override
  State<_TransitRailMap> createState() => _TransitRailMapState();
}

class _TransitRailMapState extends State<_TransitRailMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  int get _currentIndex {
    final List<TicketHalt> h = widget.halts;
    for (int i = 0; i < h.length; i++) {
      if (h[i].state == HaltState.arriving) return i;
    }
    int lastDeparted = -1;
    for (int i = 0; i < h.length; i++) {
      if (h[i].state == HaltState.departed) lastDeparted = i;
    }
    if (lastDeparted >= 0) return lastDeparted;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final List<TicketHalt> hals = widget.halts;
    final int n = hals.length;
    if (n == 0) return const SizedBox.shrink();

    final int current = _currentIndex;
    final double totalHeight = n * _kStationPitch;
    final Color track =
        widget.isDark ? _kRouteTrackDark : _kRouteTrackLight;
    final double progressEnd = (current + 0.5) * _kStationPitch;
    final bool completed =
        hals.every((TicketHalt h) => h.state == HaltState.departed);

    return SizedBox(
      height: totalHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Capsule rail
          SizedBox(
            width: _kRailWidth,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (BuildContext context, Widget? child) {
                return CustomPaint(
                  painter: _TransitCapsulePainter(
                    stationCount: n,
                    currentIndex: current,
                    pitch: _kStationPitch,
                    trackColor: track,
                    routeColor: _kRouteActive,
                    progressEnd: progressEnd,
                    pulse: _pulse.value,
                    completed: completed,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 14),
          // Labels ΓÇö fixed pitch, single-line safe layout
          Expanded(
            child: Column(
              children: <Widget>[
                for (int i = 0; i < n; i++)
                  SizedBox(
                    height: _kStationPitch,
                    child: _StationLabel(
                      halt: hals[i],
                      isCurrent: i == current && !completed,
                      ink: widget.ink,
                      muted: widget.muted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StationLabel extends StatelessWidget {
  const _StationLabel({
    required this.halt,
    required this.isCurrent,
    required this.ink,
    required this.muted,
  });

  final TicketHalt halt;
  final bool isCurrent;
  final Color ink;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final String status = switch (halt.state) {
      HaltState.departed => 'Departed',
      HaltState.arriving => 'Arriving',
      HaltState.upcoming => 'Upcoming',
    };
    final Color statusColor = switch (halt.state) {
      HaltState.departed => _kStatusGreen,
      HaltState.arriving => _kStatusGreen,
      HaltState.upcoming => muted,
    };

    // Reference-style: station + subtitle left, time right ΓÇö no vertical overflow.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  halt.station,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: -0.2,
                    color: ink,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    status,
                    if (halt.platform != null) halt.platform!,
                    halt.dateLabel,
                  ].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: statusColor,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                halt.time,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ink,
                  height: 1.1,
                ),
              ),
              if (halt.actual != null && halt.actual != halt.time) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  halt.actual!,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _kStatusGreen,
                    height: 1.1,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Paints the rounded vertical progress capsule + station dots.
class _TransitCapsulePainter extends CustomPainter {
  _TransitCapsulePainter({
    required this.stationCount,
    required this.currentIndex,
    required this.pitch,
    required this.trackColor,
    required this.routeColor,
    required this.progressEnd,
    required this.pulse,
    required this.completed,
  });

  final int stationCount;
  final int currentIndex;
  final double pitch;
  final Color trackColor;
  final Color routeColor;
  final double progressEnd;
  final double pulse;
  final bool completed;

  @override
  void paint(Canvas canvas, Size size) {
    // Inset slightly so pulse rings don't clip harshly at edges
    final RRect capsule = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(size.width / 2),
    );

    canvas.drawRRect(capsule, Paint()..color = trackColor);

    if (progressEnd > 0) {
      canvas.save();
      canvas.clipRRect(capsule);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, progressEnd.clamp(0.0, size.height)),
        Paint()..color = routeColor,
      );
      canvas.restore();
    }

    for (int i = 0; i < stationCount; i++) {
      final double cy = (i + 0.5) * pitch;
      final Offset c = Offset(size.width / 2, cy);
      final bool isCurrent = i == currentIndex && !completed;

      if (isCurrent) {
        final double ringScale = 1.0 + 0.18 * pulse;
        final double ringAlpha = 0.40 * (1.0 - pulse * 0.5);
        canvas.drawCircle(
          c,
          (_kCurrentDotSize / 2 + 3.5) * ringScale,
          Paint()
            ..color = Colors.white.withValues(alpha: ringAlpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        canvas.drawCircle(
          c,
          _kCurrentDotSize / 2 + 1.5,
          Paint()..color = Colors.white.withValues(alpha: 0.20 + 0.10 * pulse),
        );
        canvas.drawCircle(
          c,
          _kCurrentDotSize / 2,
          Paint()..color = Colors.white,
        );
      } else {
        canvas.drawCircle(
          c,
          _kDotSize / 2,
          Paint()..color = Colors.white,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TransitCapsulePainter old) {
    return old.pulse != pulse ||
        old.currentIndex != currentIndex ||
        old.stationCount != stationCount ||
        old.trackColor != trackColor ||
        old.progressEnd != progressEnd ||
        old.completed != completed;
  }
}

// ΓöÇΓöÇ Shared chrome ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.surface,
    required this.border,
    required this.child,
  });

  final Color surface;
  final Color border;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }
}

class _PassengerInfoRow extends StatelessWidget {
  const _PassengerInfoRow({
    required this.index,
    required this.passenger,
    required this.ink,
    required this.muted,
    this.showDivider = true,
  });

  final int index;
  final TicketPassenger passenger;
  final Color ink;
  final Color muted;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: <Widget>[
              Icon(Icons.person_outline_rounded, size: 18, color: muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Passenger $index',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      passenger.name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                passenger.seatLabel,
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: ink,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: Divider(
              height: 0.5,
              thickness: 0.5,
              color: muted.withValues(alpha: 0.18),
            ),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.ink,
    required this.muted,
    this.valueColor,
    this.trailing,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color ink;
  final Color muted;
  final Color? valueColor;
  final Widget? trailing;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: muted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: muted,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? ink,
                  ),
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: 4),
                trailing!,
              ],
            ],
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: Divider(
              height: 0.5,
              thickness: 0.5,
              color: muted.withValues(alpha: 0.18),
            ),
          ),
      ],
    );
  }
}


