import 'package:flutter/material.dart';

import '../../../core/haptics/haptic_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/wallet/wallet_card_metrics.dart';
import '../../../shared/widgets/pill_segmented.dart';
import '../domain/pass_catalog.dart';
import '../domain/pnr_format.dart';
import '../domain/ticket_models.dart';
import '../domain/train_booking_state.dart';
import '../domain/pass_code.dart';
import 'pass_code_row.dart';
import 'pass_code_screen.dart';
import 'train/train_ticket_code_screen.dart';
import 'pass_info_card.dart';
import 'pass_detail_header.dart';
import 'pass_detail_tab_content.dart';
import 'pass_typography.dart';
import 'share/pass_share_actions.dart';
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
    showPassCodeScreen(
      context,
      builder: (_) => TrainTicketCodeScreen(ticket: t),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final MockTicket t = widget.ticket;

    final Color ink = scheme.onSurface;
    final Color muted = AppTokens.secondaryLabel(scheme);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            PassDetailHeader(
              item: TrainPassItem(t),
              title: 'E-Ticket',
              copyLabel: 'Copy PNR',
              copyValue: t.pnr,
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
                      ),
                    ),
                  ),
                  // The face draws no code, so this is the way to it. Omitted
                  // entirely when there is none: a button that opens an empty
                  // plate is worse than no button.
                  if (t.passCode case final PassCode code) ...<Widget>[
                    const SizedBox(height: 18),
                    PassCodeRow(
                      code: code,
                      onTap: () => _openCodes(context, t),
                    ),
                  ],
                  const SizedBox(height: 22),
                  PillSegmented<int>(
                    value: _tab,
                    segments: const <(int, String)>[
                      (0, 'Details'),
                      (1, 'Live status'),
                    ],
                    onChanged: (int i) {
                      HapticService.select();
                      setState(() => _tab = i);
                    },
                  ),
                  const SizedBox(height: 16),
                  // The pill's thumb carries the motion; the content only
                  // cross-fades in place while the card height eases to fit.
                  // The old slide-up made both tabs drift through each other.
                  PassDetailTabContent(
                    child: _tab == 0
                        ? _DetailsTab(
                            key: const ValueKey<String>('details'),
                            ticket: t,
                            ink: ink,
                            muted: muted,
                            isDark: isDark,
                          )
                        : _LiveStatusTab(
                            key: const ValueKey<String>('live'),
                            ticket: t,
                            ink: ink,
                            muted: muted,
                            isDark: isDark,
                          ),
                  ),
                  const SizedBox(height: 24),
                  // Below the tab content, so it is the last thing on either
                  // tab rather than something that moves when the tab changes.
                  PassShareActions(item: TrainPassItem(t)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const Color _kMint = Color(0xFF1FBF75);

// ── Details tab ───────────────────────────────────────────────────────────────

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({
    super.key,
    required this.ticket,
    required this.ink,
    required this.muted,
    required this.isDark,
  });

  final MockTicket ticket;
  final Color ink;
  final Color muted;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final MockTicket t = ticket;
    final bool onePassenger = t.passengerCount == 1;
    final TicketPassenger primary = t.primaryPassenger;
    final String bookingStatus = _bookingStatus(t.bookingStatus);

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PassInfoCard(
          title: 'Journey',
          ink: ink,
          muted: muted,
          isDark: isDark,
          rows: <(String, String)>[
            ('Date', t.date),
            ('Boarding', t.departTime),
            ('Arrival', _arrival(t)),
            ('Duration', t.duration),
          ],
        ),
        const SizedBox(height: 12),
        PassInfoCard(
          title: 'Booking',
          ink: ink,
          muted: muted,
          isDark: isDark,
          rows: <(String, String)>[
            ('Status', bookingStatus),
            ('PNR', PnrFormat.display(t.pnr)),
            ('Chart', t.chartStatus),
          ],
          valueColor: (String label, String value) => label == 'Status'
              ? _stateColor(TrainBookingState.classify(value))
              : null,
        ),
        if (t.passengers.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          // One passenger keeps the field grid shared with Journey and Booking;
          // several are listed by name, each with their berth beneath.
          PassInfoCard(
            title: onePassenger ? 'Passenger' : 'Passengers',
            ink: ink,
            muted: muted,
            isDark: isDark,
            stacked: !onePassenger,
            rows: onePassenger
                ? <(String, String)>[
                    ('Name', primary.name),
                    ('Status', primary.statusLabel),
                    ('Booked', primary.bookedLabel),
                    ('Coach', primary.coach),
                    ('Seat', primary.seat),
                    ('Berth', primary.berth),
                  ]
                : <(String, String)>[
                    for (final TicketPassenger passenger in t.passengers)
                      (passenger.name, _passengerLine(passenger)),
                  ],
            valueColor: (String label, String value) {
              if (onePassenger) {
                return label == 'Status'
                    ? _stateColor(primary.bookingState)
                    : null;
              }
              for (final TicketPassenger passenger in t.passengers) {
                if (passenger.name == label) {
                  return _stateColor(passenger.bookingState);
                }
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  /// "GNWL/14" reads as "GNWL 14"; any other status is shown as sent.
  static String _bookingStatus(String raw) {
    final String queue = trainQueueLabel(raw);
    return queue.isEmpty ? raw.trim() : queue;
  }

  /// One line per passenger: the queue position while waiting, the berth once
  /// allotted, both for RAC, which shares a berth before it is confirmed.
  static String _passengerLine(TicketPassenger p) {
    final String seat = p.seatLabel;
    final String booked = p.bookedLabel;
    final String now = switch (p.bookingState) {
      TrainBookingState.waitlisted ||
      TrainBookingState.cancelled => p.statusLabel,
      TrainBookingState.rac =>
        seat.isEmpty ? p.statusLabel : '${p.statusLabel} · $seat',
      TrainBookingState.confirmed ||
      TrainBookingState.unknown => seat.isEmpty ? p.statusLabel : seat,
    };
    return booked.isEmpty ? now : '$now · booked $booked';
  }

  /// Confirmed green, RAC amber, waitlisted and cancelled red. Unknown stays
  /// ink: no colour is better than a guessed one. Each tone is darkened on the
  /// light surface and lifted on the dark one to stay readable as text.
  Color? _stateColor(TrainBookingState state) => switch (state) {
    TrainBookingState.confirmed =>
      isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
    TrainBookingState.rac =>
      isDark ? const Color(0xFFFACC15) : const Color(0xFFA16207),
    TrainBookingState.waitlisted || TrainBookingState.cancelled =>
      isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
    TrainBookingState.unknown => null,
  };

  /// Time alone when arrival is the same day. The date is already on the
  /// journey row, so repeating it on every same-day ticket is noise.
  static String _arrival(MockTicket t) {
    final String time = t.arriveTime.trim();
    final String date = t.arrivalDate.trim();
    if (date.isEmpty || date == t.date.trim()) return time;
    if (time.isEmpty) return date;
    return '$date, $time';
  }
}

// ── Live status ───────────────────────────────────────────────────────────────
// One status line and the stops. The face above already names the train,
// the clocks, and the route, so none of that is repeated here.

class _LiveStatusTab extends StatelessWidget {
  const _LiveStatusTab({
    super.key,
    required this.ticket,
    required this.ink,
    required this.muted,
    required this.isDark,
  });

  final MockTicket ticket;
  final Color ink;
  final Color muted;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final MockTicket t = ticket;
    final List<TicketHalt> halts = t.halts;
    final bool completed =
        t.status == TicketStatus.expired || t.runState == TrainRunState.arrived;
    final String? headline = _headline(t, completed);
    final Color surface = isDark
        ? AppTheme.elevated(Brightness.dark)
        : Colors.white;
    final Color border = ink.withValues(alpha: isDark ? 0.08 : 0.06);

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: EdgeInsets.fromLTRB(16, 14, 16, halts.isEmpty ? 16 : 12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: halts.isEmpty
              ? Text(
                  completed
                      ? 'Journey complete'
                      : 'Tracking starts after departure',
                  style: PassType.label(muted),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (headline != null) ...<Widget>[
                      Text(
                        headline,
                        style: PassType.sectionTitle(
                          _headlineColor(t, completed),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _JourneyTimeline(
                      halts: halts,
                      ink: ink,
                      muted: muted,
                      surface: surface,
                      completed: completed,
                    ),
                    const SizedBox(height: 12),
                    Text('Times in IST', style: PassType.micro(muted)),
                  ],
                ),
        ),
      ],
    );
  }

  /// One line for the whole run. Per-stop lateness used to repeat this on
  /// every upcoming halt.
  static String? _headline(MockTicket t, bool completed) {
    final String label = t.liveStatusLabel.trim();
    if (label.isNotEmpty) return label;
    if (t.runState == TrainRunState.cancelled) return 'Cancelled';
    if (completed) return 'Journey complete';
    final int? delay = t.delayMinutes;
    if (delay != null && delay > 0) {
      return 'Running ${formatDelay(delay)} late';
    }
    if (t.runState == TrainRunState.onTime) return 'On time';
    return null;
  }

  Color _headlineColor(MockTicket t, bool completed) {
    if (completed) return muted;
    return switch (t.runState) {
      TrainRunState.delayed || TrainRunState.cancelled =>
        isDark ? const Color(0xFFE9A23B) : const Color(0xFF9A5B00),
      _ => ink,
    };
  }
}

// ── Station timeline ──────────────────────────────────────────────────────────

class _JourneyTimeline extends StatefulWidget {
  const _JourneyTimeline({
    required this.halts,
    required this.ink,
    required this.muted,
    required this.surface,
    required this.completed,
  });

  final List<TicketHalt> halts;
  final Color ink;
  final Color muted;

  /// Fill inside each node, so it reads as a hole in the rail.
  final Color surface;
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
    final bool multiDay =
        list
            .map((TicketHalt h) => h.dateLabel.trim())
            .where((String d) => d.isNotEmpty)
            .toSet()
            .length >
        1;

    // "Reached" drives the spine fill: the bar is solid up to where the train
    // actually is and faint beyond it, so progress is legible without reading
    // a single word.
    bool reached(int i) =>
        widget.completed ||
        list[i].state == HaltState.departed ||
        list[i].state == HaltState.arriving;

    bool showDate(int i) {
      if (!multiDay) return false;
      final String date = list[i].dateLabel.trim();
      if (date.isEmpty) return false;
      if (i == 0) return true;
      return date != list[i - 1].dateLabel.trim();
    }

    return AnimatedBuilder(
      animation: _pulse,
      builder: (BuildContext context, Widget? child) {
        return Column(
          children: <Widget>[
            for (int i = 0; i < n; i++)
              _HaltRow(
                halt: list[i],
                isCurrent: i == current && !widget.completed,
                isPast:
                    list[i].state == HaltState.departed &&
                    !(i == current && !widget.completed),
                reached: reached(i),
                // The segment below this node belongs to the next halt: it only
                // darkens once the train has got there.
                nextReached: i + 1 < n && reached(i + 1),
                showDate: showDate(i),
                ink: widget.ink,
                muted: widget.muted,
                surface: widget.surface,
                pulse: _pulse.value,
                isFirst: i == 0,
                isLast: i == n - 1,
              ),
          ],
        );
      },
    );
  }
}

/// Vertical space above a node. The painter uses the same gap so the dot
/// sits on the time line.
const double _kHaltTopGap = 12;

/// Centre of the time/station line, measured from the top of that line.
const double _kHaltNodeInset = 9;

/// Extra height above the time line when a day caption is shown.
const double _kDateBlock = 20;

/// Width of the spine gutter. Sized to the dot so the rail sits centred.
const double _kSpineGutter = 16;

class _HaltRow extends StatelessWidget {
  const _HaltRow({
    required this.halt,
    required this.isCurrent,
    required this.isPast,
    required this.reached,
    required this.nextReached,
    required this.showDate,
    required this.ink,
    required this.muted,
    required this.surface,
    required this.pulse,
    required this.isFirst,
    required this.isLast,
  });

  final TicketHalt halt;
  final bool isCurrent;
  final bool isPast;
  final bool reached;
  final bool nextReached;
  final bool showDate;
  final Color ink;
  final Color muted;
  final Color surface;
  final double pulse;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    // Passed stops recede so the eye lands on where the train is now.
    final Color nameColor = isPast && !isCurrent
        ? ink.withValues(alpha: 0.45)
        : ink;
    final String actual = halt.actual?.trim() ?? '';
    final String shownTime = actual.isNotEmpty && actual != halt.time.trim()
        ? actual
        : halt.time;
    final String platform = halt.platform?.trim() ?? '';
    // "Now" only when this halt is the one the train is actually at.
    // A not-yet-departed origin is still the current node on the rail.
    final bool here = isCurrent && halt.state == HaltState.arriving;

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
                showDate: showDate,
                pulse: pulse,
                ink: ink,
                surface: surface,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: isFirst ? 0 : _kHaltTopGap,
                bottom: isLast ? 2 : _kHaltTopGap,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (showDate)
                    SizedBox(
                      height: _kDateBlock,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          halt.dateLabel.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PassType.micro(muted),
                        ),
                      ),
                    ),
                  Row(
                    children: <Widget>[
                      SizedBox(
                        width: 58,
                        child: Text(
                          shownTime,
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                          style: PassType.value(nameColor).copyWith(
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          halt.station,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PassType.itemTitle(nameColor),
                        ),
                      ),
                      if (here) ...<Widget>[
                        const SizedBox(width: 8),
                        Text('Now', style: PassType.caption(_kMint)),
                      ],
                    ],
                  ),
                  if (here && platform.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 68, top: 2),
                      child: Text(platform, style: PassType.caption(muted)),
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

/// Thin rail with a dot per stop. The current stop is the only one that moves.
class _SpinePainter extends CustomPainter {
  _SpinePainter({
    required this.topFilled,
    required this.bottomFilled,
    required this.nodeFilled,
    required this.isCurrent,
    required this.isFirst,
    required this.isLast,
    required this.showDate,
    required this.pulse,
    required this.ink,
    required this.surface,
  });

  final bool topFilled;
  final bool bottomFilled;
  final bool nodeFilled;
  final bool isCurrent;
  final bool isFirst;
  final bool isLast;
  final bool showDate;
  final double pulse;
  final Color ink;
  final Color surface;

  static const double _bar = 2;
  static const double _dot = 3.5;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy =
        (isFirst ? 0.0 : _kHaltTopGap) +
        (showDate ? _kDateBlock : 0) +
        _kHaltNodeInset;
    final Color track = ink.withValues(alpha: 0.16);

    void bar(double fromY, double toY, bool filled) {
      if (toY <= fromY) return;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(cx - _bar / 2, fromY, cx + _bar / 2, toY),
          const Radius.circular(_bar / 2),
        ),
        Paint()..color = filled ? ink.withValues(alpha: 0.85) : track,
      );
    }

    if (!isFirst) bar(0, cy - _dot, topFilled);
    if (!isLast) bar(cy + _dot, size.height, bottomFilled);

    if (isCurrent) {
      canvas.drawCircle(
        Offset(cx, cy),
        _dot + 5 + 2 * pulse,
        Paint()..color = _kMint.withValues(alpha: 0.18 * (1 - pulse * 0.6)),
      );
      canvas.drawCircle(Offset(cx, cy), _dot, Paint()..color = _kMint);
      return;
    }

    if (nodeFilled) {
      canvas.drawCircle(Offset(cx, cy), _dot - 0.5, Paint()..color = ink);
      return;
    }

    canvas.drawCircle(Offset(cx, cy), _dot - 0.5, Paint()..color = surface);
    canvas.drawCircle(
      Offset(cx, cy),
      _dot - 0.5,
      Paint()
        ..color = ink.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
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
        old.showDate != showDate ||
        old.ink != ink ||
        old.surface != surface;
  }
}
