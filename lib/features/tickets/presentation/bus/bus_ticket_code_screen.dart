import 'package:flutter/material.dart';

import '../../domain/bus_pass_models.dart';
import '../pass_code_view.dart';
import '../pass_typography.dart';

/// Fullscreen scan view — code, route, and departure only.
///
/// Deliberately the same shape as `MovieTicketCodeScreen`: at a gate you want
/// the largest possible code and the least possible else, and a traveller who
/// has used one pass should not have to relearn the other. Both go through
/// [PassCodePlate], so the two render identically rather than approximately.
class BusTicketCodeScreen extends StatelessWidget {
  const BusTicketCodeScreen({super.key, required this.pass});

  final BusPass pass;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color ink = scheme.onSurface;
    final Color muted = ink.withValues(alpha: 0.55);

    final String route = <String>[
      pass.resolvedFromCity,
      pass.resolvedToCity,
    ].where((String s) => s.trim().isNotEmpty).join('  →  ');

    final String when = <String>[
      pass.date.trim(),
      pass.departTime.trim(),
    ].where((String s) => s.isNotEmpty).join(' · ');

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
                    if (route.isNotEmpty)
                      Text(
                        route,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: PassType.screenTitle(ink),
                      ),
                    if (when.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        when,
                        textAlign: TextAlign.center,
                        style: PassType.caption(muted),
                      ),
                    ],
                    const SizedBox(height: 36),
                    PassCodePlate(code: pass.passCode),
                    if (pass.bookingId.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 28),
                      Text(
                        pass.bookingId.trim(),
                        textAlign: TextAlign.center,
                        style: PassType.code(ink),
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
