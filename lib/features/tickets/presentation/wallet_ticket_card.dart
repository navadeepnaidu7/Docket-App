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
    trainName: '12427 RAJDHANI EXPRESS',
    fromCode: 'NZM',
    fromName: 'H. Nizamuddin',
    toCode: 'NDLS',
    toName: 'New Delhi',
    departTime: '08:40',
    arriveTime: '13:10',
    date: '23 Mar, 2024',
    duration: '4h 30m',
    ticketClass: 'AC 2 Tier',
    coach: 'B2',
    seat: '23',
    berth: 'LB',
    passengerName: 'Navadeep Naidu',
    pnr: '2432587612',
    bookingId: 'E12345678',
    status: TicketStatus.active,
    progressFraction: 0.48,
  ),
  const MockTicket(
    id: 'mock_t2',
    operator: 'IRCTC',
    trainName: '12951 MUMBAI RAJDHANI',
    fromCode: 'NDLS',
    fromName: 'New Delhi',
    toCode: 'BCT',
    toName: 'Mumbai Central',
    departTime: '16:55',
    arriveTime: '08:15',
    date: '10 Jan, 2024',
    duration: '15h 20m',
    ticketClass: 'AC 3 Tier',
    coach: 'A1',
    seat: '45',
    berth: 'UB',
    passengerName: 'Navadeep Naidu',
    pnr: '8821456730',
    bookingId: 'E98765432',
    status: TicketStatus.expired,
    progressFraction: 1.0,
  ),
];

// ── Compact card (same height pattern as passport card) ───────────────────────

class WalletTicketCard extends StatefulWidget {
  const WalletTicketCard({super.key, required this.ticket});
  final MockTicket ticket;

  @override
  State<WalletTicketCard> createState() => _WalletTicketCardState();
}

class _WalletTicketCardState extends State<WalletTicketCard> {
  bool _pressed = false;

  void _openDetail() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TicketDetailSheet(ticket: widget.ticket),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    final bool isActive = t.status == TicketStatus.active;
    final Color accent =
        isActive ? const Color(0xFF34C759) : const Color(0xFF8E8E93);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: _openDetail,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: 36,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Top accent bar ──────────────────────────────────
                Container(
                  height: 3,
                  color: isActive
                      ? const Color(0xFF34C759)
                      : const Color(0xFF3A3A4E),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Operator + status
                      Row(
                        children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFF252540),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(Icons.train_rounded,
                                color: Color(0xFF4C7CFF), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Text(t.operator,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6, height: 6,
                                  decoration: BoxDecoration(
                                      color: accent, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isActive ? 'ON TIME' : 'COMPLETED',
                                  style: TextStyle(
                                      color: accent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Route — big station codes
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.fromCode,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 34,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1)),
                              Text(t.fromName,
                                  style: const TextStyle(
                                      color: Color(0xFF8E8E93), fontSize: 11)),
                            ],
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: _DashedLine()),
                                    Container(
                                      width: 30, height: 30,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF252540),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.train_rounded,
                                          color: Colors.white54, size: 16),
                                    ),
                                    Expanded(child: _DashedLine()),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(t.duration,
                                    style: const TextStyle(
                                        color: Color(0xFF8E8E93),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(t.toCode,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 34,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1)),
                              Text(t.toName,
                                  style: const TextStyle(
                                      color: Color(0xFF8E8E93), fontSize: 11)),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Times + date
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _TimeBlock(time: t.departTime, date: t.date, align: CrossAxisAlignment.start),
                          Text(t.ticketClass,
                              style: const TextStyle(
                                  color: Color(0xFF8E8E93),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                          _TimeBlock(time: t.arriveTime, date: t.date, align: CrossAxisAlignment.end),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Progress bar
                      _ProgressTrack(
                          progress: t.progressFraction, isActive: isActive),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),

                // ── Perforated divider ──────────────────────────────
                _PerforatedDivider(),

                // ── Bottom strip: passenger + tap hint ─────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline_rounded,
                          color: Color(0xFF8E8E93), size: 18),
                      const SizedBox(width: 8),
                      Text(t.passengerName,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('${t.coach} · ${t.seat}',
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF252540),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(t.berth,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
    final Color accent =
        isActive ? const Color(0xFF34C759) : const Color(0xFF8E8E93);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),

            // Train name + status
            Row(
              children: [
                Expanded(
                  child: Text(t.trainName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isActive ? 'CONFIRMED' : 'COMPLETED',
                    style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Route
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.fromCode,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900)),
                      Text(t.fromName,
                          style: const TextStyle(
                              color: Color(0xFF8E8E93), fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(t.departTime,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                      Text(t.date,
                          style: const TextStyle(
                              color: Color(0xFF8E8E93), fontSize: 12)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: [
                      const Icon(Icons.arrow_forward_rounded,
                          color: Color(0xFF8E8E93), size: 20),
                      const SizedBox(height: 4),
                      Text(t.duration,
                          style: const TextStyle(
                              color: Color(0xFF8E8E93), fontSize: 11)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(t.toCode,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900)),
                      Text(t.toName,
                          style: const TextStyle(
                              color: Color(0xFF8E8E93), fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(t.arriveTime,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                      Text(t.date,
                          style: const TextStyle(
                              color: Color(0xFF8E8E93), fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Details grid
            _DetailGrid(items: [
              ('CLASS', t.ticketClass),
              ('COACH', t.coach),
              ('SEAT', t.seat),
              ('BERTH', t.berth),
              ('PASSENGER', t.passengerName),
              ('PNR', t.pnr),
            ]),

            const SizedBox(height: 24),

            // Progress
            _ProgressTrack(progress: t.progressFraction, isActive: isActive),

            const SizedBox(height: 24),

            // QR + booking ID
            _PerforatedDivider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.qr_code_2_rounded,
                      color: Colors.black, size: 64),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.bookingId,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5)),
                    const Text('Booking ID',
                        style: TextStyle(
                            color: Color(0xFF8E8E93), fontSize: 13)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.items});
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF252540),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.$1,
                style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8)),
            const SizedBox(height: 3),
            Text(item.$2,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      )).toList(),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({required this.time, required this.date, required this.align});
  final String time;
  final String date;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(time,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
        Text(date,
            style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 10)),
      ],
    );
  }
}

class _DashedLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashPainter(),
      child: const SizedBox(height: 1),
    );
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white24..strokeWidth = 1;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + 4, 0), p);
      x += 8;
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.progress, required this.isActive});
  final double progress;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF34C759) : const Color(0xFF8E8E93);
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final filled = (w * progress.clamp(0.0, 1.0));
      return SizedBox(
        height: 24,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(height: 3, decoration: BoxDecoration(
              color: Colors.white12, borderRadius: BorderRadius.circular(2))),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(width: filled, height: 3,
                  decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(2))),
            ),
            Positioned(
              left: (filled - 12).clamp(0, w - 24),
              child: Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Icon(Icons.train_rounded, size: 12, color: color),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _PerforatedDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Row(
        children: [
          Container(width: 10, height: 20,
              decoration: const BoxDecoration(
                color: Color(0xFFF2F2F7),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ))),
          Expanded(child: CustomPaint(
            painter: _DashPainter(),
            child: const SizedBox(height: 1),
          )),
          Container(width: 10, height: 20,
              decoration: const BoxDecoration(
                color: Color(0xFFF2F2F7),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                ))),
        ],
      ),
    );
  }
}
