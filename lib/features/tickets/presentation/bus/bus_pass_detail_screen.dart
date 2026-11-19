import 'package:flutter/material.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/wallet/wallet_card_metrics.dart';
import '../../domain/bus_pass_models.dart';
import '../../domain/pass_catalog.dart';
import '../../domain/pass_code.dart';
import '../pass_code_view.dart';
import '../pass_info_card.dart';
import '../pass_remove_flow.dart';
import '../pass_typography.dart';
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
    HapticService.tap();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => BusTicketCodeScreen(pass: pass),
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
                      style: PassType.screenTitle(ink),
                    ),
                  ),
                  PassOverflowButton(
                    item: BusPassItem(pass),
                    copyLabel: 'Copy booking ID',
                    copyValue: pass.bookingId,
                  ),
                ],
              ),
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
                    _CodeRow(
                      code: code,
                      ink: ink,
                      muted: muted,
                      isDark: isDark,
                      onTap: () => _openCodes(context),
                    ),
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

/// The ticket's code on a white tile, opening it fullscreen — the movie
/// face's code row, set on a card because it sits under the face rather than
/// on it.
class _CodeRow extends StatelessWidget {
  const _CodeRow({
    required this.code,
    required this.ink,
    required this.muted,
    required this.isDark,
    required this.onTap,
  });

  final PassCode code;
  final Color ink;
  final Color muted;
  final bool isDark;
  final VoidCallback onTap;

  /// Side of the white tile. Linear symbols get the same footprint so the row
  /// keeps its height whatever the ticket carries.
  static const double _tile = 88;

  @override
  Widget build(BuildContext context) {
    final Color surface = isDark
        ? AppTheme.elevated(Brightness.dark)
        : Colors.white;
    final Color border = ink.withValues(alpha: isDark ? 0.08 : 0.06);
    final bool isQr = code.format == PassCodeFormat.qr;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                Container(
                  width: _tile,
                  height: _tile,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Center(
                    child: PassCodeView(code: code, width: _tile - 16),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        isQr ? 'QR code' : 'Barcode',
                        style: PassType.sectionTitle(ink),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to open full screen for scanning',
                        style: PassType.caption(muted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: muted, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
