import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/ticket_models.dart';
import '../movie/movie_ticket_chrome.dart';

/// How dense the shared train e-ticket face should render.
enum TrainTicketDensity {
  /// Passes stack — compact ticket stub.
  glance,

  /// Fullscreen detail — roomier type and QR.
  detail,
}

/// IRCTC / Indian Railways visual policy for the train pass face.
@immutable
class TrainTicketStyle {
  const TrainTicketStyle({
    required this.bodyGradient,
    required this.accent,
    required this.glow,
    required this.labelAlpha,
  });

  final List<Color> bodyGradient;
  final Color accent;
  final Color glow;
  final double labelAlpha;

  static const TrainTicketStyle active = TrainTicketStyle(
    bodyGradient: <Color>[Color(0xFF152A7A), Color(0xFF0C1028)],
    accent: Color(0xFF7EB0FF),
    glow: Color(0xFF3B82F6),
    labelAlpha: 0.55,
  );

  static const TrainTicketStyle expired = TrainTicketStyle(
    bodyGradient: <Color>[Color(0xFF3A3A3C), Color(0xFF1C1C1E)],
    accent: Color(0xFF8E8E93),
    glow: Color(0xFF636366),
    labelAlpha: 0.50,
  );

  static TrainTicketStyle forTicket(
    MockTicket ticket, {
    bool useBrandColors = false,
  }) {
    final bool active =
        useBrandColors || ticket.status == TicketStatus.active;
    return active ? TrainTicketStyle.active : TrainTicketStyle.expired;
  }
}

/// Single train e-ticket face for wallet + detail screens.
///
/// Clean route-first stub: stations and times lead, train meta is secondary,
/// booking chips stay compact so the face doesn't feel like a form dump.
class TrainTicketFace extends StatelessWidget {
  const TrainTicketFace({
    super.key,
    required this.ticket,
    required this.density,
    this.useBrandColors = false,
    this.widthFactor,
    this.onOpenCodes,
  });

  final MockTicket ticket;
  final TrainTicketDensity density;

  /// When true, keep brand colors even if the pass is expired (detail chrome).
  final bool useBrandColors;

  /// Optional width shrink vs parent (glance only).
  final double? widthFactor;

  /// Detail only — opens fullscreen QR/barcode viewer.
  final VoidCallback? onOpenCodes;

  bool get _isGlance => density == TrainTicketDensity.glance;

  static double footerBodyHeight({required bool detail, required double scale}) =>
      (detail ? 72.0 : 58.0) * scale;

  @override
  Widget build(BuildContext context) {
    final bool isActive = ticket.status == TicketStatus.active;
    final TrainTicketStyle style = TrainTicketStyle.forTicket(
      ticket,
      useBrandColors: useBrandColors,
    );
    final double scale =
        _isGlance ? MovieTicketMetrics.glanceTallScale : 1.0;
    final double footerHeight =
        footerBodyHeight(detail: !_isGlance, scale: scale);
    final double notchFromBottom =
        footerHeight + (MovieTicketMetrics.tearHeight * scale) / 2;
    final double factor = widthFactor ?? (_isGlance ? 0.94 : 1.0);

    final Widget ticketWidget = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MovieTicketMetrics.cornerR),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: style.bodyGradient.first
                .withValues(alpha: isActive ? 0.38 : 0.26),
            blurRadius: 28,
            offset: const Offset(0, 12),
            spreadRadius: -6,
          ),
        ],
      ),
      child: ClipPath(
        clipper: TicketShapeClipper(notchFromBottom: notchFromBottom),
        child: _TicketBody(
          ticket: ticket,
          style: style,
          isActive: isActive,
          scale: scale,
          density: density,
          footerHeight: footerHeight,
          onOpenCodes: onOpenCodes,
        ),
      ),
    );

    if (factor >= 0.999) return ticketWidget;

    return Align(
      child: FractionallySizedBox(
        widthFactor: factor,
        child: ticketWidget,
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _TicketBody extends StatelessWidget {
  const _TicketBody({
    required this.ticket,
    required this.style,
    required this.isActive,
    required this.scale,
    required this.density,
    required this.footerHeight,
    this.onOpenCodes,
  });

  final MockTicket ticket;
  final TrainTicketStyle style;
  final bool isActive;
  final double scale;
  final TrainTicketDensity density;
  final double footerHeight;
  final VoidCallback? onOpenCodes;

  bool get _detail => density == TrainTicketDensity.detail;

  @override
  Widget build(BuildContext context) {
    final Color label = Colors.white.withValues(alpha: style.labelAlpha);
    final MockTicket t = ticket;

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: style.bodyGradient,
              ),
            ),
          ),
        ),
        // Soft corner glow — restrained, not a second card.
        Positioned(
          top: -60,
          right: -40,
          child: IgnorePointer(
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    style.glow.withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(
                18 * scale,
                14 * scale,
                18 * scale,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _TopBar(
                    operator: t.operator,
                    isActive: isActive,
                    scale: scale,
                  ),
                  SizedBox(height: (_detail ? 22 : 18) * scale),
                  _RouteBlock(
                    ticket: t,
                    style: style,
                    detail: _detail,
                    scale: scale,
                  ),
                  SizedBox(height: (_detail ? 22 : 18) * scale),
                  Text(
                    t.trainName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: _detail ? 22 : 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: 5 * scale),
                  Text(
                    '${t.trainNumber}  ·  ${_classShort(t.ticketClass)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: label,
                      fontSize: _detail ? 13 : 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.1,
                    ),
                  ),
                  SizedBox(height: (_detail ? 18 : 14) * scale),
                  _MetaChips(
                    date: _shortDate(t.date),
                    coach: t.coachesListLabel,
                    seat: _detail ? t.seatsListLabel : t.seatSummary,
                    label: label,
                    accent: style.accent,
                    detail: _detail,
                    scale: scale,
                  ),
                  if (_detail) ...<Widget>[
                    SizedBox(height: 16 * scale),
                    _PnrRow(
                      pnr: t.pnr,
                      label: label,
                    ),
                    SizedBox(height: 14 * scale),
                    _TicketCodes(
                      accent: style.accent,
                      onTap: onOpenCodes,
                    ),
                  ],
                ],
              ),
            ),
            if (!_detail) const Spacer(),
            if (_detail) SizedBox(height: 12 * scale),
            TicketTearLine(height: MovieTicketMetrics.tearHeight * scale),
            SizedBox(
              width: double.infinity,
              height: footerHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20 * scale),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          Icons.train_rounded,
                          size: 16 * scale,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                        SizedBox(width: 7 * scale),
                        Text(
                          t.operator.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 12 * scale,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: MovieTicketMetrics.footerIdGap * scale),
                    SizedBox(
                      height: MovieTicketMetrics.footerIdLine,
                      child: Text(
                        'Indian Railways',
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _shortDate(String full) {
    final int i = full.indexOf(', ');
    return i >= 0 ? full.substring(i + 2) : full;
  }

  String _classShort(String ticketClass) {
    final String u = ticketClass.toUpperCase();
    if (u.contains('2') && u.contains('AC')) return '2A';
    if (u.contains('1') && u.contains('AC')) return '1A';
    if (u.contains('3') && u.contains('AC')) return '3A';
    if (u.contains('SL')) return 'SL';
    if (u.contains('CC')) return 'CC';
    if (u.contains('2')) return '2A';
    if (u.contains('1')) return '1A';
    if (u.contains('3')) return '3A';
    return ticketClass;
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.operator,
    required this.isActive,
    required this.scale,
  });

  final String operator;
  final bool isActive;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 9 * scale,
            vertical: 5 * scale,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.train_rounded,
                size: 13 * scale,
                color: Colors.white.withValues(alpha: 0.92),
              ),
              SizedBox(width: 5 * scale),
              Text(
                operator,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 11 * scale,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        _StatusPill(isActive: isActive, scale: scale),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isActive, required this.scale});

  final bool isActive;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final Color dot =
        isActive ? const Color(0xFF30D158) : const Color(0xFF8E8E93);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 9 * scale,
        vertical: 5 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6 * scale,
            height: 6 * scale,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          SizedBox(width: 6 * scale),
          Text(
            isActive ? 'Active' : 'Expired',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 11 * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Route ─────────────────────────────────────────────────────────────────────

class _RouteBlock extends StatelessWidget {
  const _RouteBlock({
    required this.ticket,
    required this.style,
    required this.detail,
    required this.scale,
  });

  final MockTicket ticket;
  final TrainTicketStyle style;
  final bool detail;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final MockTicket t = ticket;
    final Color soft = Colors.white.withValues(alpha: 0.62);

    return Column(
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _StationEnd(
                code: t.fromCode,
                name: t.fromName,
                time: t.departTime,
                alignEnd: false,
                detail: detail,
                scale: scale,
                soft: soft,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                top: (detail ? 14 : 12) * scale,
                left: 8 * scale,
                right: 8 * scale,
              ),
              child: _RouteSpine(
                duration: t.duration,
                accent: style.accent,
                detail: detail,
                scale: scale,
              ),
            ),
            Expanded(
              child: _StationEnd(
                code: t.toCode,
                name: t.toName,
                time: t.arriveTime,
                alignEnd: true,
                detail: detail,
                scale: scale,
                soft: soft,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StationEnd extends StatelessWidget {
  const _StationEnd({
    required this.code,
    required this.name,
    required this.time,
    required this.alignEnd,
    required this.detail,
    required this.scale,
    required this.soft,
  });

  final String code;
  final String name;
  final String time;
  final bool alignEnd;
  final bool detail;
  final double scale;
  final Color soft;

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
            fontSize: detail ? 30 : 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.1,
            height: 1.0,
          ),
        ),
        SizedBox(height: 6 * scale),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: GoogleFonts.inter(
            color: soft,
            fontSize: detail ? 12.5 : 11.5,
            fontWeight: FontWeight.w500,
            height: 1.15,
          ),
        ),
        SizedBox(height: 6 * scale),
        Text(
          time,
          textAlign: textAlign,
          style: GoogleFonts.inter(
            color: const Color(0xFF9EC0FF),
            fontSize: detail ? 14 : 13,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _RouteSpine extends StatelessWidget {
  const _RouteSpine({
    required this.duration,
    required this.accent,
    required this.detail,
    required this.scale,
  });

  final String duration;
  final Color accent;
  final bool detail;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final double width = (detail ? 84.0 : 70.0) * scale;
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: 22 * scale,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                // Thin track
                Positioned(
                  left: 0,
                  right: 0,
                  child: CustomPaint(
                    painter: _DashedLinePainter(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                    size: Size(width, 1.5),
                  ),
                ),
                Container(
                  width: 22 * scale,
                  height: 22 * scale,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 13 * scale,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 7 * scale),
          Text(
            duration,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: accent.withValues(alpha: 0.95),
              fontSize: detail ? 11 : 10,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    const double dash = 4;
    const double gap = 3.5;
    double x = 0;
    final double y = size.height / 2;
    while (x < size.width) {
      final double x2 = (x + dash).clamp(0.0, size.width);
      canvas.drawLine(Offset(x, y), Offset(x2, y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter old) => old.color != color;
}

// ── Meta chips ────────────────────────────────────────────────────────────────

class _MetaChips extends StatelessWidget {
  const _MetaChips({
    required this.date,
    required this.coach,
    required this.seat,
    required this.label,
    required this.accent,
    required this.detail,
    required this.scale,
  });

  final String date;
  final String coach;
  final String seat;
  final Color label;
  final Color accent;
  final bool detail;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _Chip(
            caption: 'Date',
            value: date,
            label: label,
            detail: detail,
            scale: scale,
          ),
        ),
        SizedBox(width: 8 * scale),
        Expanded(
          child: _Chip(
            caption: 'Coach',
            value: coach,
            label: label,
            detail: detail,
            scale: scale,
          ),
        ),
        SizedBox(width: 8 * scale),
        Expanded(
          child: _Chip(
            caption: 'Seat',
            value: seat,
            label: label,
            detail: detail,
            scale: scale,
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.caption,
    required this.value,
    required this.label,
    required this.detail,
    required this.scale,
  });

  final String caption;
  final String value;
  final Color label;
  final bool detail;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: (detail ? 10 : 9) * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            caption.toUpperCase(),
            style: GoogleFonts.inter(
              color: label,
              fontSize: detail ? 10 : 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              height: 1.0,
            ),
          ),
          SizedBox(height: 5 * scale),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: detail ? 14 : 13,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _PnrRow extends StatelessWidget {
  const _PnrRow({required this.pnr, required this.label});

  final String pnr;
  final Color label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: <Widget>[
          Text(
            'PNR',
            style: GoogleFonts.inter(
              color: label,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const Spacer(),
          Text(
            _formatPnr(pnr),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPnr(String raw) {
    if (raw.length <= 4) return raw;
    final StringBuffer b = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      if (i > 0 && i % 4 == 0) b.write(' ');
      b.write(raw[i]);
    }
    return b.toString();
  }
}

// ── Codes ─────────────────────────────────────────────────────────────────────

class _TicketCodes extends StatelessWidget {
  const _TicketCodes({
    required this.accent,
    this.onTap,
  });

  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: <Widget>[
              TicketQrTile(size: 56, accent: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Show boarding code',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'QR & barcode for scanning',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.52),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.40),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
