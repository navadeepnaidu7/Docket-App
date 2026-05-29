import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Data model ────────────────────────────────────────────────────────────────

enum TicketStatus { active, expired }

class MockTicket {
  const MockTicket({
    required this.id,
    required this.operator,
    required this.trainName,
    required this.fromCode,
    required this.fromName,
    required this.toCode,
    required this.toName,
    required this.departTime,
    required this.arriveTime,
    required this.date,
    required this.duration,
    required this.ticketClass,
    required this.coach,
    required this.seat,
    required this.berth,
    required this.passengerName,
    required this.pnr,
    required this.bookingId,
    required this.status,
    this.progressFraction = 0.45,
  });

  final String id;
  final String operator;
  final String trainName;
  final String fromCode;
  final String fromName;
  final String toCode;
  final String toName;
  final String departTime;
  final String arriveTime;
  final String date;
  final String duration;
  final String ticketClass;
  final String coach;
  final String seat;
  final String berth;
  final String passengerName;
  final String pnr;
  final String bookingId;
  final TicketStatus status;
  final double progressFraction;
}

final List<MockTicket> mockTickets = [
  const MockTicket(
    id: 'mock_t1',
    operator: 'IRCTC',
    trainName: '12427 Rajdhani Express',
    fromCode: 'NZM',
    fromName: 'H. Nizamuddin',
    toCode: 'NDLS',
    toName: 'New Delhi',
    departTime: '08:40',
    arriveTime: '13:10',
    date: '23 Mar 2024',
    duration: '4h 30m',
    ticketClass: 'AC 2 Tier',
    coach: 'B2',
    seat: '23',
    berth: 'Lower',
    passengerName: 'Navadeep Naidu',
    pnr: '2432587612',
    bookingId: 'E12345678',
    status: TicketStatus.active,
    progressFraction: 0.48,
  ),
  const MockTicket(
    id: 'mock_t3',
    operator: 'IRCTC',
    trainName: '22691 Rajdhani Express',
    fromCode: 'SBC',
    fromName: 'KSR Bengaluru',
    toCode: 'NDLS',
    toName: 'New Delhi',
    departTime: '20:00',
    arriveTime: '06:00',
    date: '02 Jun 2024',
    duration: '34h 00m',
    ticketClass: 'AC 1 Tier',
    coach: 'H1',
    seat: '04',
    berth: 'Lower',
    passengerName: 'Navadeep Naidu',
    pnr: '4109823761',
    bookingId: 'E23456789',
    status: TicketStatus.active,
    progressFraction: 0.12,
  ),
  const MockTicket(
    id: 'mock_t4',
    operator: 'IRCTC',
    trainName: '12163 Chennai Express',
    fromCode: 'NDLS',
    fromName: 'New Delhi',
    toCode: 'MAS',
    toName: 'Chennai Central',
    departTime: '22:30',
    arriveTime: '19:45',
    date: '15 Jun 2024',
    duration: '21h 15m',
    ticketClass: 'AC 2 Tier',
    coach: 'A2',
    seat: '12',
    berth: 'Side Upper',
    passengerName: 'Navadeep Naidu',
    pnr: '6637291048',
    bookingId: 'E34567890',
    status: TicketStatus.active,
    progressFraction: 0.0,
  ),
  const MockTicket(
    id: 'mock_t2',
    operator: 'IRCTC',
    trainName: '12951 Mumbai Rajdhani',
    fromCode: 'NDLS',
    fromName: 'New Delhi',
    toCode: 'BCT',
    toName: 'Mumbai Central',
    departTime: '16:55',
    arriveTime: '08:15',
    date: '10 Jan 2024',
    duration: '15h 20m',
    ticketClass: 'AC 3 Tier',
    coach: 'A1',
    seat: '45',
    berth: 'Upper',
    passengerName: 'Navadeep Naidu',
    pnr: '8821456730',
    bookingId: 'E98765432',
    status: TicketStatus.expired,
    progressFraction: 1.0,
  ),
  const MockTicket(
    id: 'mock_t5',
    operator: 'IRCTC',
    trainName: '12650 Karnataka Express',
    fromCode: 'SBC',
    fromName: 'KSR Bengaluru',
    toCode: 'NZM',
    toName: 'H. Nizamuddin',
    departTime: '19:45',
    arriveTime: '06:30',
    date: '14 Nov 2023',
    duration: '34h 45m',
    ticketClass: 'AC 3 Tier',
    coach: 'B4',
    seat: '32',
    berth: 'Middle',
    passengerName: 'Navadeep Naidu',
    pnr: '3312984756',
    bookingId: 'E87654321',
    status: TicketStatus.expired,
    progressFraction: 1.0,
  ),
  const MockTicket(
    id: 'mock_t6',
    operator: 'IRCTC',
    trainName: '12028 Shatabdi Express',
    fromCode: 'MAS',
    fromName: 'Chennai Central',
    toCode: 'SBC',
    toName: 'KSR Bengaluru',
    departTime: '06:00',
    arriveTime: '11:00',
    date: '03 Sep 2023',
    duration: '5h 00m',
    ticketClass: 'CC Chair Car',
    coach: 'C3',
    seat: '67',
    berth: 'Seat',
    passengerName: 'Navadeep Naidu',
    pnr: '9901234567',
    bookingId: 'E76543210',
    status: TicketStatus.expired,
    progressFraction: 1.0,
  ),
];

// ── Palette helpers ───────────────────────────────────────────────────────────

// Active: rich indigo-to-blue gradient (Apple Wallet blue)
const _kActiveTop = Color(0xFF1B3A6B);
const _kActiveBot = Color(0xFF0A1F3D);
const _kActiveAccent = Color(0xFF4A90D9);

// Expired: muted slate
const _kExpiredTop = Color(0xFF3A3A3C);
const _kExpiredBot = Color(0xFF1C1C1E);
const _kExpiredAccent = Color(0xFF8E8E93);

// ── Card ──────────────────────────────────────────────────────────────────────

class WalletTicketCard extends StatefulWidget {
  const WalletTicketCard({super.key, required this.ticket});
  final MockTicket ticket;

  @override
  State<WalletTicketCard> createState() => _WalletTicketCardState();
}

class _WalletTicketCardState extends State<WalletTicketCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.965).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _pressCtrl.forward();
  void _onTapUp(TapUpDetails _) => _pressCtrl.reverse();
  void _onTapCancel() => _pressCtrl.reverse();

  void _openDetail() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _TicketDetailSheet(ticket: widget.ticket),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    final bool isActive = t.status == TicketStatus.active;
    final Color topColor = isActive ? _kActiveTop : _kExpiredTop;
    final Color botColor = isActive ? _kActiveBot : _kExpiredBot;
    final Color accent = isActive ? _kActiveAccent : _kExpiredAccent;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: _openDetail,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: (isActive ? _kActiveTop : Colors.black)
                    .withValues(alpha: 0.45),
                blurRadius: 40,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // ── Gradient background ─────────────────────────────
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [topColor, botColor],
                      ),
                    ),
                  ),
                ),

                // ── Subtle radial glow top-right ────────────────────
                Positioned(
                  top: -60,
                  right: -40,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accent.withValues(alpha: 0.18),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Card content ────────────────────────────────────
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CardHeader(t: t, accent: accent, isActive: isActive),
                    _TearLine(cardColor: botColor),
                    _CardFooter(t: t),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Card header (main body above tear line) ───────────────────────────────────

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.t,
    required this.accent,
    required this.isActive,
  });
  final MockTicket t;
  final Color accent;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Operator row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.train_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.operator,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    t.trainName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _StatusPill(isActive: isActive, accent: accent),
            ],
          ),

          const SizedBox(height: 28),

          // Route — big station codes
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // From
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.fromCode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -2,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.departTime,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.fromName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),

              // Middle — duration + arrow
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white.withValues(alpha: 0.5),
                            size: 16,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t.duration,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // To
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    t.toCode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -2,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.arriveTime,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.toName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 22),

          // Progress bar (active only)
          if (isActive && t.progressFraction > 0) ...[
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Stack(
                      children: [
                        Container(
                          height: 3,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        FractionallySizedBox(
                          widthFactor: t.progressFraction.clamp(0.0, 1.0),
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(t.progressFraction * 100).round()}%',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // Date + class row + days badge
          Row(
            children: [
              _MetaChip(label: t.date),
              const SizedBox(width: 8),
              _MetaChip(label: t.ticketClass),
              const Spacer(),
              if (isActive) _DaysBadge(dateStr: t.date),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Card footer (below tear line) ────────────────────────────────────────────

class _CardFooter extends StatelessWidget {
  const _CardFooter({required this.t});
  final MockTicket t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
      child: Row(
        children: [
          // Passenger
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PASSENGER',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  t.passengerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          // Coach · Seat · Berth
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'SEAT',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${t.coach} · ${t.seat} · ${t.berth}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tear line ─────────────────────────────────────────────────────────────────

class _TearLine extends StatelessWidget {
  const _TearLine({required this.cardColor});
  final Color cardColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: CustomPaint(
        painter: _TearLinePainter(cardColor: cardColor),
        size: const Size(double.infinity, 20),
      ),
    );
  }
}

class _TearLinePainter extends CustomPainter {
  const _TearLinePainter({required this.cardColor});
  final Color cardColor;

  @override
  void paint(Canvas canvas, Size size) {
    final notchR = 10.0;
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final notchPaint = Paint()
      ..color = const Color(0xFFF5F1E9) // matches scaffold background
      ..style = PaintingStyle.fill;

    // Left notch
    canvas.drawCircle(Offset(0, size.height / 2), notchR, notchPaint);
    // Right notch
    canvas.drawCircle(
        Offset(size.width, size.height / 2), notchR, notchPaint);

    // Dashed line
    double x = notchR * 2;
    final y = size.height / 2;
    while (x < size.width - notchR * 2) {
      canvas.drawLine(Offset(x, y), Offset(x + 5, y), dashPaint);
      x += 10;
    }
  }

  @override
  bool shouldRepaint(covariant _TearLinePainter old) =>
      old.cardColor != cardColor;
}

// ── Days badge ────────────────────────────────────────────────────────────────

class _DaysBadge extends StatelessWidget {
  const _DaysBadge({required this.dateStr});
  final String dateStr;

  String _label() {
    try {
      // Parse "23 Mar 2024" format
      final parts = dateStr.split(' ');
      if (parts.length != 3) return '';
      const months = {
        'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
        'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
      };
      final d = DateTime(
        int.parse(parts[2]),
        months[parts[1]] ?? 1,
        int.parse(parts[0]),
      );
      final diff = d.difference(DateTime.now()).inDays;
      if (diff < 0) return '';
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Tomorrow';
      return 'In $diff days';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _label();
    if (label.isEmpty) return const SizedBox.shrink();
    final bool urgent = label == 'Today' || label == 'Tomorrow';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: urgent
            ? const Color(0xFFFF9F0A).withValues(alpha: 0.25)
            : Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: urgent
            ? Border.all(color: const Color(0xFFFF9F0A).withValues(alpha: 0.5), width: 0.5)
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: urgent ? const Color(0xFFFF9F0A) : Colors.white.withValues(alpha: 0.7),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

// ── Status pill ───────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isActive, required this.accent});
  final bool isActive;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF30D158) : _kExpiredAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isActive ? 'Confirmed' : 'Completed',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Meta chip ─────────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── Detail bottom sheet ───────────────────────────────────────────────────────

class _TicketDetailSheet extends StatelessWidget {
  const _TicketDetailSheet({required this.ticket});
  final MockTicket ticket;

  @override
  Widget build(BuildContext context) {
    final t = ticket;
    final bool isActive = t.status == TicketStatus.active;
    final Color topColor = isActive ? _kActiveTop : _kExpiredTop;
    final Color botColor = isActive ? _kActiveBot : _kExpiredBot;
    final Color accent = isActive ? _kActiveAccent : _kExpiredAccent;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.9],
      builder: (context, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F1E9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: EdgeInsets.zero,
          children: [
            // ── Drag handle ─────────────────────────────────────────
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 0),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),

            // ── Ticket card replica (header only) ───────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (isActive ? _kActiveTop : Colors.black)
                          .withValues(alpha: 0.35),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [topColor, botColor],
                          ),
                        ),
                      ),
                      Positioned(
                        top: -50,
                        right: -30,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                accent.withValues(alpha: 0.2),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      _CardHeader(t: t, accent: accent, isActive: isActive),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Details section ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel('Journey Details'),
                  const SizedBox(height: 12),
                  _DetailRow('Train', t.trainName),
                  _DetailRow('Date', t.date),
                  _DetailRow('Duration', t.duration),
                  _DetailRow('Class', t.ticketClass),

                  const SizedBox(height: 24),
                  _SectionLabel('Seat'),
                  const SizedBox(height: 12),
                  _DetailRow('Coach', t.coach),
                  _DetailRow('Seat No.', t.seat),
                  _DetailRow('Berth', t.berth),

                  const SizedBox(height: 24),
                  _SectionLabel('Passenger'),
                  const SizedBox(height: 12),
                  _DetailRow('Name', t.passengerName),
                  _DetailRow('PNR', t.pnr),
                  _DetailRow('Booking ID', t.bookingId),

                  const SizedBox(height: 28),

                  // ── QR code block ─────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.qr_code_2_rounded,
                              size: 120, color: Colors.black),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          t.pnr,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: Color(0xFF0B1B34),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'PNR Number',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: Colors.black.withValues(alpha: 0.4),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.black.withValues(alpha: 0.07),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF0B1B34),
                fontWeight: FontWeight.w400,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF0B1B34),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
