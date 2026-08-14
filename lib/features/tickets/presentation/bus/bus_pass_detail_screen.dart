import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/studio_backdrop.dart';
import '../../domain/bus_pass_models.dart';
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
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
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
                      AspectRatio(
                        aspectRatio: 0.72,
                        child: BusTicketFace(pass: pass),
                      ),
                      if (pass.passengers.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 24),
                        Text(
                          'Passengers',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: AppTokens.secondaryLabel(scheme),
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final p in pass.passengers)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              p.seat.isEmpty ? p.name : '${p.name} · ${p.seat}',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
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
