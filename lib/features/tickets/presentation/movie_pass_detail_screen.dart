import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../application/movie_artwork_blend_provider.dart';
import '../domain/movie_pass_models.dart';
import '../domain/pass_catalog.dart';
import 'movie/movie_ticket_code_screen.dart';
import 'pass_code_screen.dart';
import 'pass_info_card.dart';
import 'movie/movie_ticket_face.dart';
import 'pass_detail_header.dart';
import 'share/pass_share_actions.dart';

/// Fullscreen e-ticket detail — shared face + booking/cinema sections.
class MoviePassDetailScreen extends ConsumerWidget {
  const MoviePassDetailScreen({super.key, required this.pass});

  final MoviePass pass;

  void _openCodes(BuildContext context, MoviePass p) {
    showPassCodeScreen(context, builder: (_) => MovieTicketCodeScreen(pass: p));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            PassDetailHeader(
              item: MoviePassItem(p),
              title: 'E-Ticket',
              copyLabel: 'Copy booking ID',
              copyValue: p.bookingId,
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
                    artworkBlend: ref.watch(movieArtworkBlendProvider),
                    onOpenCodes: () => _openCodes(context, p),
                  ),
                  const SizedBox(height: 18),
                  PassInfoCard(
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
                  PassInfoCard(
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
                  const SizedBox(height: 24),
                  PassShareActions(item: MoviePassItem(p)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
