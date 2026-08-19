import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/wallet/wallet_card_metrics.dart';
import '../../../../shared/widgets/studio_backdrop.dart';
import '../../domain/bus_pass_models.dart';
import '../pass_typography.dart';
import 'bus_ticket_face.dart';

class BusPassDetailScreen extends StatelessWidget {
  const BusPassDetailScreen({super.key, required this.pass});

  final BusPass pass;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: <Widget>[
          const StudioBackdrop(),
          SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      Expanded(
                        child: Text(
                          pass.operator.trim().isEmpty ? 'Bus' : pass.operator,
                          textAlign: TextAlign.center,
                          style: PassType.screenTitle(scheme.onSurface),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    children: <Widget>[
                      // The face is authored at a fixed canvas, so it needs the
                      // same scale-to-fit wrapper the wallet card uses. This
                      // was a bare 0.72 while the wallet card rendered the same
                      // face at ticketAspect, so the card changed shape when
                      // you opened it.
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
                      if (pass.passengers.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 24),
                        Text(
                          'Passengers',
                          style: PassType.sectionTitle(
                            AppTokens.secondaryLabel(scheme),
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final p in pass.passengers)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              p.seat.isEmpty ? p.name : '${p.name} · ${p.seat}',
                              style: PassType.itemTitle(scheme.onSurface),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
