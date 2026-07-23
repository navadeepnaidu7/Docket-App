import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/movie_pass_models.dart';
import 'movie_ticket_chrome.dart';

/// Fullscreen scan view — code, movie name, and show time only.
class MovieTicketCodeScreen extends StatelessWidget {
  const MovieTicketCodeScreen({super.key, required this.pass});

  final MoviePass pass;

  bool get _isQr => pass.codeType == MovieTicketCodeType.qr;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color ink = scheme.onSurface;
    final Color muted = ink.withValues(alpha: 0.55);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, size: 24),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      pass.movieTitle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${pass.showDate} · ${pass.showTime}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 36),
                    if (_isQr)
                      Container(
                        width: 260,
                        height: 260,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: isDark ? 0.35 : 0.10),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const CustomPaint(painter: TicketQrPainter()),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 28,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: isDark ? 0.35 : 0.10),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const TicketBarcodeStrip(height: 72),
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
