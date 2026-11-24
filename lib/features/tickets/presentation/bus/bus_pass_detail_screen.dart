import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/wallet/wallet_card_metrics.dart';
import '../../domain/bus_pass_models.dart';
import '../../domain/pass_catalog.dart';
import '../../domain/pass_code.dart';
import '../pass_code_row.dart';
import '../pass_code_screen.dart';
import '../pass_info_card.dart';
import '../pass_detail_header.dart';
import '../share/pass_share_actions.dart';
import 'bus_ticket_code_screen.dart';
import 'bus_ticket_face.dart';

/// Fullscreen bus e-ticket — the face, the boarding code, then the detail.
///
/// The face is the wallet glance card unchanged; the face never draws a code.
/// Under it, a movie-style row shows the real code on a white tile and opens
/// it fullscreen. Grouped label/value rows follow.
class BusPassDetailScreen extends StatelessWidget {
  const BusPassDetailScreen({super.key, required this.pass});

  final BusPass pass;

  void _openCodes(BuildContext context) {
    showPassCodeScreen(
      context,
      builder: (_) => BusTicketCodeScreen(pass: pass),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color ink = scheme.onSurface;
    final Color muted = AppTokens.secondaryLabel(scheme);

    final String duration = busDurationLabel(pass);
    final int dayOffset = busArrivalDayOffset(pass);
    final String arrival = dayOffset > 0
        ? '${pass.arriveTime}  (+$dayOffset day${dayOffset == 1 ? '' : 's'})'
        : pass.arriveTime;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            PassDetailHeader(
              item: BusPassItem(pass),
              title: 'E-Ticket',
              copyLabel: 'Copy booking ID',
              copyValue: pass.bookingId,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                physics: const BouncingScrollPhysics(),
                children: <Widget>[
                  // The face is authored at a fixed canvas, so it needs the
                  // same scale-to-fit wrapper the wallet card uses.
                  AspectRatio(
                    aspectRatio: WalletCardMetrics.trainAspect,
                    child: WalletCardCanvas(
                      designSize: WalletCardMetrics.trainCanvas,
                      child: BusTicketFace(pass: pass, useBrandColors: true),
                    ),
                  ),
                  // Omitted entirely when the pass has no code: a row that
                  // opens an empty plate is worse than no row.
                  if (pass.passCode case final PassCode code) ...<Widget>[
                    const SizedBox(height: 18),
                    PassCodeRow(code: code, onTap: () => _openCodes(context)),
                  ],
                  const SizedBox(height: 12),
                  PassInfoCard(
                    title: 'Journey',
                    ink: ink,
                    muted: muted,
                    isDark: isDark,
                    rows: <(String, String)>[
                      ('Operator', pass.operator),
                      ('Date', pass.date),
                      ('Departure', pass.departTime),
                      ('Arrival', arrival),
                      ('Duration', duration),
                      ('Fare', pass.fare),
                    ],
                  ),
                  const SizedBox(height: 12),
                  PassInfoCard(
                    title: 'Boarding',
                    ink: ink,
                    muted: muted,
                    isDark: isDark,
                    rows: <(String, String)>[
                      ('Boarding', pass.boardingLocation),
                      ('Point', pass.boardingPoint),
                      ('Platform', pass.platform),
                      ('Drop', pass.dropLocation),
                      ('Booking ID', pass.bookingId),
                    ],
                  ),
                  if (pass.passengers.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    PassInfoCard(
                      title: pass.passengers.length == 1
                          ? 'Passenger'
                          : 'Passengers',
                      ink: ink,
                      muted: muted,
                      isDark: isDark,
                      labelWidth: 150,
                      rows: <(String, String)>[
                        for (final BusPassenger p in pass.passengers)
                          (p.name, p.seat.isEmpty ? '—' : 'Seat ${p.seat}'),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  PassShareActions(item: BusPassItem(pass)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
