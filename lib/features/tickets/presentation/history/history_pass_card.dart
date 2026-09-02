import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/bounce_tap.dart';
import '../../domain/history_folder.dart';
import '../../domain/pass_catalog.dart';
import '../bus/bus_pass_detail_screen.dart';
import '../movie_pass_detail_screen.dart';
import '../ticket_detail_screen.dart';

/// One archived pass: title and date, nothing else.
///
/// The screen is already one category, so brand marks and chevrons would only
/// repeat what the header says. Height follows content rather than a fixed row
/// so long titles get two full lines.
class HistoryPassCard extends StatelessWidget {
  const HistoryPassCard({
    super.key,
    required this.item,
    this.onLongPress,
  });

  final WalletPassItem item;
  final VoidCallback? onLongPress;

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
      case BusPassItem(:final pass):
        root.push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => BusPassDetailScreen(pass: pass),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    final String title = HistoryPassPresentation.title(item);
    final String? date = HistoryPassPresentation.shortDateLabel(item);

    return Semantics(
      button: true,
      label: date == null ? title : '$title, $date',
      child: BounceTap(
        onTap: () => _open(context),
        onLongPress: onLongPress,
        scaleFactor: 0.985,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: AppTokens.groupedFieldFill(scheme, isDark: isDark),
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: AppTokens.separator(scheme), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                  height: 1.25,
                  color: scheme.onSurface,
                ),
              ),
              if (date != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  date,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTokens.secondaryLabel(scheme),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
