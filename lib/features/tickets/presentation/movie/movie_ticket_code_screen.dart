import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/movie_pass_models.dart';
import '../pass_code_view.dart';

/// Fullscreen scan view — code, movie name, and show time only.
class MovieTicketCodeScreen extends StatelessWidget {
  const MovieTicketCodeScreen({super.key, required this.pass});

  final MoviePass pass;

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
                    PassCodePlate(code: pass.passCode),
                    if (pass.bookingId.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 18),
                      // The reference to read out when the scanner will not
                      // cooperate. Below the code, never inside its quiet zone.
                      Text(
                        pass.bookingId,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.robotoMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.4,
                          color: muted,
                        ),
                      ),
                    ],
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
