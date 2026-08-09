import 'dart:math' as math;

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

/// Visual policy for the train pass face.
///
/// Inspired by premium rail booking product design: warm paper surface,
/// charcoal type, and a single mint accent — not a gradient poster.
@immutable
class TrainTicketStyle {
  const TrainTicketStyle({
    required this.surface,
    required this.surfaceDeep,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.accentSoft,
    required this.track,
    required this.trackDone,
    required this.chipFill,
    required this.divider,
    required this.shadow,
    required this.footerInk,
  });

  final Color surface;
  final Color surfaceDeep;
  final Color ink;
  final Color muted;
  final Color accent;
  final Color accentSoft;
  final Color track;
  final Color trackDone;
  final Color chipFill;
  final Color divider;
  final Color shadow;
  final Color footerInk;

  static const TrainTicketStyle active = TrainTicketStyle(
    surface: Color(0xFFFFFDF9),
    surfaceDeep: Color(0xFFF4F7F2),
    ink: Color(0xFF0F1410),
    muted: Color(0xFF6B736C),
    accent: Color(0xFF1FBF75),
    accentSoft: Color(0xFFD8F5E6),
    track: Color(0xFFD5DBD6),
    trackDone: Color(0xFF0F1410),
    chipFill: Color(0xFFF2F5F1),
    divider: Color(0xFFE4E9E3),
    shadow: Color(0xFF1FBF75),
    footerInk: Color(0xFF3A433C),
  );

  static const TrainTicketStyle expired = TrainTicketStyle(
    surface: Color(0xFFF7F7F7),
    surfaceDeep: Color(0xFFEEEEEE),
    ink: Color(0xFF3A3A3C),
    muted: Color(0xFF8E8E93),
    accent: Color(0xFF8E8E93),
    accentSoft: Color(0xFFE8E8ED),
    track: Color(0xFFD1D1D6),
    trackDone: Color(0xFF8E8E93),
    chipFill: Color(0xFFF0F0F2),
    divider: Color(0xFFE0E0E4),
    shadow: Color(0xFF636366),
    footerInk: Color(0xFF636366),
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
  final bool useBrandColors;
  final double? widthFactor;
  final VoidCallback? onOpenCodes;

  bool get _isGlance => density == TrainTicketDensity.glance;

  static double footerBodyHeight({required bool detail, required double scale}) =>
      (detail ? 68.0 : 54.0) * scale;

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
            color: style.shadow.withValues(alpha: isActive ? 0.22 : 0.12),
            blurRadius: 32,
            offset: const Offset(0, 16),
            spreadRadius: -8,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
            spreadRadius: -4,
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
    final MockTicket t = ticket;

    return Stack(
      children: <Widget>[
        // Paper surface
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[style.surface, style.surfaceDeep],
              ),
            ),
          ),
        ),
        // Soft mint wash top-right
        Positioned(
          top: -80,
          right: -50,
          child: IgnorePointer(
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    style.accent.withValues(alpha: isActive ? 0.14 : 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        // Top accent hairline
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 3.5 * scale,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  style.accent.withValues(alpha: 0.0),
                  style.accent,
                  style.accent.withValues(alpha: 0.0),
                ],
                stops: const <double>[0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(
                20 * scale,
                18 * scale,
                20 * scale,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _HeaderRow(
                    operator: t.operator,
                    isActive: isActive,
                    style: style,
                    scale: scale,
                  ),
                  SizedBox(height: (_detail ? 22 : 18) * scale),
                  Text(
                    'Passenger',
                    style: GoogleFonts.inter(
                      color: style.muted,
                      fontSize: 11.5 * scale.clamp(0.9, 1.15).toDouble(),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.15,
                      height: 1.0,
                    ),
                  ),
                  SizedBox(height: 5 * scale),
                  Text(
                    t.passengerCount > 1
                        ? '${t.passengerName}  +${t.passengerCount - 1}'
                        : t.passengerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: style.ink,
                      fontSize: _detail ? 22 : 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.55,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: (_detail ? 22 : 18) * scale),
                  _RouteTimeline(
                    ticket: t,
                    style: style,
                    detail: _detail,
                    scale: scale,
                  ),
                  SizedBox(height: (_detail ? 22 : 18) * scale),
                  _ReferenceBlock(
                    label: 'Booking reference',
                    value: _formatPnr(t.pnr),
                    style: style,
                    scale: scale,
                    detail: _detail,
                  ),
                  SizedBox(height: (_detail ? 18 : 14) * scale),
                  _StatsRow(
                    style: style,
                    scale: scale,
                    detail: _detail,
                    items: <_StatItem>[
                      _StatItem(
                        label: 'Coach',
                        value: t.coachesListLabel,
                      ),
                      _StatItem(
                        label: 'Train',
                        value: t.trainNumber,
                      ),
                      // Never a bare passenger count here: '3' under a "Seat"
                      // label reads as seat number 3. The detail face has room
                      // for the actual numbers; the glance face says how many.
                      _StatItem(
                        label: t.passengerCount == 1 ? 'Seat' : 'Seats',
                        value: _detail ? t.seatsListLabel : t.seatSummary,
                      ),
                    ],
                  ),
                  SizedBox(height: (_detail ? 10 : 8) * scale),
                  Text(
                    '${t.trainName}  ·  ${_classShort(t.ticketClass)}  ·  ${_shortDate(t.date)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: style.muted,
                      fontSize: _detail ? 12 : 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.1,
                    ),
                  ),
                  if (_detail) ...<Widget>[
                    SizedBox(height: 18 * scale),
                    _CodesPanel(
                      style: style,
                      onTap: onOpenCodes,
                    ),
                  ],
                ],
              ),
            ),
            if (!_detail) const Spacer(),
            if (_detail) SizedBox(height: 10 * scale),
            _PaperTear(style: style, height: MovieTicketMetrics.tearHeight * scale),
            SizedBox(
              width: double.infinity,
              height: footerHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20 * scale),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    _RailMark(color: style.footerInk, size: 16 * scale),
                    SizedBox(width: 8 * scale),
                    Text(
                      'Indian Railways',
                      style: GoogleFonts.inter(
                        color: style.footerInk.withValues(alpha: 0.85),
                        fontSize: 12.5 * scale.clamp(0.9, 1.1).toDouble(),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
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
    if (u.contains('2') && (u.contains('AC') || u.contains('2A'))) return '2A';
    if (u.contains('1') && (u.contains('AC') || u.contains('1A'))) return '1A';
    if (u.contains('3') && (u.contains('AC') || u.contains('3A'))) return '3A';
    if (u.contains('SL')) return 'SL';
    if (u.contains('CC')) return 'CC';
    return ticketClass;
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

// ── Header ────────────────────────────────────────────────────────────────────

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.operator,
    required this.isActive,
    required this.style,
    required this.scale,
  });

  final String operator;
  final bool isActive;
  final TrainTicketStyle style;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 10 * scale,
            vertical: 6 * scale,
          ),
          decoration: BoxDecoration(
            color: style.accentSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.train_rounded,
                size: 14 * scale,
                color: style.accent,
              ),
              SizedBox(width: 5 * scale),
              Text(
                operator.toUpperCase(),
                style: GoogleFonts.inter(
                  color: style.ink,
                  fontSize: 11 * scale,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 10 * scale,
            vertical: 6 * scale,
          ),
          decoration: BoxDecoration(
            color: isActive ? style.accentSoft : style.chipFill,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 6 * scale,
                height: 6 * scale,
                decoration: BoxDecoration(
                  color: isActive ? style.accent : style.muted,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 6 * scale),
              Text(
                isActive ? 'Active' : 'Expired',
                style: GoogleFonts.inter(
                  color: isActive ? style.ink : style.muted,
                  fontSize: 11 * scale,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Route timeline (Dribbble center card) ─────────────────────────────────────

class _RouteTimeline extends StatelessWidget {
  const _RouteTimeline({
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

    return Column(
      children: <Widget>[
        // Times + duration
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                t.departTime,
                style: GoogleFonts.inter(
                  color: style.ink,
                  fontSize: detail ? 17 : 15.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.35,
                  height: 1.0,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 10 * scale,
                vertical: 4 * scale,
              ),
              decoration: BoxDecoration(
                color: style.chipFill,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                t.duration,
                style: GoogleFonts.inter(
                  color: style.muted,
                  fontSize: detail ? 11.5 : 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            Expanded(
              child: Text(
                t.arriveTime,
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                  color: style.ink,
                  fontSize: detail ? 17 : 15.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.35,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12 * scale),
        // Track with train
        SizedBox(
          height: 22 * scale,
          child: CustomPaint(
            painter: _RouteTrackPainter(
              doneColor: style.trackDone,
              pendingColor: style.track,
              accent: style.accent,
              progress: t.progressFraction.clamp(0.18, 0.82).toDouble(),
            ),
            size: Size(double.infinity, 22 * scale),
          ),
        ),
        SizedBox(height: 12 * scale),
        // Station names + codes
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    t.fromName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: style.ink,
                      fontSize: detail ? 15 : 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.25,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: 3 * scale),
                  Text(
                    t.fromCode,
                    style: GoogleFonts.inter(
                      color: style.muted,
                      fontSize: detail ? 12 : 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    t.toName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      color: style.ink,
                      fontSize: detail ? 15 : 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.25,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: 3 * scale),
                  Text(
                    t.toCode,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      color: style.muted,
                      fontSize: detail ? 12 : 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Solid → train → dotted track, matching the booking UI reference.
class _RouteTrackPainter extends CustomPainter {
  _RouteTrackPainter({
    required this.doneColor,
    required this.pendingColor,
    required this.accent,
    required this.progress,
  });

  final Color doneColor;
  final Color pendingColor;
  final Color accent;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final double cy = size.height / 2;
    final double left = 5;
    final double right = size.width - 5;
    final double trainX = left + (right - left) * progress.clamp(0.15, 0.85).toDouble();

    // End dots
    canvas.drawCircle(
      Offset(left, cy),
      4.2,
      Paint()..color = doneColor,
    );
    canvas.drawCircle(
      Offset(right, cy),
      4.2,
      Paint()
        ..color = pendingColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      Offset(right, cy),
      1.8,
      Paint()..color = accent,
    );

    // Solid completed segment
    final Paint solid = Paint()
      ..color = doneColor
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(left + 6, cy), Offset(trainX - 14, cy), solid);

    // Dotted remaining segment
    final Paint dot = Paint()
      ..color = pendingColor
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    double x = trainX + 14;
    while (x < right - 8) {
      final double x2 = math.min(x + 3.5, right - 8);
      canvas.drawLine(Offset(x, cy), Offset(x2, cy), dot);
      x += 7.5;
    }

    // Train capsule
    final RRect body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(trainX, cy),
        width: 26,
        height: 16,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(body, Paint()..color = doneColor);

    // Cabin window
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(trainX - 2, cy),
          width: 8,
          height: 7,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
    // Nose
    final Path nose = Path()
      ..moveTo(trainX + 10, cy - 5)
      ..lineTo(trainX + 15, cy)
      ..lineTo(trainX + 10, cy + 5)
      ..close();
    canvas.drawPath(nose, Paint()..color = doneColor);
  }

  @override
  bool shouldRepaint(covariant _RouteTrackPainter old) {
    return old.progress != progress ||
        old.doneColor != doneColor ||
        old.pendingColor != pendingColor ||
        old.accent != accent;
  }
}

// ── Reference + stats ─────────────────────────────────────────────────────────

class _ReferenceBlock extends StatelessWidget {
  const _ReferenceBlock({
    required this.label,
    required this.value,
    required this.style,
    required this.scale,
    required this.detail,
  });

  final String label;
  final String value;
  final TrainTicketStyle style;
  final double scale;
  final bool detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: GoogleFonts.inter(
            color: style.muted,
            fontSize: 11.5 * scale.clamp(0.9, 1.15).toDouble(),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
        SizedBox(height: 5 * scale),
        Text(
          value,
          style: GoogleFonts.inter(
            color: style.ink,
            fontSize: detail ? 20 : 17.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _StatItem {
  const _StatItem({required this.label, required this.value});
  final String label;
  final String value;
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.style,
    required this.scale,
    required this.detail,
    required this.items,
  });

  final TrainTicketStyle style;
  final double scale;
  final bool detail;
  final List<_StatItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 4 * scale,
        vertical: (detail ? 14 : 12) * scale,
      ),
      decoration: BoxDecoration(
        color: style.chipFill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < items.length; i++) ...<Widget>[
            if (i > 0)
              Container(
                width: 1,
                height: 32 * scale,
                color: style.divider,
              ),
            Expanded(
              child: Column(
                children: <Widget>[
                  Text(
                    items[i].label,
                    style: GoogleFonts.inter(
                      color: style.muted,
                      fontSize: detail ? 11.5 : 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 5 * scale),
                  Text(
                    items[i].value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: style.ink,
                      fontSize: detail ? 20 : 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Codes (detail) ────────────────────────────────────────────────────────────

class _CodesPanel extends StatelessWidget {
  const _CodesPanel({
    required this.style,
    this.onTap,
  });

  final TrainTicketStyle style;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: style.divider),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: CustomPaint(
                    painter: _DarkBarcodePainter(color: style.ink),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: style.divider),
                ),
                child: CustomPaint(
                  painter: _DarkQrPainter(color: style.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DarkBarcodePainter extends CustomPainter {
  _DarkBarcodePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color.withValues(alpha: 0.88);
    const List<double> widths = <double>[
      1.2, 0.8, 2.0, 0.8, 1.2, 1.6, 0.8, 2.4, 0.8, 1.2,
      0.8, 1.6, 2.0, 0.8, 1.2, 0.8, 2.0, 1.2, 0.8, 1.6,
      0.8, 2.4, 0.8, 1.2, 1.6, 0.8, 2.0, 0.8, 1.2, 0.8,
    ];
    double x = 0;
    int i = 0;
    while (x < size.width - 2) {
      final double w = widths[i % widths.length];
      if (i.isEven) {
        canvas.drawRect(
          Rect.fromLTWH(x, 0, w, size.height),
          paint,
        );
      }
      x += w + 0.7;
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant _DarkBarcodePainter old) => old.color != color;
}

class _DarkQrPainter extends CustomPainter {
  _DarkQrPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color.withValues(alpha: 0.9);
    final double cell = size.width / 9;
    const List<List<int>> pattern = <List<int>>[
      <int>[1, 1, 1, 1, 1, 1, 1, 0, 1],
      <int>[1, 0, 0, 0, 0, 0, 1, 0, 0],
      <int>[1, 0, 1, 1, 1, 0, 1, 0, 1],
      <int>[1, 0, 1, 1, 1, 0, 1, 1, 0],
      <int>[1, 0, 1, 1, 1, 0, 1, 0, 1],
      <int>[1, 0, 0, 0, 0, 0, 1, 1, 0],
      <int>[1, 1, 1, 1, 1, 1, 1, 0, 1],
      <int>[0, 0, 1, 0, 1, 0, 0, 1, 0],
      <int>[1, 0, 1, 1, 0, 1, 1, 0, 1],
    ];
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (pattern[r][c] == 1) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(c * cell, r * cell, cell * 0.88, cell * 0.88),
              Radius.circular(cell * 0.12),
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DarkQrPainter old) => old.color != color;
}

// ── Tear + brand mark ─────────────────────────────────────────────────────────

class _PaperTear extends StatelessWidget {
  const _PaperTear({required this.style, required this.height});

  final TrainTicketStyle style;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _PaperDashPainter(color: style.divider),
      ),
    );
  }
}

class _PaperDashPainter extends CustomPainter {
  _PaperDashPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint dash = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const double inset = 18;
    double x = inset;
    final double y = size.height / 2;
    while (x < size.width - inset) {
      canvas.drawLine(Offset(x, y), Offset(x + 5, y), dash);
      x += 10;
    }
  }

  @override
  bool shouldRepaint(covariant _PaperDashPainter old) => old.color != color;
}

class _RailMark extends StatelessWidget {
  const _RailMark({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _RailMarkPainter(color: color)),
    );
  }
}

class _RailMarkPainter extends CustomPainter {
  _RailMarkPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final double w = size.width;
    final double h = size.height;
    // Simplified locomotive mark
    final RRect body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.12, h * 0.28, w * 0.62, h * 0.42),
      Radius.circular(w * 0.1),
    );
    canvas.drawRRect(body, p);
    canvas.drawLine(
      Offset(w * 0.74, h * 0.42),
      Offset(w * 0.9, h * 0.42),
      p,
    );
    canvas.drawCircle(Offset(w * 0.32, h * 0.78), w * 0.1, p);
    canvas.drawCircle(Offset(w * 0.58, h * 0.78), w * 0.1, p);
  }

  @override
  bool shouldRepaint(covariant _RailMarkPainter old) => old.color != color;
}
