import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/movie_pass_models.dart';
import '../../domain/ticket_models.dart' show TicketStatus;
import 'movie_brand_style.dart';
import 'movie_ticket_chrome.dart';

/// How dense the shared e-ticket face should render.
enum MovieTicketDensity {
  /// Passes stack — compact ticket stub.
  glance,

  /// Fullscreen detail — roomier type and optional seats/QR.
  detail,
}

/// Single movie e-ticket face for wallet + detail screens.
class MovieTicketFace extends StatelessWidget {
  const MovieTicketFace({
    super.key,
    required this.pass,
    required this.density,
    this.useBrandColors = false,
    this.widthFactor,
  });

  final MoviePass pass;
  final MovieTicketDensity density;

  /// When true, keep brand colors even if the pass is expired (detail chrome).
  final bool useBrandColors;

  /// Optional width shrink vs parent (glance only).
  final double? widthFactor;

  bool get _isGlance => density == MovieTicketDensity.glance;

  @override
  Widget build(BuildContext context) {
    final bool isActive = pass.status == TicketStatus.active;
    final MovieBrandStyle style = MovieBrandStyle.forPass(
      pass,
      useBrandColors: useBrandColors,
    );
    final double scale =
        _isGlance ? MovieTicketMetrics.glanceTallScale : 1.0;
    final bool detail = !_isGlance;
    final bool qrStub = detail && style.showQrInStub;

    final double footerHeight = (pass.brand == MoviePassBrand.bookMyShow || pass.brand == MoviePassBrand.district)
        ? (detail ? 82.0 : 64.0) * scale
        : (qrStub
            ? MovieTicketMetrics.detailQrFooterBody
            : MovieTicketMetrics.footerBodyHeight(scale: scale));

    final double notchFromBottom = footerHeight + (MovieTicketMetrics.tearHeight * scale) / 2;
    final double factor = widthFactor ??
        (_isGlance ? 0.94 : 1.0);

    final Widget ticket = Container(
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
          pass: pass,
          style: style,
          isActive: isActive,
          scale: scale,
          density: density,
        ),
      ),
    );

    if (factor >= 0.999) return ticket;

    return Align(
      child: FractionallySizedBox(
        widthFactor: factor,
        child: ticket,
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _TicketBody extends StatelessWidget {
  const _TicketBody({
    required this.pass,
    required this.style,
    required this.isActive,
    required this.scale,
    required this.density,
  });

  final MoviePass pass;
  final MovieBrandStyle style;
  final bool isActive;
  final double scale;
  final MovieTicketDensity density;

  bool get _detail => density == MovieTicketDensity.detail;

  @override
  Widget build(BuildContext context) {
    final Color label =
        Colors.white.withValues(alpha: style.labelAlpha);

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
        if (style.showTopHairline)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ColoredBox(
              color: style.accent,
              child: SizedBox(height: 4 * scale),
            ),
          ),
        if (!style.showTopHairline)
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
                (style.showTopHairline ? 14 : 12) * scale,
                14 * scale,
                0,
              ),
              child: _HeroBand(
                pass: pass,
                style: style,
                isActive: isActive,
                height: (_detail ? 260.0 : 190.0) * scale,
                detail: _detail,
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
                  // Title starts directly at the top for clean e-ticket look
                  Text(
                    pass.movieTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: _detail ? 26 : 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.55,
                      height: 1.15,
                    ),
                  ),
                  if (_detail) ...<Widget>[
                    SizedBox(height: 4 * scale),
                    Text(
                      '${pass.format}  ·  ${pass.language}  ·  ${pass.certification}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: label,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  SizedBox(height: (_detail ? 18 : 14) * scale),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _Field(
                          label: 'Date',
                          value: _shortDate(pass.showDate),
                          labelColor: label,
                          detail: _detail,
                        ),
                      ),
                      Expanded(
                        child: _Field(
                          label: 'Time',
                          value: pass.showTime,
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
                          label: 'Screen',
                          value: pass.screen,
                          labelColor: label,
                          detail: _detail,
                        ),
                      ),
                      Expanded(
                        child: _Field(
                          label: 'Seats',
                          value: _detail
                              ? pass.seatListLabel
                              : pass.seatSummary,
                          labelColor: label,
                          detail: _detail,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: (_detail ? 16 : 12) * scale),
                  _Field(
                    label: 'Place',
                    value: _detail
                        ? '${pass.cinemaName}\n${pass.cinemaAddress}'
                        : pass.cinemaName,
                    labelColor: label,
                    maxLines: _detail ? 3 : 1,
                    detail: _detail,
                  ),
                  if (_detail) ...<Widget>[
                    SizedBox(height: 14 * scale),
                    _SeatChips(seats: pass.seats, accent: style.accent),
                  ],
                ],
              ),
            ),
            TicketTearLine(height: MovieTicketMetrics.tearHeight * scale),
            if (style.showQrInStub && _detail)
              SizedBox(
                height: MovieTicketMetrics.detailQrFooterBody,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    MovieTicketMetrics.footerPadTop,
                    20,
                    MovieTicketMetrics.footerPadBottom,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: SizedBox(
                          height: MovieTicketMetrics.detailQrContentH,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.max,
                            children: <Widget>[
                              Text(
                                pass.bookingId,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.robotoMono(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.confirmation_number_outlined,
                                    size: 14 * scale,
                                    color: Colors.white.withValues(alpha: 0.70),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'E-TICKET',
                                    style: GoogleFonts.inter(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 11 * scale,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      TicketQrTile(
                        size: MovieTicketMetrics.detailQrTile,
                        accent: style.accent,
                      ),
                    ],
                  ),
                ),
              )
            else if (pass.brand == MoviePassBrand.bookMyShow || pass.brand == MoviePassBrand.district)
              SizedBox(
                width: double.infinity,
                height: (_detail ? 82.0 : 64.0) * scale,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    if (pass.brand == MoviePassBrand.district)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              radius: 0.9,
                              colors: <Color>[
                                const Color(0xFFC948FF).withValues(alpha: 0.35),
                                const Color(0xFFA53BFF).withValues(alpha: 0.12),
                                const Color(0x00A53BFF),
                              ],
                              stops: const <double>[0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                    SvgPicture.asset(
                      style.footerLogoAsset ?? style.logoAsset!,
                      height: (_detail ? 50.0 : 40.0) * scale,
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20 * scale,
                  MovieTicketMetrics.footerPadTop * scale,
                  20 * scale,
                  MovieTicketMetrics.footerPadBottom * scale,
                ),
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          Icons.confirmation_number_outlined,
                          size: 18 * scale,
                          color: Colors.white.withValues(alpha: 0.70),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'E-TICKET',
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
                        pass.bookingId,
                        style: GoogleFonts.robotoMono(
                          color: Colors.white.withValues(alpha: 0.60),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                          height: 1.0,
                        ),
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

  String _shortDate(String full) {
    final int i = full.indexOf(', ');
    return i >= 0 ? full.substring(i + 2) : full;
  }
}

// ── Pieces ────────────────────────────────────────────────────────────────────

class _HeroBand extends StatelessWidget {
  const _HeroBand({
    required this.pass,
    required this.style,
    required this.isActive,
    required this.height,
    required this.detail,
  });

  final MoviePass pass;
  final MovieBrandStyle style;
  final bool isActive;
  final double height;
  final bool detail;

  @override
  Widget build(BuildContext context) {
    if (pass.brand == MoviePassBrand.bookMyShow || pass.brand == MoviePassBrand.district || pass.brand == MoviePassBrand.universal) {
      final String? asset = pass.posterAsset;
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: asset != null
              ? Image.asset(
                  asset,
                  fit: BoxFit.cover,
                  errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                    return _buildFallback(context);
                  },
                )
              : Image.network(
                  pass.posterUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.30)),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                    return _buildFallback(context);
                  },
                ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _buildGradientBackdrop(),
            _buildPlayOverlay(),
            if (detail) _buildDetailScreenOverlay(),
            Positioned(
              top: 10,
              left: 10,
              child: _BrandChip(style: style),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: _StatusPill(isActive: isActive),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallback(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _buildGradientBackdrop(),
        _buildPlayOverlay(),
      ],
    );
  }

  Widget _buildGradientBackdrop() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: pass.posterHint.gradient,
        ),
      ),
    );
  }

  Widget _buildPlayOverlay() {
    return Center(
      child: Container(
        width: detail ? 56 : 48,
        height: detail ? 56 : 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.28),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
          ),
        ),
        child: Icon(
          Icons.play_arrow_rounded,
          size: detail ? 32 : 28,
          color: Colors.white.withValues(alpha: 0.90),
        ),
      ),
    );
  }

  Widget _buildDetailScreenOverlay() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 28, 14, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Colors.transparent,
              Colors.black.withValues(alpha: 0.50),
            ],
          ),
        ),
        child: Text(
          pass.screen,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _BrandChip extends StatelessWidget {
  const _BrandChip({required this.style});
  final MovieBrandStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: style.chipBackground,
        borderRadius: BorderRadius.circular(7),
        border: style.chipBorder != null
            ? Border.all(
                color: style.chipBorder!.withValues(alpha: 0.60),
              )
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (style.logoAsset != null) ...<Widget>[
            SvgPicture.asset(
              style.logoAsset!,
              width: 11,
              height: 11,
              colorFilter: ColorFilter.mode(
                style.logoTint ?? Colors.white,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            style.chipLabel,
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

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    required this.labelColor,
    required this.detail,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final Color labelColor;
  final bool detail;
  final int maxLines;

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
          maxLines: maxLines,
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

class _SeatChips extends StatelessWidget {
  const _SeatChips({required this.seats, required this.accent});

  final List<MovieSeat> seats;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Seats',
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.50),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: seats
              .map(
                (MovieSeat s) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accent.withValues(alpha: 0.40)),
                  ),
                  child: Text(
                    s.label,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
