import 'package:flutter/material.dart';

import '../../../core/haptics/haptic_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/wallet/wallet_card_metrics.dart';
import '../domain/ticket_models.dart';
import 'pass_typography.dart';
import 'train/halt_status.dart';
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
                Text('Boarding code', style: PassType.screenTitle(ink)),
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
                Text(t.pnr, style: PassType.code(ink)),
                const SizedBox(height: 4),
                Text(
                  'PNR Number',
                  style: PassType.label(ink.withValues(alpha: 0.5)),
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
                      style: PassType.screenTitle(ink),
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
                  // The face is authored at a fixed 366x630 canvas, so it needs
                  // the same scale-to-fit wrapper the wallet card uses. Dropped
                  // in raw it would render at its design size and overflow on
                  // anything narrower than 366dp.
                  AspectRatio(
                    aspectRatio: WalletCardMetrics.trainAspect,
                    child: WalletCardCanvas(
                      designSize: WalletCardMetrics.trainCanvas,
                      child: TrainTicketFace(
                        ticket: t,
                        density: TrainTicketDensity.detail,
                        useBrandColors: true,
                        onOpenCodes: () => _openCodes(context, t),
                      ),
                    ),
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
          style: PassType.value(
            selected ? ink : ink.withValues(alpha: 0.48),
          ).copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
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
                      style: PassType.pill(_kMint),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.trainName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PassType.value(
                        Colors.white.withValues(alpha: 0.92),
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
                          Text('Live', style: PassType.pill(_kMint)),
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
                          style: PassType.micro(
                            Colors.white.withValues(alpha: 0.7),
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
                style: PassType.value(
                  completed ? Colors.white.withValues(alpha: 0.45) : _kMint,
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
                style: PassType.label(muted).copyWith(height: 1.4),
              ),
            ),
          )
        else
          _SurfaceCard(
            surface: cardSurface,
            border: border,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: _JourneyTimeline(
                halts: halts,
                ink: ink,
                muted: muted,
                surface: cardSurface,
                isDark: isDark,
                completed: completed,
                runState: t.runState,
                delayMinutes: t.delayMinutes,
              ),
            ),
          ),
        if (halts.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          _JourneyDock(
            title: '${t.trainNumber} ${t.trainName}',
            route: '${t.fromName} → ${t.toName}',
            status: etaLeft,
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
            style: PassType.micro(muted.withValues(alpha: 0.75)),
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
          style: PassType.sectionTitle(Colors.white).copyWith(height: 1.0),
        ),
        const SizedBox(height: 4),
        Text(
          place,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: PassType.caption(Colors.white.withValues(alpha: 0.7)),
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

/// Anchors the timeline: which train this is, where it runs, and how far along.
class _JourneyDock extends StatelessWidget {
  const _JourneyDock({
    required this.title,
    required this.route,
    required this.status,
    required this.ink,
    required this.muted,
    required this.isDark,
    required this.cardSurface,
    required this.border,
    required this.completed,
  });

  final String title;
  final String route;
  final String status;
  final Color ink;
  final Color muted;
  final bool isDark;
  final Color cardSurface;
  final Color border;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(20),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PassType.itemTitle(ink),
                ),
                const SizedBox(height: 3),
                Text(
                  route,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PassType.caption(muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            constraints: const BoxConstraints(maxWidth: 132),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: completed
                  ? muted.withValues(alpha: isDark ? 0.16 : 0.12)
                  : (isDark ? _kMint.withValues(alpha: 0.18) : _kMintSoft),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: PassType.pill(
                completed ? muted : (isDark ? _kMint : _kCharcoal),
              ).copyWith(height: 1.2),
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
    required this.surface,
    required this.isDark,
    required this.completed,
    required this.runState,
    required this.delayMinutes,
  });

  final List<TicketHalt> halts;
  final Color ink;
  final Color muted;

  /// Fill inside each ring, so a node reads as a hole punched in the spine
  /// rather than a dot sitting on top of it.
  final Color surface;
  final bool isDark;
  final bool completed;
  final TrainRunState runState;
  final int? delayMinutes;

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

    // "Reached" drives the spine fill: the bar is solid up to where the train
    // actually is and faint beyond it, so progress is legible without reading
    // a single word.
    bool reached(int i) =>
        widget.completed ||
        list[i].state == HaltState.departed ||
        list[i].state == HaltState.arriving;

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
                reached: reached(i),
                // The segment below this node belongs to the next halt: it only
                // darkens once the train has got there.
                nextReached: i + 1 < n && reached(i + 1),
                status: resolveHaltStatus(
                  halt: list[i],
                  runState: widget.runState,
                  delayMinutes: widget.delayMinutes,
                  completed: widget.completed,
                ),
                ink: widget.ink,
                muted: widget.muted,
                surface: widget.surface,
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

/// Vertical space above a node, which the painter must match to centre the ring
/// on the time pill.
const double _kHaltTopGap = 14;

/// Half the time pill's height — the node's centre line.
const double _kHaltNodeInset = 10;

/// Width of the spine gutter. Sized to the ring so the bar sits centred.
const double _kSpineGutter = 22;

class _HaltRow extends StatelessWidget {
  const _HaltRow({
    required this.halt,
    required this.index,
    required this.total,
    required this.isCurrent,
    required this.isPast,
    required this.reached,
    required this.nextReached,
    required this.status,
    required this.ink,
    required this.muted,
    required this.surface,
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
  final bool reached;
  final bool nextReached;
  final HaltStatus? status;
  final Color ink;
  final Color muted;
  final Color surface;
  final bool isDark;
  final double pulse;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    // The sub-line carries what the pill does not: where to stand, and which
    // day this halt falls on.
    final String subtitle = <String>[
      if (halt.platform != null && halt.platform!.trim().isNotEmpty)
        halt.platform!.trim(),
      if (index == total - 1) 'Destination' else halt.dateLabel,
    ].where((String s) => s.isNotEmpty).join(' · ');

    // Passed stops recede so the eye lands on where the train is now.
    final Color nameColor =
        isPast && !isCurrent ? ink.withValues(alpha: 0.5) : ink;

    final bool revised = halt.actual != null && halt.actual != halt.time;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: _kSpineGutter,
            child: CustomPaint(
              painter: _SpinePainter(
                topFilled: reached,
                bottomFilled: nextReached,
                nodeFilled: reached,
                isCurrent: isCurrent,
                isFirst: isFirst,
                isLast: isLast,
                pulse: pulse,
                ink: ink,
                surface: surface,
                isDark: isDark,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: isFirst ? 0 : _kHaltTopGap,
                bottom: isLast ? 4 : _kHaltTopGap,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Both sides have to be able to give: a narrow phone plus a
                  // revised time plus a wide status label ("2 hr 5 min late")
                  // does not fit at natural width.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            _TimePill(
                              time: halt.time,
                              struckThrough: revised,
                              ink: nameColor,
                              isDark: isDark,
                            ),
                            if (revised) ...<Widget>[
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  halt.actual!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: PassType.pill(
                                    _toneColor(
                                      status?.tone ?? HaltStatusTone.neutral,
                                      isDark: isDark,
                                      muted: muted,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (status != null) ...<Widget>[
                        const SizedBox(width: 8),
                        Flexible(
                          child: _StatusPill(
                            status: status!,
                            isDark: isDark,
                            muted: muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    halt.station,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PassType.itemTitle(nameColor),
                  ),
                  if (subtitle.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 3),
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PassType.caption(muted),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 15,
                          color: muted.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Scheduled time, struck through when a revised time sits beside it.
class _TimePill extends StatelessWidget {
  const _TimePill({
    required this.time,
    required this.struckThrough,
    required this.ink,
    required this.isDark,
  });

  final String time;
  final bool struckThrough;
  final Color ink;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.09)
            : const Color(0xFFEDEDEF),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        time,
        style: PassType.pill(
          struckThrough ? ink.withValues(alpha: 0.55) : ink,
        ).copyWith(
          decoration: struckThrough ? TextDecoration.lineThrough : null,
          decorationColor: ink.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

Color _toneColor(
  HaltStatusTone tone, {
  required bool isDark,
  required Color muted,
}) {
  return switch (tone) {
    HaltStatusTone.neutral => muted,
    HaltStatusTone.live => _kMint,
    HaltStatusTone.positive => isDark ? _kMint : const Color(0xFF1B7F4B),
    HaltStatusTone.warning => isDark
        ? const Color(0xFFE9A23B)
        : const Color(0xFF9A5B00),
  };
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.status,
    required this.isDark,
    required this.muted,
  });

  final HaltStatus status;
  final bool isDark;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final Color fg = _toneColor(status.tone, isDark: isDark, muted: muted);
    final Color bg = switch (status.tone) {
      HaltStatusTone.neutral => isDark
          ? Colors.white.withValues(alpha: 0.07)
          : const Color(0xFFF0F0F2),
      HaltStatusTone.live ||
      HaltStatusTone.positive => isDark
          ? _kMint.withValues(alpha: 0.16)
          : const Color(0xFFDDF3E5),
      HaltStatusTone.warning => isDark
          ? const Color(0xFFE9A23B).withValues(alpha: 0.16)
          : const Color(0xFFFBEBD2),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
            child: Text(
              status.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PassType.pill(fg),
            ),
          ),
          const SizedBox(width: 1),
          Icon(Icons.chevron_right_rounded, size: 14, color: fg),
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
            width: _kSpineGutter,
            child: Center(
              child: Container(
                width: 5,
                decoration: BoxDecoration(
                  color: _kMint,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: isDark
                    ? _kMint.withValues(alpha: 0.12)
                    : _kMintSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.train_rounded, size: 14, color: _kMint),
                  const SizedBox(width: 6),
                  Text(
                    'Ride $stops stops',
                    style: PassType.pill(
                      isDark ? Colors.white : _kCharcoal,
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

/// The bar-and-ring spine down the left of the timeline.
///
/// Draws the bar first and punches the ring over it, so a node reads as a hole
/// in a continuous rail rather than a bead threaded onto it.
class _SpinePainter extends CustomPainter {
  _SpinePainter({
    required this.topFilled,
    required this.bottomFilled,
    required this.nodeFilled,
    required this.isCurrent,
    required this.isFirst,
    required this.isLast,
    required this.pulse,
    required this.ink,
    required this.surface,
    required this.isDark,
  });

  final bool topFilled;
  final bool bottomFilled;
  final bool nodeFilled;
  final bool isCurrent;
  final bool isFirst;
  final bool isLast;
  final double pulse;
  final Color ink;
  final Color surface;
  final bool isDark;

  static const double _bar = 5;
  static const double _ringRadius = 9;
  static const double _ringStroke = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = (isFirst ? 0.0 : _kHaltTopGap) + _kHaltNodeInset;

    final Color track = ink.withValues(alpha: isDark ? 0.16 : 0.11);

    void bar(double fromY, double toY, bool filled) {
      if (toY <= fromY) return;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(cx - _bar / 2, fromY, cx + _bar / 2, toY),
          const Radius.circular(_bar / 2),
        ),
        Paint()..color = filled ? ink : track,
      );
    }

    // Overlap the ring slightly so no hairline of background shows at the seam.
    const double overlap = 2;
    if (!isFirst) bar(0, cy - _ringRadius + overlap, topFilled);
    if (!isLast) bar(cy + _ringRadius - overlap, size.height, bottomFilled);

    // Halo on the stop the train is pulling into, so "now" is findable without
    // reading the pills.
    if (isCurrent) {
      canvas.drawCircle(
        Offset(cx, cy),
        _ringRadius + 4 + 3 * pulse,
        Paint()..color = _kMint.withValues(alpha: 0.22 * (1 - pulse)),
      );
    }

    final Color ringColor = isCurrent
        ? _kMint
        : nodeFilled
            ? ink
            : ink.withValues(alpha: 0.45);

    canvas.drawCircle(
      Offset(cx, cy),
      _ringRadius - _ringStroke / 2,
      Paint()..color = surface,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      _ringRadius - _ringStroke / 2,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = _ringStroke,
    );
  }

  @override
  bool shouldRepaint(covariant _SpinePainter old) {
    return old.pulse != pulse ||
        old.isCurrent != isCurrent ||
        old.topFilled != topFilled ||
        old.bottomFilled != bottomFilled ||
        old.nodeFilled != nodeFilled ||
        old.isFirst != isFirst ||
        old.isLast != isLast ||
        old.ink != ink ||
        old.surface != surface ||
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
                    Text('Passenger $index', style: PassType.caption(muted)),
                    const SizedBox(height: 2),
                    Text(passenger.name, style: PassType.itemTitle(ink)),
                  ],
                ),
              ),
              Text(
                passenger.seatLabel,
                textAlign: TextAlign.right,
                style: PassType.value(ink),
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
                child: Text(label, style: PassType.label(muted)),
              ),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: PassType.value(valueColor ?? ink),
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
