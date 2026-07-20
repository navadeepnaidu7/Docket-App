import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/haptics/haptic_service.dart';
import '../domain/ticket_models.dart';
import 'ticket_detail_screen.dart';

export '../domain/ticket_models.dart';

// ΓöÇΓöÇ Pass face palette ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

const Color _kExpiredTop = Color(0xFF3A3A3C);
const Color _kExpiredBot = Color(0xFF1C1C1E);

// ΓöÇΓöÇ Wallet card ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

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
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  /// Fullscreen dialog transition (modal rise) — keep as-is.
  void _openDetail() {
    HapticService.confirm();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => TicketDetailScreen(ticket: widget.ticket),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MockTicket t = widget.ticket;
    final bool isActive = t.status == TicketStatus.active;
    final Color top = isActive ? const Color(0xFF1B2E8D) : _kExpiredTop;
    final Color bot = isActive ? const Color(0xFF0F1035) : _kExpiredBot;

    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) => _pressCtrl.reverse(),
      onTapCancel: () => _pressCtrl.reverse(),
      onTap: _openDetail,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: isActive ? 0.08 : 0.05),
              width: 1.0,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: top.withValues(alpha: isActive ? 0.38 : 0.28),
                blurRadius: 28,
                offset: const Offset(0, 14),
                spreadRadius: -6,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[top, bot],
                      ),
                    ),
                  ),
                ),
                if (isActive)
                  Positioned(
                    top: -120,
                    left: 0,
                    right: 0,
                    height: 240,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: <Color>[
                            const Color(0xFF3B82F6).withValues(alpha: 0.35),
                            const Color(0xFF3B82F6).withValues(alpha: 0.0),
                          ],
                          stops: const <double>[0.0, 1.0],
                        ),
                      ),
                    ),
                  ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // Top: operator + Class badge + Passenger count badge
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              const Icon(
                                Icons.train_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    t.trainName.toUpperCase(),
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  Text(
                                    t.trainNumber,
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF828BCF),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              if (t.passengers.length > 1) ...<Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.30),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      const Icon(
                                        Icons.group_outlined,
                                        size: 13,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${t.passengers.length} Pax',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.30),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                      t.ticketClass.contains('2') ? '2A' : (t.ticketClass.contains('1') ? '1A' : 'SL'),
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        height: 1.1,
                                      ),
                                    ),
                                    Text(
                                      'Class',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF828BCF),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Route block
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: _StationBlock(
                                  code: t.fromCode,
                                  time: t.departTime,
                                  city: t.fromName,
                                  alignEnd: false,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.only(top: 14),
                                child: _RouteRail(),
                              ),
                              Expanded(
                                child: _StationBlock(
                                  code: t.toCode,
                                  time: t.arriveTime,
                                  city: t.toName,
                                  alignEnd: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Date pill centered
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFF828BCF).withValues(alpha: 0.30),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 13,
                                    color: Color(0xFF828BCF),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    t.date,
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF828BCF),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Notched Divider
                    _PassDivider(
                      notchColor: Theme.of(context).scaffoldBackgroundColor,
                    ),
                    // Inner Box containing Fields and Footer
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: <Widget>[
                                // Row 1: Date | Departure | Arrival
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: _GridField(
                                        label: 'Date',
                                        value: t.date.split(' ').sublist(0, 2).join(' '),
                                      ),
                                    ),
                                    Expanded(
                                      child: _GridField(
                                        label: 'Departure',
                                        value: t.departTime,
                                      ),
                                    ),
                                    Expanded(
                                      child: _GridField(
                                        label: 'Arrival',
                                        value: t.arriveTime,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  height: 1,
                                  color: Colors.white.withValues(alpha: 0.06),
                                  margin: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                // Row 2: Coach | Seat | Platform | Berth
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: _GridField(
                                        label: 'Coach',
                                        value: t.coachesListLabel,
                                      ),
                                    ),
                                    Expanded(
                                      child: _GridField(
                                        label: 'Seat',
                                        value: t.seatsListLabel,
                                      ),
                                    ),
                                    Expanded(
                                      child: _GridField(
                                        label: 'Platform',
                                        value: t.halts.isNotEmpty ? (t.halts.first.platform ?? '5') : '5',
                                      ),
                                    ),
                                    Expanded(
                                      child: _GridField(
                                        label: 'Berth',
                                        value: t.berthsListLabel,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  height: 1,
                                  color: Colors.white.withValues(alpha: 0.06),
                                  margin: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                // Row 3: PNR | Booking ID
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: _GridField(
                                        label: 'PNR',
                                        value: t.pnr,
                                      ),
                                    ),
                                    Expanded(
                                      child: _GridField(
                                        label: 'Booking ID',
                                        value: t.bookingId,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // IRCTC Footer
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.25),
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
                              border: Border(
                                top: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  width: 1.0,
                                ),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            child: Row(
                              children: <Widget>[
                                const Icon(
                                  Icons.train_outlined,
                                  size: 20,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      t.operator,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      'Indian Railways',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF828BCF),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Container(
                                  width: 1,
                                  height: 24,
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                                const Spacer(),
                                const Icon(
                                  Icons.notifications_active_outlined,
                                  size: 18,
                                  color: Color(0xFF828BCF),
                                ),
                                const SizedBox(width: 6),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'Your trip begins in',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF828BCF),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '3 Days',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF4A90E2),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _StationBlock extends StatelessWidget {
  const _StationBlock({
    required this.code,
    required this.time,
    required this.city,
    required this.alignEnd,
  });

  final String code;
  final String time;
  final String city;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final CrossAxisAlignment cross =
        alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final TextAlign textAlign = alignEnd ? TextAlign.right : TextAlign.left;

    return Column(
      crossAxisAlignment: cross,
      children: <Widget>[
        Text(
          code,
          textAlign: textAlign,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          city,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: GoogleFonts.inter(
            color: const Color(0xFF828BCF),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          time,
          textAlign: textAlign,
          style: GoogleFonts.inter(
            color: const Color(0xFF5282F0),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _RouteRail extends StatelessWidget {
  const _RouteRail();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            height: 1.2,
            color: Colors.white.withValues(alpha: 0.25),
          ),
          Positioned(
            left: 0,
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFF828BCF),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 0,
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFF828BCF),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Color(0xFF1B2E8D),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.train_rounded,
              size: 14,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _GridField extends StatelessWidget {
  const _GridField({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.15,
          ),
        ),
      ],
    );
  }
}

class _PassDivider extends StatelessWidget {
  const _PassDivider({required this.notchColor});
  final Color notchColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: CustomPaint(
        painter: _PassDividerPainter(notchColor: notchColor),
        size: const Size(double.infinity, 16),
      ),
    );
  }
}

class _PassDividerPainter extends CustomPainter {
  _PassDividerPainter({required this.notchColor});
  final Color notchColor;

  @override
  void paint(Canvas canvas, Size size) {
    const double r = 8;
    final Paint notch = Paint()..color = notchColor;
    canvas.drawCircle(Offset(0, size.height / 2), r, notch);
    canvas.drawCircle(Offset(size.width, size.height / 2), r, notch);

    final Paint dash = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    double x = r * 2;
    final double y = size.height / 2;
    while (x < size.width - r * 2) {
      canvas.drawLine(Offset(x, y), Offset(x + 4, y), dash);
      x += 9;
    }
  }

  @override
  bool shouldRepaint(covariant _PassDividerPainter old) =>
      old.notchColor != notchColor;
}
