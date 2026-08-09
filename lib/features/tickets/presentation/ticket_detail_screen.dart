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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  'Boarding code',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: 188,
                  height: 188,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: isDark
                        ? null
                        : Border.all(
                            color: Colors.black.withValues(alpha: 0.05),
                          ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: _kMint.withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    size: 148,
                    color: Color(0xFF0F1410),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  t.pnr,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.2,
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

    final Color cardSurface =
        isDark ? AppTheme.elevated(Brightness.dark) : Colors.white;
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
                  const SizedBox(height: 22),
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
                    duration: const Duration(milliseconds: 340),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder:
                        (Widget? current, List<Widget> previous) {
                      return Stack(
                        alignment: Alignment.topCenter,
                        children: <Widget>[
                          ...previous,
                          ?current,
                        ],
                      );
                    },
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      final Animation<Offset> slide = Tween<Offset>(
                        begin: const Offset(0, 0.035),
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
                            isDark: isDark,
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

// ── Palette ───────────────────────────────────────────────────────────────────

const Color _kMint = Color(0xFF1FBF75);
const Color _kMintSoft = Color(0xFFD8F5E6);
const Color _kCharcoal = Color(0xFF0F1410);

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
        : const Color(0xFFEEF1EE);
    final Color selected =
        isDark ? AppTheme.elevated(Brightness.dark) : Colors.white;
    final Color ink = Theme.of(context).colorScheme.onSurface;

    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(14),
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
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? ink : ink.withValues(alpha: 0.48),
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
                valueColor: confirmed ? _kMint : muted,
                trailing: confirmed
                    ? const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: _kMint,
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

// ── Live status ───────────────────────────────────────────────────────────────
// Clean journey board: mint progress, charcoal stations, soft paper card.

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
    final int remainingStops = halts
        .where((TicketHalt h) => h.state != HaltState.departed)
        .length;
    final String etaLeft = completed
        ? 'Journey complete'
        : remainingStops == 0
            ? 'All stops completed'
            : remainingStops <= 1
                ? 'Final stop ahead'
                : '${remainingStops - 1} halt${remainingStops - 1 == 1 ? '' : 's'} remaining';

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Dark journey summary card (left-panel vibe from reference)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? <Color>[
                      const Color(0xFF1A1F1B),
                      const Color(0xFF0F1410),
                    ]
                  : <Color>[
                      const Color(0xFF152018),
                      const Color(0xFF0C120E),
                    ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _kMint.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _kMint.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      t.trainNumber,
                      style: GoogleFonts.inter(
                        color: _kMint,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.trainName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.15,
                      ),
                    ),
                  ),
                  if (!completed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _kMint.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: _kMint,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Live',
                            style: GoogleFonts.inter(
                              color: _kMint,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _DarkEndpoint(
                      time: t.departTime,
                      place: t.fromName,
                      alignEnd: false,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: <Widget>[
                        Text(
                          t.duration,
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 72,
                          height: 16,
                          child: CustomPaint(
                            painter: _MiniTrackPainter(
                              progress: t.progressFraction.clamp(0.08, 0.92),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _DarkEndpoint(
                      time: t.arriveTime,
                      place: t.toName,
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                t.liveStatusLabel,
                style: GoogleFonts.inter(
                  color: completed
                      ? Colors.white.withValues(alpha: 0.45)
                      : _kMint,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
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
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
              child: _JourneyTimeline(
                halts: halts,
                ink: ink,
                muted: muted,
                isDark: isDark,
                completed: completed,
              ),
            ),
          ),
        if (halts.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          _StatusDock(
            left: etaLeft,
            right: completed ? 'Complete' : t.liveStatusLabel,
            ink: ink,
            muted: muted,
            isDark: isDark,
            cardSurface: cardSurface,
            border: border,
            completed: completed,
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

class _DarkEndpoint extends StatelessWidget {
  const _DarkEndpoint({
    required this.time,
    required this.place,
    required this.alignEnd,
  });

  final String time;
  final String place;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          time,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          place,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _MiniTrackPainter extends CustomPainter {
  _MiniTrackPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final double cy = size.height / 2;
    final Paint base = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final Paint done = Paint()
      ..color = _kMint
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), base);
    canvas.drawLine(
      Offset(0, cy),
      Offset(size.width * progress, cy),
      done,
    );
    canvas.drawCircle(const Offset(0, 0) + Offset(0, cy), 3, done);
    canvas.drawCircle(
      Offset(size.width * progress, cy),
      4.5,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(size.width * progress, cy),
      3,
      Paint()..color = _kMint,
    );
    canvas.drawCircle(
      Offset(size.width, cy),
      3,
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(covariant _MiniTrackPainter old) =>
      old.progress != progress;
}

class _StatusDock extends StatelessWidget {
  const _StatusDock({
    required this.left,
    required this.right,
    required this.ink,
    required this.muted,
    required this.isDark,
    required this.cardSurface,
    required this.border,
    required this.completed,
  });

  final String left;
  final String right;
  final Color ink;
  final Color muted;
  final bool isDark;
  final Color cardSurface;
  final Color border;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 0.5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Text(
                left,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.15,
                  color: ink,
                ),
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(maxWidth: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: completed
                  ? muted.withValues(alpha: isDark ? 0.16 : 0.12)
                  : (isDark
                      ? _kMint.withValues(alpha: 0.18)
                      : _kMintSoft),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: completed ? muted : (isDark ? _kMint : _kCharcoal),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Station timeline ──────────────────────────────────────────────────────────

class _JourneyTimeline extends StatefulWidget {
  const _JourneyTimeline({
    required this.halts,
    required this.ink,
    required this.muted,
    required this.isDark,
    required this.completed,
  });

  final List<TicketHalt> halts;
  final Color ink;
  final Color muted;
  final bool isDark;
  final bool completed;

  @override
  State<_JourneyTimeline> createState() => _JourneyTimelineState();
}

class _JourneyTimelineState extends State<_JourneyTimeline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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
    final List<TicketHalt> list = widget.halts;
    final int n = list.length;
    if (n == 0) return const SizedBox.shrink();

    final int current = _currentIndex;
    final int rideStops =
        current < n - 1 ? n - current - 1 : 0;
    final bool showRide =
        !widget.completed && rideStops > 1 && current < n - 1;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (BuildContext context, Widget? child) {
        return Column(
          children: <Widget>[
            for (int i = 0; i < n; i++) ...<Widget>[
              _HaltRow(
                halt: list[i],
                index: i,
                total: n,
                isCurrent: i == current && !widget.completed,
                isPast: list[i].state == HaltState.departed &&
                    !(i == current && !widget.completed),
                ink: widget.ink,
                muted: widget.muted,
                isDark: widget.isDark,
                pulse: _pulse.value,
                isFirst: i == 0,
                isLast: i == n - 1 && !(showRide && i == current),
              ),
              if (showRide && i == current)
                _RideChip(
                  stops: rideStops,
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

class _HaltRow extends StatelessWidget {
  const _HaltRow({
    required this.halt,
    required this.index,
    required this.total,
    required this.isCurrent,
    required this.isPast,
    required this.ink,
    required this.muted,
    required this.isDark,
    required this.pulse,
    required this.isFirst,
    required this.isLast,
  });

  final TicketHalt halt;
  final int index;
  final int total;
  final bool isCurrent;
  final bool isPast;
  final Color ink;
  final Color muted;
  final bool isDark;
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
        isPast && !isCurrent ? ink.withValues(alpha: 0.45) : ink;
    final Color subColor = isCurrent
        ? _kMint
        : isPast
            ? muted.withValues(alpha: 0.8)
            : muted;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 24,
            child: CustomPaint(
              painter: _MintSpinePainter(
                isPast: isPast || isCurrent,
                isCurrent: isCurrent,
                isFirst: isFirst,
                isLast: isLast,
                pulse: pulse,
                isDark: isDark,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: isFirst ? 0 : 11,
                bottom: isLast ? 6 : 11,
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
                            fontSize: isCurrent ? 15 : 14,
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
                              fontSize: 12,
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
                          fontWeight: FontWeight.w700,
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
                            fontWeight: FontWeight.w700,
                            color: _kMint,
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

class _RideChip extends StatelessWidget {
  const _RideChip({
    required this.stops,
    required this.ink,
    required this.isDark,
  });

  final int stops;
  final Color ink;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 24,
            child: Center(
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: _kMint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? _kMint.withValues(alpha: 0.12)
                    : _kMintSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.train_rounded, size: 15, color: _kMint),
                  const SizedBox(width: 7),
                  Text(
                    'Ride $stops stops',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                      color: isDark ? Colors.white : _kCharcoal,
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

class _MintSpinePainter extends CustomPainter {
  _MintSpinePainter({
    required this.isPast,
    required this.isCurrent,
    required this.isFirst,
    required this.isLast,
    required this.pulse,
    required this.isDark,
  });

  final bool isPast;
  final bool isCurrent;
  final bool isFirst;
  final bool isLast;
  final double pulse;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = isFirst ? 8.0 : 16.0;
    final Color track =
        isDark ? const Color(0xFF3A3F3B) : const Color(0xFFDCE3DC);

    final Paint active = Paint()
      ..color = _kMint
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final Paint idle = Paint()
      ..color = track
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    if (!isFirst) {
      canvas.drawLine(
        Offset(cx, 0),
        Offset(cx, cy),
        isPast || isCurrent ? active : idle,
      );
    }
    if (!isLast) {
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx, size.height),
        (isPast && !isCurrent) || isCurrent ? active : idle,
      );
    }

    if (isFirst) {
      canvas.drawCircle(Offset(cx, cy), 6, Paint()..color = _kMint);
      canvas.drawCircle(Offset(cx, cy), 2.5, Paint()..color = Colors.white);
    } else if (isCurrent) {
      final double ring = 1.0 + 0.2 * pulse;
      canvas.drawCircle(
        Offset(cx, cy),
        9 * ring,
        Paint()
          ..color = _kMint.withValues(alpha: 0.28 * (1 - pulse * 0.4))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawCircle(Offset(cx, cy), 7, Paint()..color = _kMint);
      canvas.drawCircle(Offset(cx, cy), 3, Paint()..color = Colors.white);
    } else if (isPast) {
      canvas.drawCircle(Offset(cx, cy), 5, Paint()..color = _kMint);
      canvas.drawCircle(Offset(cx, cy), 2, Paint()..color = Colors.white);
    } else if (isLast) {
      canvas.drawCircle(
        Offset(cx, cy),
        6,
        Paint()
          ..color = _kMint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
      canvas.drawCircle(Offset(cx, cy), 2.4, Paint()..color = _kMint);
    } else {
      canvas.drawCircle(Offset(cx, cy), 4.2, Paint()..color = track);
      canvas.drawCircle(
        Offset(cx, cy),
        4.2,
        Paint()
          ..color = _kMint.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MintSpinePainter old) {
    return old.pulse != pulse ||
        old.isCurrent != isCurrent ||
        old.isPast != isPast ||
        old.isFirst != isFirst ||
        old.isLast != isLast ||
        old.isDark != isDark;
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
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
