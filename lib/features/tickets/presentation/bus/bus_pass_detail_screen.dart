import 'package:flutter/material.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/wallet/wallet_card_metrics.dart';
import '../../domain/bus_pass_models.dart';
import '../../domain/pass_catalog.dart';
import '../pass_info_card.dart';
import '../pass_typography.dart';
import '../share/pass_share_actions.dart';
import 'bus_brand_style.dart';
import 'bus_ticket_code_screen.dart';
import 'bus_ticket_face.dart';

/// Fullscreen bus e-ticket — the face, the boarding code, then the detail.
///
/// Same shape as the movie detail screen: face at the top, a tap target that
/// opens the code fullscreen, and grouped label/value rows underneath.
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
                  const SizedBox(width: 48),
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
                    aspectRatio: WalletCardMetrics.ticketAspect,
                    child: WalletCardCanvas(
                      designSize: WalletCardMetrics.ticketCanvas,
                      child: BusTicketFace(
                        pass: pass,
                        useBrandColors: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _CodeButton(
                    pass: pass,
                    ink: ink,
                    muted: muted,
                    isDark: isDark,
                    onTap: () => _openCodes(context),
                  ),
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

/// Tap target that opens the boarding code fullscreen.
///
/// A row rather than an icon button: the brief rules out icons, and at a gate
/// this needs to be the obvious thing to press, not a glyph to hunt for.
class _CodeButton extends StatelessWidget {
  const _CodeButton({
    required this.pass,
    required this.ink,
    required this.muted,
    required this.isDark,
    required this.onTap,
  });

  final BusPass pass;
  final Color ink;
  final Color muted;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BusBrandStyle brand =
        BusBrandStyle.forPass(pass, useBrandColors: true);
    final Color surface =
        isDark ? AppTheme.elevated(Brightness.dark) : Colors.white;
    final Color border = ink.withValues(alpha: isDark ? 0.08 : 0.06);

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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Boarding code',
                        style: PassType.sectionTitle(ink),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Show this at the boarding point',
                        style: PassType.caption(muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: brand.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'View',
                    style: PassType.pill(Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
