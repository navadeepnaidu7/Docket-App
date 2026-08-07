import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../../../../shared/widgets/bounce_tap.dart';
import '../../domain/history_folder.dart';
import '../../domain/pass_catalog.dart';
import '../movie_pass_detail_screen.dart';
import '../ticket_detail_screen.dart';
import 'history_visuals.dart';

/// Horizontal rectangular pass row used inside a history category folder.
class HistoryPassStrip extends StatelessWidget {
  const HistoryPassStrip({
    super.key,
    required this.item,
  });

  final WalletPassItem item;

  static const double height = 74;
  static const double radius = 18;

  void _open(BuildContext context) {
    HapticService.confirm();
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
    final HistoryStripLook look = HistoryStripLook.forItem(item);
    final String title = HistoryPassPresentation.title(item);
    final String subtitle = HistoryPassPresentation.subtitle(item);
    final Color lead = look.gradient.first;

    return Semantics(
      button: true,
      label: title,
      child: BounceTap(
        onTap: () => _open(context),
        scaleFactor: 0.98,
        child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: look.gradient.length >= 2
                ? look.gradient
                : <Color>[lead, lead],
          ),
          borderRadius: BorderRadius.circular(radius),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: look.shadow.withValues(alpha: 0.32),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            children: <Widget>[
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: height * 0.5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.white.withValues(alpha: 0.16),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: HistoryBrandMark(look: look, size: 20),
                    ),
                    const SizedBox(width: 12),
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
                              fontSize: 15.5,
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
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: 0.70),
                      size: 22,
                    ),
                  ],
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
