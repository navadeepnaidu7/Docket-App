import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/haptics/haptic_service.dart';
import '../domain/ticket_models.dart';
import 'ticket_detail_screen.dart';

export '../domain/ticket_models.dart';

// ── Pass face palette ─────────────────────────────────────────────────────────

const Color _kActiveTop = Color(0xFF1B3A6B);
const Color _kActiveBot = Color(0xFF0A1F3D);
const Color _kActiveAccent = Color(0xFF5BA3E8);

const Color _kExpiredTop = Color(0xFF3A3A3C);
const Color _kExpiredBot = Color(0xFF1C1C1E);

// ── Wallet card ───────────────────────────────────────────────────────────────

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
    final Color top = isActive ? _kActiveTop : _kExpiredTop;
    final Color bot = isActive ? _kActiveBot : _kExpiredBot;

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
                Positioned(
                  top: -50,
                  right: -30,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: <Color>[
                          (isActive ? _kActiveAccent : Colors.white)
                              .withValues(alpha: 0.14),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // Top: operator + status
                          Row(
                            children: <Widget>[
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: const Icon(
                                  Icons.train_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                t.operator,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const Spacer(),
                              _StatusPill(isActive: isActive),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            t.trainTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.15,
                            ),
                          ),
                          const SizedBox(height: 22),
                          // Route
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
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: _RouteRail(duration: t.duration),
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
                        ],
                      ),
                    ),
                    // Soft divider
                    _PassDivider(
                      notchColor: Theme.of(context).scaffoldBackgroundColor,
                    ),
                    // Footer
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  t.passengerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              Text(
                                '${t.coach} · ${t.seat} · ${t.berth}',
                                style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${t.date}  ·  ${t.ticketClass}',
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.50),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
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
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.4,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          time,
          textAlign: textAlign,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          city,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.48),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _RouteRail extends StatelessWidget {
  const _RouteRail({required this.duration});
  final String duration;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.22),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.train_rounded,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            duration,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.48),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isActive});
  final bool isActive;

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
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF30D158)
                  : const Color(0xFF8E8E93),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isActive ? 'Active' : 'Expired',
            style: GoogleFonts.inter(
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
