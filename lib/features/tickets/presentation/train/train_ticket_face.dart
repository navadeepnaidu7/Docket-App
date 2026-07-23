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
    bodyGradient: <Color>[Color(0xFF1B2E8D), Color(0xFF0F1035)],
    accent: Color(0xFF6BA3FF),
    glow: Color(0xFF3B82F6),
    labelAlpha: 0.60,
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
/// Mirrors [MovieTicketFace] geometry (notches, tear, footer) but uses a
/// source → destination hero instead of a movie poster.
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
      (detail ? 82.0 : 64.0) * scale;

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
                .withValues(alpha: isActive ? 0.40 : 0.28),
            blurRadius: 30,
            offset: const Offset(0, 14),
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
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: style.bodyGradient,
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
                  style.glow.withValues(alpha: 0.28),
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
              padding: EdgeInsets.fromLTRB(
                14 * scale,
                12 * scale,
                14 * scale,
                0,
              ),
              child: _RouteHeroBand(
                ticket: t,
                style: style,
                isActive: isActive,
                height: (_detail ? 200.0 : 160.0) * scale,
                detail: _detail,
                scale: scale,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20 * scale,
                (_detail ? 18 : 14) * scale,
                20 * scale,
                4 * scale,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    t.trainName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: _detail ? 24 : 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.55,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: 4 * scale),
                  Text(
                    _detail
                        ? '${t.trainNumber}  ·  ${t.ticketClass}'
                        : t.trainNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: label,
                      fontSize: _detail ? 13 : 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: (_detail ? 18 : 14) * scale),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _Field(
                          label: 'Date',
                          value: _shortDate(t.date),
                          labelColor: label,
                          detail: _detail,
                        ),
                      ),
                      Expanded(
                        child: _Field(
                          label: 'Departure',
                          value: t.departTime,
                          labelColor: label,
                          detail: _detail,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: (_detail ? 16 : 12) * scale),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _Field(
                          label: 'Arrival',
                          value: t.arriveTime,
                          labelColor: label,
                          detail: _detail,
                        ),
                      ),
                      Expanded(
                        child: _Field(
                          label: 'Class',
                          value: _classShort(t.ticketClass),
                          labelColor: label,
                          detail: _detail,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: (_detail ? 16 : 12) * scale),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _Field(
                          label: 'Coach',
                          value: t.coachesListLabel,
                          labelColor: label,
                          detail: _detail,
                        ),
                      ),
                      Expanded(
                        child: _Field(
                          label: 'Seat',
                          value: _detail ? t.seatsListLabel : t.seatSummary,
                          labelColor: label,
                          detail: _detail,
                        ),
                      ),
                    ],
                  ),
                  if (_detail) ...<Widget>[
                    SizedBox(height: 16 * scale),
                    _Field(
                      label: 'PNR',
                      value: t.pnr,
                      labelColor: label,
                      detail: _detail,
                    ),
                    SizedBox(height: 16 * scale),
                    _TicketCodes(
                      accent: style.accent,
                      onTap: onOpenCodes,
                    ),
                  ],
                ],
              ),
            ),
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
                          size: 18 * scale,
                          color: Colors.white.withValues(alpha: 0.70),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          t.operator.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13 * scale,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
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
                          color: Colors.white.withValues(alpha: 0.60),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
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
    // "Fri, 12 Apr" → "12 Apr" when possible
    final int i = full.indexOf(', ');
    return i >= 0 ? full.substring(i + 2) : full;
  }

  String _classShort(String ticketClass) {
    if (ticketClass.contains('2')) return '2A';
    if (ticketClass.contains('1')) return '1A';
    if (ticketClass.contains('3')) return '3A';
    if (ticketClass.toUpperCase().contains('SL')) return 'SL';
    if (ticketClass.toUpperCase().contains('CC')) return 'CC';
    return ticketClass;
  }
}

// ── Route hero (replaces movie poster) ────────────────────────────────────────

class _RouteHeroBand extends StatelessWidget {
  const _RouteHeroBand({
    required this.ticket,
    required this.style,
    required this.isActive,
    required this.height,
    required this.detail,
    required this.scale,
  });

  final MockTicket ticket;
  final TrainTicketStyle style;
  final bool isActive;
  final double height;
  final bool detail;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final MockTicket t = ticket;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.28),
                    style.glow.withValues(alpha: 0.22),
                    Colors.black.withValues(alpha: 0.45),
                  ],
                ),
              ),
            ),
            // Soft rail glow
            Positioned(
              left: -40,
              right: -40,
              bottom: -30,
              height: height * 0.55,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.bottomCenter,
                    radius: 0.9,
                    colors: <Color>[
                      style.accent.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: _OperatorChip(operator: t.operator),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: _StatusPill(isActive: isActive),
            ),
            // Source → destination
            Padding(
              padding: EdgeInsets.fromLTRB(
                16 * scale.clamp(0.85, 1.2),
                detail ? 44 : 40,
                16 * scale.clamp(0.85, 1.2),
                14,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: _StationColumn(
                          code: t.fromCode,
                          name: t.fromName,
                          time: t.departTime,
                          alignEnd: false,
                          detail: detail,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _RouteConnector(
                          duration: t.duration,
                          detail: detail,
                          accent: style.accent,
                        ),
                      ),
                      Expanded(
                        child: _StationColumn(
                          code: t.toCode,
                          name: t.toName,
                          time: t.arriveTime,
                          alignEnd: true,
                          detail: detail,
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
    );
  }
}

class _StationColumn extends StatelessWidget {
  const _StationColumn({
    required this.code,
    required this.name,
    required this.time,
    required this.alignEnd,
    required this.detail,
  });

  final String code;
  final String name;
  final String time;
  final bool alignEnd;
  final bool detail;

  @override
  Widget build(BuildContext context) {
    final CrossAxisAlignment cross =
        alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final TextAlign textAlign = alignEnd ? TextAlign.right : TextAlign.left;

    return Column(
      crossAxisAlignment: cross,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          code,
          textAlign: textAlign,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: detail ? 34 : 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.70),
            fontSize: detail ? 13 : 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          time,
          textAlign: textAlign,
          style: GoogleFonts.inter(
            color: const Color(0xFF8BB4FF),
            fontSize: detail ? 15 : 13,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _RouteConnector extends StatelessWidget {
  const _RouteConnector({
    required this.duration,
    required this.detail,
    required this.accent,
  });

  final String duration;
  final bool detail;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: detail ? 88 : 72,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                height: 1.2,
                color: Colors.white.withValues(alpha: 0.28),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(
                  Icons.train_rounded,
                  size: detail ? 16 : 14,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            duration,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: accent.withValues(alpha: 0.95),
              fontSize: detail ? 11 : 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OperatorChip extends StatelessWidget {
  const _OperatorChip({required this.operator});

  final String operator;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.train_rounded, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            operator,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.40),
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

// ── Fields & codes ────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    required this.labelColor,
    required this.detail,
  });

  final String label;
  final String value;
  final Color labelColor;
  final bool detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: GoogleFonts.inter(
            color: labelColor,
            fontSize: detail ? 12 : 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: detail ? 4 : 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: detail ? 16 : 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'QR / Barcode',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.50),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              TicketBarcodeStrip(height: MovieTicketMetrics.barcodeHeight),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  TicketQrTile(
                    size: 88,
                    accent: accent,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Tap to open full screen for scanning',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.45),
                    size: 22,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
