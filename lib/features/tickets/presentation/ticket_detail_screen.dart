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
    final Color border =
        scheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.06);
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
                  const SizedBox(height: 20),
                  _SegmentedTabs(
                    index: _tab,
                    onChanged: (int i) {
                      HapticService.select();
                      setState(() => _tab = i);
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      final Animation<Offset> slide = Tween<Offset>(
                        begin: const Offset(0, 0.04),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: slide,
                          child: child,
                        ),
                      );
                    },
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

// ── Segmented control ─────────────────────────────────────────────────────────

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
    final Color selected =
        isDark ? AppTheme.elevated(Brightness.dark) : Colors.white;
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
        duration: const Duration(milliseconds: 200),
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
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? ink : ink.withValues(alpha: 0.55),
            letterSpacing: -0.15,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

// ── Details tab ───────────────────────────────────────────────────────────────

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
                valueColor: confirmed ? const Color(0xFF30D158) : muted,
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

// ── Live status tab ───────────────────────────────────────────────────────────
// Citymapper-style journey rail: coloured line spine, station rows with
// times, intermediate “ride N stops” chips, bottom status dock.

const Color _kLineBlue = Color(0xFF3B82F6);
const Color _kLineBlueDeep = Color(0xFF2563EB);
const Color _kStatusGreen = Color(0xFF30D158);
const Color _kRouteTrackLight = Color(0xFFE5E5EA);
const Color _kRouteTrackDark = Color(0xFF2C2C2E);

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
    final bool completed = t.status == TicketStatus.expired;
    final int remaining = halts
        .where((TicketHalt h) => h.state != HaltState.departed)
        .length;
    final String etaLabel = completed
        ? 'Arrived'
        : remaining <= 1
            ? 'Near destination'
            : '${remaining - 1} halt${remaining - 1 == 1 ? '' : 's'} left';

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[_kLineBlue, _kLineBlueDeep],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: _kLineBlue.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.train_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    t.trainTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.25,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    t.liveStatusLabel,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: completed ? muted : _kStatusGreen,
                    ),
                  ),
                ],
              ),
            ),
            if (!completed)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color:
                      _kStatusGreen.withValues(alpha: isDark ? 0.14 : 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: _kStatusGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Live',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kStatusGreen,
                      ),
                    ),
                  ],
                ),
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
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
              child: _JourneyRail(
                halts: halts,
                lineColor: _kLineBlue,
                ink: ink,
                muted: muted,
                isDark: isDark,
                completed: completed,
              ),
            ),
          ),
        if (halts.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          _JourneyDock(
            leftLabel: etaLabel,
            rightLabel: completed ? 'Complete' : t.liveStatusLabel,
            rightTone: completed ? muted : _kStatusGreen,
            isDark: isDark,
            cardSurface: cardSurface,
            border: border,
            ink: ink,
          ),
        ],
        const SizedBox(height: 14),
        Center(
          child: Text(
            'All times are in IST',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: muted.withValues(alpha: 0.75),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bottom dock inspired by transit “X mins left / status” pills.
class _JourneyDock extends StatelessWidget {
  const _JourneyDock({
    required this.leftLabel,
    required this.rightLabel,
    required this.rightTone,
    required this.isDark,
    required this.cardSurface,
    required this.border,
    required this.ink,
  });

  final String leftLabel;
  final String rightLabel;
  final Color rightTone;
  final bool isDark;
  final Color cardSurface;
  final Color border;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 0.5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Text(
                leftLabel,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.15,
                  color: ink,
                ),
              ),
            ),
          ),
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: rightTone.withValues(alpha: isDark ? 0.16 : 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                rightLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: rightTone,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Journey rail (Citymapper-like) ────────────────────────────────────────────

class _JourneyRail extends StatefulWidget {
  const _JourneyRail({
    required this.halts,
    required this.lineColor,
    required this.ink,
    required this.muted,
    required this.isDark,
    required this.completed,
  });

  final List<TicketHalt> halts;
  final Color lineColor;
  final Color ink;
  final Color muted;
  final bool isDark;
  final bool completed;

  @override
  State<_JourneyRail> createState() => _JourneyRailState();
}

class _JourneyRailState extends State<_JourneyRail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
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

  int _rideStopsAfter(int current) {
    final int n = widget.halts.length;
    if (current >= n - 1) return 0;
    return n - current - 1;
  }

  @override
  Widget build(BuildContext context) {
    final List<TicketHalt> haltList = widget.halts;
    final int n = haltList.length;
    if (n == 0) return const SizedBox.shrink();

    final int current = _currentIndex;
    final int rideStops = _rideStopsAfter(current);
    final bool showRideChip =
        !widget.completed && rideStops > 1 && current < n - 1;

    final Color track =
        widget.isDark ? _kRouteTrackDark : _kRouteTrackLight;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (BuildContext context, Widget? child) {
        return Column(
          children: <Widget>[
            for (int i = 0; i < n; i++) ...<Widget>[
              _StationTimelineRow(
                halt: haltList[i],
                index: i,
                total: n,
                isCurrent: i == current && !widget.completed,
                isPast: haltList[i].state == HaltState.departed &&
                    !(i == current && !widget.completed),
                lineColor: widget.lineColor,
                trackColor: track,
                ink: widget.ink,
                muted: widget.muted,
                pulse: _pulse.value,
                isFirst: i == 0,
                isLast: i == n - 1 && !(showRideChip && i == current),
              ),
              if (showRideChip && i == current)
                _RideSegmentRow(
                  stops: rideStops,
                  lineColor: widget.lineColor,
                  ink: widget.ink,
                  isDark: widget.isDark,
                ),
            ],
          ],
        );
      },
    );
  }
}

class _StationTimelineRow extends StatelessWidget {
  const _StationTimelineRow({
    required this.halt,
    required this.index,
    required this.total,
    required this.isCurrent,
    required this.isPast,
    required this.lineColor,
    required this.trackColor,
    required this.ink,
    required this.muted,
    required this.pulse,
    required this.isFirst,
    required this.isLast,
  });

  final TicketHalt halt;
  final int index;
  final int total;
  final bool isCurrent;
  final bool isPast;
  final Color lineColor;
  final Color trackColor;
  final Color ink;
  final Color muted;
  final double pulse;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final String subtitle = switch (halt.state) {
      HaltState.departed => [
          'Departed',
          if (halt.platform != null) halt.platform!,
        ].join(' · '),
      HaltState.arriving => [
          'Arriving now',
          if (halt.platform != null) halt.platform!,
        ].join(' · '),
      HaltState.upcoming => [
          if (halt.platform != null) halt.platform!,
          if (index == total - 1) 'Destination' else halt.dateLabel,
        ].where((String s) => s.isNotEmpty).join(' · '),
    };

    final Color nameColor =
        isPast && !isCurrent ? ink.withValues(alpha: 0.55) : ink;
    final Color subColor = isCurrent
        ? lineColor
        : isPast
            ? muted.withValues(alpha: 0.85)
            : muted;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 28,
            child: CustomPaint(
              painter: _LineSpinePainter(
                lineColor: lineColor,
                trackColor: trackColor,
                isPast: isPast || isCurrent,
                isCurrent: isCurrent,
                isFirst: isFirst,
                isLast: isLast,
                pulse: pulse,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: isFirst ? 0 : 10,
                bottom: isLast ? 8 : 10,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          halt.station,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: isCurrent ? 15.5 : 14.5,
                            fontWeight:
                                isCurrent ? FontWeight.w700 : FontWeight.w600,
                            letterSpacing: -0.2,
                            color: nameColor,
                            height: 1.2,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: subColor,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        halt.time,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: nameColor,
                          height: 1.15,
                        ),
                      ),
                      if (halt.actual != null &&
                          halt.actual != halt.time) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          halt.actual!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
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
            ),
          ),
        ],
      ),
    );
  }
}

/// Intermediate chip: “Ride N stops”.
class _RideSegmentRow extends StatelessWidget {
  const _RideSegmentRow({
    required this.stops,
    required this.lineColor,
    required this.ink,
    required this.isDark,
  });

  final int stops;
  final Color lineColor;
  final Color ink;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 28,
            child: Center(
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: lineColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE5E5EA),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.train_rounded, size: 15, color: lineColor),
                  const SizedBox(width: 7),
                  Text(
                    'Ride $stops stops',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                      color: ink,
                    ),
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

/// Vertical line spine with station node (badge / pulse / plain dot).
class _LineSpinePainter extends CustomPainter {
  _LineSpinePainter({
    required this.lineColor,
    required this.trackColor,
    required this.isPast,
    required this.isCurrent,
    required this.isFirst,
    required this.isLast,
    required this.pulse,
  });

  final Color lineColor;
  final Color trackColor;
  final bool isPast;
  final bool isCurrent;
  final bool isFirst;
  final bool isLast;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = isFirst ? 10.0 : 18.0;
    const double lineW = 4.0;

    final Paint pastPaint = Paint()
      ..color = lineColor
      ..strokeWidth = lineW
      ..strokeCap = StrokeCap.round;
    final Paint futurePaint = Paint()
      ..color = trackColor
      ..strokeWidth = lineW
      ..strokeCap = StrokeCap.round;

    if (!isFirst) {
      canvas.drawLine(
        Offset(cx, 0),
        Offset(cx, cy),
        isPast || isCurrent ? pastPaint : futurePaint,
      );
    }
    if (!isLast) {
      final bool segmentDone = isPast && !isCurrent;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx, size.height),
        segmentDone || isCurrent ? pastPaint : futurePaint,
      );
    }

    if (isFirst) {
      final Rect badge = Rect.fromCenter(
        center: Offset(cx, cy),
        width: 22,
        height: 22,
      );
      final RRect r = RRect.fromRectAndRadius(badge, const Radius.circular(7));
      canvas.drawRRect(r, Paint()..color = lineColor);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, cy), width: 8, height: 8),
          const Radius.circular(2),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.95),
      );
    } else if (isCurrent) {
      final double ring = 1.0 + 0.22 * pulse;
      final double ringA = 0.35 * (1.0 - pulse * 0.45);
      canvas.drawCircle(
        Offset(cx, cy),
        9 * ring,
        Paint()
          ..color = lineColor.withValues(alpha: ringA)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawCircle(Offset(cx, cy), 7, Paint()..color = lineColor);
      canvas.drawCircle(Offset(cx, cy), 3.2, Paint()..color = Colors.white);
    } else if (isPast) {
      canvas.drawCircle(Offset(cx, cy), 5.5, Paint()..color = lineColor);
      canvas.drawCircle(Offset(cx, cy), 2.4, Paint()..color = Colors.white);
    } else if (isLast) {
      canvas.drawCircle(
        Offset(cx, cy),
        6,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
      canvas.drawCircle(Offset(cx, cy), 2.5, Paint()..color = lineColor);
    } else {
      canvas.drawCircle(Offset(cx, cy), 4.5, Paint()..color = trackColor);
      canvas.drawCircle(
        Offset(cx, cy),
        4.5,
        Paint()
          ..color = lineColor.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineSpinePainter old) {
    return old.pulse != pulse ||
        old.isCurrent != isCurrent ||
        old.isPast != isPast ||
        old.lineColor != lineColor ||
        old.trackColor != trackColor ||
        old.isFirst != isFirst ||
        old.isLast != isLast;
  }
}

// ── Shared chrome ─────────────────────────────────────────────────────────────

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
