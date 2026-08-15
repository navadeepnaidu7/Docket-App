import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/wallet/wallet_card_metrics.dart';
import '../../domain/movie_pass_models.dart';
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
    this.onOpenCodes,
  });

  final MoviePass pass;
  final MovieTicketDensity density;

  /// When true, keep brand colors even if the pass is expired (detail chrome).
  final bool useBrandColors;

  /// Optional width shrink vs parent (glance only).
  final double? widthFactor;

  /// Detail only — opens fullscreen QR/barcode viewer.
  final VoidCallback? onOpenCodes;

  bool get _isGlance => density == MovieTicketDensity.glance;

  /// The poster frame. Keyed because the two densities size it differently and
  /// that difference is deliberate — a test asserts it.
  @visibleForTesting
  static const Key heroKey = Key('movie_pass.hero');

  /// Shared stub height so notch + tear align for every brand.
  static double footerBodyHeight({
    required bool detail,
    required double scale,
  }) => (detail ? 82.0 : 64.0) * scale;

  @override
  Widget build(BuildContext context) {
    final bool isActive = pass.status == TicketStatus.active;
    final MovieBrandStyle style = MovieBrandStyle.forPass(
      pass,
      useBrandColors: useBrandColors,
    );
    final double scale = _isGlance ? MovieTicketMetrics.glanceTallScale : 1.0;
    final double footerHeight = footerBodyHeight(
      detail: !_isGlance,
      scale: scale,
    );
    final double notchFromBottom =
        footerHeight + (MovieTicketMetrics.tearHeight * scale) / 2;
    final double factor = widthFactor ?? (_isGlance ? 0.94 : 1.0);

    final Widget ticket = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MovieTicketMetrics.cornerR),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: style.bodyGradient.first.withValues(
              alpha: isActive ? 0.40 : 0.28,
            ),
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
          footerHeight: footerHeight,
          onOpenCodes: onOpenCodes,
        ),
      ),
    );

    if (factor >= 0.999) return ticket;

    return Align(
      child: FractionallySizedBox(widthFactor: factor, child: ticket),
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
    required this.footerHeight,
    this.onOpenCodes,
  });

  final MoviePass pass;
  final MovieBrandStyle style;
  final bool isActive;
  final double scale;
  final MovieTicketDensity density;
  final double footerHeight;
  final VoidCallback? onOpenCodes;

  bool get _detail => density == MovieTicketDensity.detail;

  bool get _brandLogoFooter =>
      pass.brand == MoviePassBrand.bookMyShow ||
      pass.brand == MoviePassBrand.district;

  @override
  Widget build(BuildContext context) {
    final Color label = Colors.white.withValues(alpha: style.labelAlpha);

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
                key: MovieTicketFace.heroKey,
                pass: pass,
                detail: _detail,
                // Detail shows the whole one-sheet; the glance card keeps a
                // fixed-height crop so the ticket detail below it still fits.
                height: _detail ? null : 190.0 * scale,
                aspectRatio: _detail ? MovieTicketMetrics.posterAspect : null,
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
                    SizedBox(height: 16 * scale),
                    _TicketCodes(
                      codeType: pass.codeType,
                      accent: style.accent,
                      onTap: onOpenCodes,
                    ),
                  ],
                ],
              ),
            ),
            TicketTearLine(height: MovieTicketMetrics.tearHeight * scale),
            if (_brandLogoFooter)
              SizedBox(
                width: double.infinity,
                height: footerHeight,
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
                            Icons.local_activity_rounded,
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
                          pass.sourcePlatform ?? 'Ticket',
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
    final int i = full.indexOf(', ');
    return i >= 0 ? full.substring(i + 2) : full;
  }
}

// ── Pieces ────────────────────────────────────────────────────────────────────

class _TicketCodes extends StatelessWidget {
  const _TicketCodes({
    required this.codeType,
    required this.accent,
    this.onTap,
  });

  final MovieTicketCodeType codeType;
  final Color accent;
  final VoidCallback? onTap;

  bool get _isQr => codeType == MovieTicketCodeType.qr;

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
                _isQr ? 'QR code' : 'Barcode',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.50),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              if (_isQr)
                Row(
                  children: <Widget>[
                    TicketQrTile(size: 88, accent: accent),
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
                )
              else
                Row(
                  children: <Widget>[
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Icon(
                        Icons.barcode_reader,
                        size: 28,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Open for scanning',
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

class _HeroBand extends StatelessWidget {
  const _HeroBand({
    super.key,
    required this.pass,
    required this.detail,
    this.height,
    this.aspectRatio,
  }) : assert(
         (height == null) != (aspectRatio == null),
         'Size the hero by exactly one of height or aspectRatio',
       );

  final MoviePass pass;
  final bool detail;

  /// Fixed height — the glance card's crop.
  final double? height;

  /// Width / height — the detail screen's whole-poster frame.
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    // Design probe: glance shows a transparent TMDB title logo on a dark plate when
    // logoUrl is present. Detail always uses the full one-sheet poster (or gradient).
    final bool logoGlance = !detail && pass.resolvedLogoUrl != null;
    final Widget art = logoGlance ? _buildLogoGlanceArt() : _buildPosterArt();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: aspectRatio != null
          ? AspectRatio(aspectRatio: aspectRatio!, child: art)
          : SizedBox(height: height, width: double.infinity, child: art),
    );
  }

  /// Full poster / fixture asset / gradient — detail screen and logo-less glance.
  Widget _buildPosterArt() {
    final String? asset = pass.resolvedPosterAsset;
    final String? url = pass.resolvedPosterUrl;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Painted first and never removed, so it shows through while the poster
        // loads and remains as the fallback if the poster fails.
        _buildGradientBackdrop(),
        if (asset != null)
          Image.asset(
            asset,
            fit: BoxFit.cover,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stackTrace) =>
                    const SizedBox.shrink(),
          )
        else if (url != null)
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 220),
                memCacheWidth: _decodeWidth(context, constraints.maxWidth),
                placeholder: (BuildContext context, String url) =>
                    const _PosterShimmer(),
                errorWidget: (BuildContext context, String url, Object error) =>
                    const SizedBox.shrink(),
              );
            },
          )
        else
          const SizedBox.shrink(),
        if (detail) _buildDetailScreenOverlay(),
      ],
    );
  }

  /// Glance-only: dark field + contained transparent logo.
  Widget _buildLogoGlanceArt() {
    final String logoUrl = pass.resolvedLogoUrl!;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const ColoredBox(color: Color(0xFF0B0B0E)),
        // Soft lift so the logo does not sit on pure void.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.95,
              colors: <Color>[
                const Color(0xFF1A1A22).withValues(alpha: 0.90),
                const Color(0xFF0B0B0E),
              ],
            ),
          ),
        ),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth * 0.10,
                vertical: constraints.maxHeight * 0.16,
              ),
              child: CachedNetworkImage(
                imageUrl: logoUrl,
                fit: BoxFit.contain,
                fadeInDuration: const Duration(milliseconds: 220),
                memCacheWidth: _decodeWidth(context, constraints.maxWidth),
                placeholder: (BuildContext context, String url) =>
                    const _PosterShimmer(),
                errorWidget: (BuildContext context, String url, Object error) {
                  // Logo miss → same path as a posterless glance (gradient only).
                  return _buildGradientBackdrop();
                },
              ),
            );
          },
        ),
      ],
    );
  }

  /// Pixel width to decode the poster at.
  ///
  /// The face is authored on a 382dp canvas and then scaled by a FittedBox
  /// ([WalletCardCanvas]) to whatever box the carousel gives it, so the width we lay out at
  /// is not the width we paint at. Size for the widest a card may get and convert to
  /// physical pixels. Flutter never upscales past the source, so over-asking on the detail
  /// screen — which has no FittedBox — costs nothing.
  int _decodeWidth(BuildContext context, double logicalWidth) {
    final double canvasUpscale =
        WalletCardMetrics.maxCardWidth / WalletCardMetrics.ticketCanvas.width;
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    // Capped at the largest size the image proxy serves.
    return math.min((logicalWidth * canvasUpscale * dpr).round(), 780);
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

/// Sweeping highlight shown while a poster downloads.
///
/// Hand-rolled rather than pulling in the `shimmer` package, matching how the ID card
/// skeletons in `ids_tab.dart` do it. The gradient backdrop paints underneath, so this only
/// needs to contribute the moving band.
class _PosterShimmer extends StatefulWidget {
  const _PosterShimmer();

  @override
  State<_PosterShimmer> createState() => _PosterShimmerState();
}

class _PosterShimmerState extends State<_PosterShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : 320;
          return AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) {
              final double shimmerX =
                  lerpDouble(-width, width, _controller.value) ?? 0;
              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ColoredBox(color: Colors.white.withValues(alpha: 0.06)),
                  Transform.translate(
                    offset: Offset(shimmerX, 0),
                    child: Transform.rotate(
                      angle: 0.35,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: <Color>[
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.14),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
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
