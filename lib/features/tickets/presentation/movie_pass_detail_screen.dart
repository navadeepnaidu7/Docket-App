import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/haptics/haptic_service.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/movie_pass_models.dart';
import 'movie/movie_ticket_code_screen.dart';
import 'movie/movie_ticket_face.dart';

/// Fullscreen e-ticket detail — shared face + booking/cinema sections.
class MoviePassDetailScreen extends StatelessWidget {
  const MoviePassDetailScreen({super.key, required this.pass});

  final MoviePass pass;

  void _openCodes(BuildContext context, MoviePass p) {
    HapticService.tap();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => MovieTicketCodeScreen(pass: p),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color ink = scheme.onSurface;
    final Color muted = AppTokens.secondaryLabel(scheme);
    final MoviePass p = pass;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                  MovieTicketFace(
                    pass: p,
                    density: MovieTicketDensity.detail,
                    useBrandColors: true,
                    onOpenCodes: () => _openCodes(context, p),
                  ),
                  const SizedBox(height: 18),
                  _InfoCard(
                    title: 'Booking Details',
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
                    title: 'Cinema Details',
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
