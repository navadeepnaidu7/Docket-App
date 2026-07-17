import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/haptics/haptic_service.dart';
import '../domain/movie_pass_models.dart';
import '../domain/ticket_models.dart' show TicketStatus;
import 'movie_pass_detail_screen.dart';

/// Vertical scale vs base ticket face (+20%).
const double _kTicketTall = 1.35;

/// Side notch radius (real clip, not painted).
const double _kNotchR = 10;

/// Card corner radius.
const double _kCornerR = 24;

/// Fixed footer stack used to place side notches:
/// perforation + barcode pad/bar/id + bottom pad  (all pre-scaled).
double get _footerHeight {
  final double p = 20 * _kTicketTall; // perforation row
  final double top = 8 * _kTicketTall;
  final double bar = 40 * _kTicketTall;
  final double gap = 6 * _kTicketTall;
  const double idLine = 14;
  final double bot = 14 * _kTicketTall;
  return p + top + bar + gap + idLine + bot;
}

/// Distance from ticket bottom to notch center.
double get _notchFromBottom => _footerHeight - (20 * _kTicketTall) / 2;

/// Movie e-ticket face for the Passes stack.
class WalletMovieCard extends StatefulWidget {
  const WalletMovieCard({super.key, required this.pass});

  final MoviePass pass;

  @override
  State<WalletMovieCard> createState() => _WalletMovieCardState();
}

class _WalletMovieCardState extends State<WalletMovieCard>
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
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.975).animate(
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
        builder: (_) => MoviePassDetailScreen(pass: widget.pass),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MoviePass p = widget.pass;
    final bool isActive = p.status == TicketStatus.active;
    final MovieBrandPalette palette = p.palette(forceActive: false);

    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) => _pressCtrl.reverse(),
      onTapCancel: () => _pressCtrl.reverse(),
      onTap: _openDetail,
      child: ScaleTransition(
        scale: _scaleAnim,
        // 7% narrower than the pass stack width.
        child: Align(
          child: FractionallySizedBox(
            widthFactor: 0.96,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_kCornerR),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: palette.top.withValues(alpha: isActive ? 0.40 : 0.28),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                    spreadRadius: -6,
                  ),
                ],
              ),
              // Real side cutouts via path clip — no painted fill color.
              child: ClipPath(
                clipper: _TicketShapeClipper(
                  cornerR: _kCornerR,
                  notchR: _kNotchR,
                  notchFromBottom: _notchFromBottom,
                ),
                child: _TicketFace(
                  pass: p,
                  palette: palette,
                  isActive: isActive,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Ticket face ───────────────────────────────────────────────────────────────

class _TicketFace extends StatelessWidget {
  const _TicketFace({
    required this.pass,
    required this.palette,
    required this.isActive,
  });

  final MoviePass pass;
  final MovieBrandPalette palette;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final MoviePassBrand brand = pass.brand;

    final List<Color> body = switch (brand) {
      MoviePassBrand.bookMyShow => const <Color>[
          Color(0xFFF84464),
          Color(0xFFC4242B),
        ],
      MoviePassBrand.district => const <Color>[
          Color(0xFF1C1C1E),
          Color(0xFF0E0E10),
        ],
      MoviePassBrand.universal => <Color>[palette.top, palette.bottom],
    };

    final Color label = Colors.white.withValues(
      alpha: brand == MoviePassBrand.district ? 0.50 : 0.60,
    );

    final double s = _kTicketTall;

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isActive
                    ? body
                    : const <Color>[Color(0xFF3A3A3C), Color(0xFF1C1C1E)],
              ),
            ),
          ),
        ),
        if (brand == MoviePassBrand.district && isActive)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ColoredBox(
              color: const Color(0xFFE23744),
              child: SizedBox(height: 4 * s),
            ),
          ),
        if (brand != MoviePassBrand.district)
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
                    palette.glow.withValues(alpha: 0.28),
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
                14 * s,
                (brand == MoviePassBrand.district ? 14 : 12) * s,
                14 * s,
                0,
              ),
              child: _HeroBand(
                pass: pass,
                brand: brand,
                isActive: isActive,
                height: 120 * s,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20 * s, 14 * s, 20 * s, 4 * s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _Presenter(brand: brand, isActive: isActive),
                  SizedBox(height: 4 * s),
                  Text(
                    pass.movieTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.55,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: 14 * s),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _Field(
                          label: 'Date',
                          value: _shortDate(pass.showDate),
                          labelColor: label,
                        ),
                      ),
                      Expanded(
                        child: _Field(
                          label: 'Time',
                          value: pass.showTime,
                          labelColor: label,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12 * s),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _Field(
                          label: 'Screen',
                          value: pass.screen,
                          labelColor: label,
                        ),
                      ),
                      Expanded(
                        child: _Field(
                          label: 'Seats',
                          value: pass.seatSummary,
                          labelColor: label,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12 * s),
                  _Field(
                    label: 'Place',
                    value: pass.cinemaName,
                    labelColor: label,
                    maxLines: 1,
                  ),
                ],
              ),
            ),

            // Dashed tear only — side holes come from ClipPath.
            SizedBox(
              height: 20 * s,
              width: double.infinity,
              child: const CustomPaint(painter: _DashPainter()),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(20 * s, 8 * s, 20 * s, 14 * s),
              child: Column(
                children: <Widget>[
                  _Barcode(height: 40 * s),
                  SizedBox(height: 6 * s),
                  SizedBox(
                    height: 14,
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

// ── Shape clipper (transparent side notches) ──────────────────────────────────

class _TicketShapeClipper extends CustomClipper<Path> {
  const _TicketShapeClipper({
    required this.cornerR,
    required this.notchR,
    required this.notchFromBottom,
  });

  final double cornerR;
  final double notchR;
  final double notchFromBottom;

  @override
  Path getClip(Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cy = (h - notchFromBottom).clamp(cornerR + notchR, h - cornerR - notchR);

    final Path path = Path()
      ..moveTo(cornerR, 0)
      ..lineTo(w - cornerR, 0)
      ..arcToPoint(Offset(w, cornerR), radius: Radius.circular(cornerR))
      ..lineTo(w, cy - notchR)
      // Right notch — cut into ticket (open to the outside)
      ..arcToPoint(
        Offset(w, cy + notchR),
        radius: Radius.circular(notchR),
        clockwise: false,
      )
      ..lineTo(w, h - cornerR)
      ..arcToPoint(Offset(w - cornerR, h), radius: Radius.circular(cornerR))
      ..lineTo(cornerR, h)
      ..arcToPoint(Offset(0, h - cornerR), radius: Radius.circular(cornerR))
      ..lineTo(0, cy + notchR)
      // Left notch
      ..arcToPoint(
        Offset(0, cy - notchR),
        radius: Radius.circular(notchR),
        clockwise: false,
      )
      ..lineTo(0, cornerR)
      ..arcToPoint(Offset(cornerR, 0), radius: Radius.circular(cornerR))
      ..close();

    return path;
  }

  @override
  bool shouldReclip(covariant _TicketShapeClipper old) =>
      old.cornerR != cornerR ||
      old.notchR != notchR ||
      old.notchFromBottom != notchFromBottom;
}

// ── Hero ──────────────────────────────────────────────────────────────────────

class _HeroBand extends StatelessWidget {
  const _HeroBand({
    required this.pass,
    required this.brand,
    required this.isActive,
    required this.height,
  });

  final MoviePass pass;
  final MoviePassBrand brand;
  final bool isActive;
  final double height;

  @override
  Widget build(BuildContext context) {
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
                  colors: pass.posterHint.gradient,
                ),
              ),
            ),
            Positioned(
              top: -24,
              left: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 28,
                  color: Colors.white.withValues(alpha: 0.90),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: switch (brand) {
                    MoviePassBrand.bookMyShow => const Color(0xFFF84464),
                    MoviePassBrand.district => const Color(0xFFE23744),
                    MoviePassBrand.universal =>
                      Colors.white.withValues(alpha: 0.20),
                  },
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  switch (brand) {
                    MoviePassBrand.bookMyShow => 'bookmyshow',
                    MoviePassBrand.district => 'district',
                    MoviePassBrand.universal => 'E-Ticket',
                  },
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing:
                        brand == MoviePassBrand.bookMyShow ? -0.2 : 0.1,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Text bits ─────────────────────────────────────────────────────────────────

class _Presenter extends StatelessWidget {
  const _Presenter({required this.brand, required this.isActive});

  final MoviePassBrand brand;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final String line = switch (brand) {
      MoviePassBrand.bookMyShow => 'BookMyShow',
      MoviePassBrand.district => 'district by Zomato',
      MoviePassBrand.universal => 'Movie Ticket',
    };

    if (brand == MoviePassBrand.district) {
      return Row(
        children: <Widget>[
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFE23744) : Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text(
              'd',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            line,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Text(
      line,
      style: GoogleFonts.inter(
        color: Colors.white.withValues(alpha: 0.75),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    required this.labelColor,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final Color labelColor;
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
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

// ── Dashed tear (no side fill) ────────────────────────────────────────────────

class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint dash = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    const double inset = _kNotchR + 8;
    double x = inset;
    final double y = size.height / 2;
    while (x < size.width - inset) {
      canvas.drawLine(Offset(x, y), Offset(x + 5, y), dash);
      x += 10;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Barcode extends StatelessWidget {
  const _Barcode({this.height = 40});
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: const CustomPaint(painter: _BarcodePainter()),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  const _BarcodePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = Colors.white.withValues(alpha: 0.90);
    const List<double> widths = <double>[
      1.5, 1, 2.6, 1, 1, 3, 1.5, 1, 2.1, 1, 1.5, 2.6, 1, 3, 1, 1.5, 1, 2.1, 1,
      2.6, 1, 1, 3, 1.5, 1, 2.1, 1.5, 1, 1, 2.6, 1, 1.5, 3, 1, 2.1, 1, 1.5, 1,
      2.6, 1, 2.1, 1, 1, 3, 1.5, 2.6, 1, 1, 2.1, 1.5,
    ];
    double x = 0;
    int i = 0;
    while (x < size.width) {
      final double w = widths[i % widths.length];
      if (i.isEven) {
        canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      }
      x += w + 1.15;
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
