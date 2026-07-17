import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/haptics/haptic_service.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/movie_pass_models.dart';
import '../domain/ticket_models.dart' show TicketStatus;

/// Fullscreen e-ticket detail — same full-ticket language as the wallet face.
class MoviePassDetailScreen extends StatelessWidget {
  const MoviePassDetailScreen({super.key, required this.pass});

  final MoviePass pass;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final MoviePass p = pass;
    final bool isActive = p.status == TicketStatus.active;
    final MovieBrandPalette palette = p.palette(forceActive: true);
    final Color ink = scheme.onSurface;
    final Color muted = AppTokens.secondaryLabel(scheme);
    final Color scaffold = theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: scaffold,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      'E-Ticket',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: ink,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz_rounded, size: 24),
                    onPressed: () {
                      HapticService.select();
                      _showActions(context, p);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                physics: const BouncingScrollPhysics(),
                children: <Widget>[
                  _DetailTicket(
                    pass: p,
                    palette: palette,
                    isActive: isActive,
                    cutoutColor: scaffold,
                  ),
                  const SizedBox(height: 18),
                  _InfoCard(
                    title: 'Booking',
                    ink: ink,
                    muted: muted,
                    isDark: isDark,
                    rows: <(String, String)>[
                      ('Booking ID', p.bookingId),
                      ('Order ID', p.orderId),
                      ('Format', p.format),
                      ('Language', p.language),
                      ('Runtime', p.runtime),
                      ('Certification', p.certification),
                      ('Check-in', p.gateType),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _InfoCard(
                    title: 'Cinema',
                    ink: ink,
                    muted: muted,
                    isDark: isDark,
                    rows: <(String, String)>[
                      ('Venue', p.cinemaName),
                      ('Address', p.cinemaAddress),
                      ('Screen', p.screen),
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

  void _showActions(BuildContext context, MoviePass p) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copy booking ID'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: p.bookingId));
                  Navigator.pop(ctx);
                  HapticService.confirm();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Booking ID copied')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('Share ticket'),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Main ticket card ──────────────────────────────────────────────────────────

class _DetailTicket extends StatelessWidget {
  const _DetailTicket({
    required this.pass,
    required this.palette,
    required this.isActive,
    required this.cutoutColor,
  });

  final MoviePass pass;
  final MovieBrandPalette palette;
  final bool isActive;
  final Color cutoutColor;

  @override
  Widget build(BuildContext context) {
    final MoviePassBrand brand = pass.brand;

    final List<Color> bodyGradient = switch (brand) {
      MoviePassBrand.bookMyShow => const <Color>[
          Color(0xFFF84464),
          Color(0xFFC4242B),
          Color(0xFF9B1B24),
        ],
      MoviePassBrand.district => const <Color>[
          Color(0xFF1C1C1E),
          Color(0xFF111113),
          Color(0xFF0A0A0B),
        ],
      MoviePassBrand.universal => <Color>[palette.top, palette.bottom],
    };

    final Color labelMuted = Colors.white.withValues(
      alpha: brand == MoviePassBrand.district ? 0.48 : 0.58,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: bodyGradient.first.withValues(alpha: 0.38),
            blurRadius: 28,
            offset: const Offset(0, 14),
            spreadRadius: -6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isActive
                        ? bodyGradient
                        : const <Color>[Color(0xFF3A3A3C), Color(0xFF1C1C1E)],
                  ),
                ),
              ),
            ),
            if (brand == MoviePassBrand.district && isActive)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ColoredBox(
                  color: Color(0xFFE23744),
                  child: SizedBox(height: 5),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    brand == MoviePassBrand.district ? 18 : 16,
                    16,
                    0,
                  ),
                  child: _Hero(
                    pass: pass,
                    brand: brand,
                    isActive: isActive,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _Presenter(brand: brand, isActive: isActive),
                      const SizedBox(height: 6),
                      Text(
                        pass.movieTitle,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.7,
                          height: 1.12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${pass.format}  ·  ${pass.language}  ·  ${pass.certification}',
                        style: GoogleFonts.inter(
                          color: labelMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _Field(
                              label: 'Date',
                              value: _shortDate(pass.showDate),
                              muted: labelMuted,
                            ),
                          ),
                          Expanded(
                            child: _Field(
                              label: 'Time',
                              value: pass.showTime,
                              muted: labelMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _Field(
                              label: brand == MoviePassBrand.district
                                  ? 'Seats'
                                  : 'Check In Type',
                              value: brand == MoviePassBrand.district
                                  ? pass.seatListLabel
                                  : pass.gateType,
                              muted: labelMuted,
                            ),
                          ),
                          Expanded(
                            child: _Field(
                              label: 'Order ID',
                              value: pass.orderId,
                              muted: labelMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _Field(
                        label: 'Place',
                        value: '${pass.cinemaName}\n${pass.cinemaAddress}',
                        muted: labelMuted,
                        maxLines: 4,
                      ),
                      if (brand != MoviePassBrand.universal) ...<Widget>[
                        const SizedBox(height: 16),
                        _Seats(
                          seats: pass.seats,
                          brand: brand,
                          isActive: isActive,
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                SizedBox(
                  height: 22,
                  child: CustomPaint(
                    painter: _PerforationPainter(cutoutColor: cutoutColor),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
                  child: brand == MoviePassBrand.district
                      ? Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'BOOKING ID',
                                    style: GoogleFonts.inter(
                                      color: labelMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    pass.bookingId,
                                    style: GoogleFonts.robotoMono(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const SizedBox(
                                    height: 40,
                                    width: double.infinity,
                                    child: CustomPaint(painter: _BarcodePainter()),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            _Qr(size: 88, accent: palette.accent),
                          ],
                        )
                      : Column(
                          children: <Widget>[
                            const SizedBox(
                              height: 56,
                              width: double.infinity,
                              child: CustomPaint(painter: _BarcodePainter()),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              pass.bookingId,
                              style: GoogleFonts.robotoMono(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.6,
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
    );
  }

  String _shortDate(String full) {
    final int i = full.indexOf(', ');
    return i >= 0 ? full.substring(i + 2) : full;
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.pass,
    required this.brand,
    required this.isActive,
  });

  final MoviePass pass;
  final MoviePassBrand brand;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9.5,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
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
              top: -20,
              left: -30,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 40,
                  color: Colors.white.withValues(alpha: 0.90),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 32, 14, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
                child: Text(
                  pass.screen,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: switch (brand) {
                    MoviePassBrand.bookMyShow => const Color(0xFFF84464),
                    MoviePassBrand.district => const Color(0xFFE23744),
                    MoviePassBrand.universal =>
                      Colors.white.withValues(alpha: 0.22),
                  },
                  borderRadius: BorderRadius.circular(8),
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
                  ),
                ),
              ),
            ),
            if (!isActive)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'EXPIRED',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Presenter extends StatelessWidget {
  const _Presenter({required this.brand, required this.isActive});
  final MoviePassBrand brand;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final String line = switch (brand) {
      MoviePassBrand.bookMyShow => 'BookMyShow presents',
      MoviePassBrand.district => 'district by Zomato',
      MoviePassBrand.universal => 'Movie Ticket',
    };

    if (brand == MoviePassBrand.district) {
      return Row(
        children: <Widget>[
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFE23744) : Colors.white24,
              borderRadius: BorderRadius.circular(5),
            ),
            alignment: Alignment.center,
            child: Text(
              'd',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            line,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Text(
      line,
      style: GoogleFonts.inter(
        color: Colors.white.withValues(alpha: 0.80),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    required this.muted,
    this.maxLines = 2,
  });

  final String label;
  final String value;
  final Color muted;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: GoogleFonts.inter(
            color: muted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _Seats extends StatelessWidget {
  const _Seats({
    required this.seats,
    required this.brand,
    required this.isActive,
  });

  final List<MovieSeat> seats;
  final MoviePassBrand brand;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final Color accent = brand == MoviePassBrand.district
        ? (isActive ? const Color(0xFFE23744) : Colors.white)
        : Colors.white;

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

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.ink,
    required this.muted,
    required this.isDark,
    required this.rows,
  });

  final String title;
  final Color ink;
  final Color muted;
  final bool isDark;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final Color surface =
        isDark ? AppTheme.elevated(Brightness.dark) : Colors.white;
    final Color border = ink.withValues(alpha: isDark ? 0.08 : 0.06);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: GoogleFonts.inter(
              color: ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          ...rows.map(
            ((String, String) r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 110,
                    child: Text(
                      r.$1,
                      style: GoogleFonts.inter(
                        color: muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      r.$2,
                      style: GoogleFonts.inter(
                        color: ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Qr extends StatelessWidget {
  const _Qr({required this.size, required this.accent});
  final double size;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.30),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _FakeQrPainter(color: const Color(0xFF111113)),
      ),
    );
  }
}

class _PerforationPainter extends CustomPainter {
  _PerforationPainter({required this.cutoutColor});
  final Color cutoutColor;

  @override
  void paint(Canvas canvas, Size size) {
    const double r = 11;
    final Paint cut = Paint()..color = cutoutColor;
    canvas.drawCircle(Offset(0, size.height / 2), r, cut);
    canvas.drawCircle(Offset(size.width, size.height / 2), r, cut);
    final Paint dash = Paint()
      ..color = Colors.white.withValues(alpha: 0.38)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    double x = r + 8;
    final double y = size.height / 2;
    while (x < size.width - r - 8) {
      canvas.drawLine(Offset(x, y), Offset(x + 5, y), dash);
      x += 10;
    }
  }

  @override
  bool shouldRepaint(covariant _PerforationPainter old) =>
      old.cutoutColor != cutoutColor;
}

class _BarcodePainter extends CustomPainter {
  const _BarcodePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = Colors.white.withValues(alpha: 0.92);
    const List<double> widths = <double>[
      1.6, 1, 2.8, 1, 1, 3.2, 1.6, 1, 2.2, 1, 1.6, 2.8, 1, 3.2, 1, 1.6, 1, 2.2,
      1, 2.8, 1, 1, 3.2, 1.6, 1, 2.2, 1.6, 1, 1, 2.8, 1, 1.6, 3.2, 1, 2.2, 1,
      1.6, 1, 2.8, 1, 2.2, 1, 1, 3.2, 1.6, 2.8, 1, 1, 2.2, 1.6,
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

class _FakeQrPainter extends CustomPainter {
  _FakeQrPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()..color = color;
    const int n = 13;
    final double cell = size.width / n;
    void finder(int ox, int oy) {
      for (int y = 0; y < 3; y++) {
        for (int x = 0; x < 3; x++) {
          if (x == 0 || x == 2 || y == 0 || y == 2 || (x == 1 && y == 1)) {
            canvas.drawRect(
              Rect.fromLTWH((ox + x) * cell, (oy + y) * cell, cell, cell),
              p,
            );
          }
        }
      }
    }

    finder(0, 0);
    finder(n - 3, 0);
    finder(0, n - 3);
    int seed = 97;
    for (int y = 0; y < n; y++) {
      for (int x = 0; x < n; x++) {
        final bool inFinder = (x < 4 && y < 4) ||
            (x >= n - 4 && y < 4) ||
            (x < 4 && y >= n - 4);
        if (inFinder) continue;
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        if (seed % 3 != 0) {
          canvas.drawRect(
            Rect.fromLTWH(x * cell, y * cell, cell * 0.9, cell * 0.9),
            p,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FakeQrPainter old) => old.color != color;
}
