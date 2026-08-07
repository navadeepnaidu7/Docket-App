import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../../../../shared/widgets/bounce_tap.dart';
import '../../domain/history_folder.dart';
import '../../domain/pass_catalog.dart';
import '../../domain/pass_history_category.dart';
import '../movie_pass_detail_screen.dart';
import '../ticket_detail_screen.dart';

/// Horizontal rectangular pass row used inside a history category folder.
class HistoryPassStrip extends StatelessWidget {
  const HistoryPassStrip({
    super.key,
    required this.item,
    required this.category,
  });

  final WalletPassItem item;
  final PassHistoryCategory category;

  static const double height = 72;
  static const double radius = 18;

  void _open(BuildContext context) {
    HapticService.confirm();
    // Root navigator so detail opens as a normal full-screen pass (same as
    // the active wallet cards), not trapped inside the history tab shell.
    final NavigatorState root = Navigator.of(context, rootNavigator: true);
    switch (item) {
      case TrainPassItem(:final ticket):
        root.push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => TicketDetailScreen(ticket: ticket),
          ),
        );
      case MoviePassItem(:final pass):
        root.push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => MoviePassDetailScreen(pass: pass),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final Color fill = category.accent(brightness);
    final String title = HistoryPassPresentation.title(item);
    final String subtitle = HistoryPassPresentation.subtitle(item);

    return BounceTap(
      onTap: () => _open(context),
      scaleFactor: 0.98,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: fill.withValues(alpha: brightness == Brightness.dark ? 0.35 : 0.28),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            children: <Widget>[
              // Soft highlight for material depth
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: height * 0.45,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.white.withValues(alpha: 0.14),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Icon(
                        category.icon,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.25,
                              color: Colors.white,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.78),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: 0.72),
                      size: 22,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
