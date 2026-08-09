import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/studio_backdrop.dart';
import '../../../dashboard/presentation/settings_route.dart';
import '../../../dashboard/presentation/widgets/dashboard_header.dart';

/// Shared chrome for the archive screens: back, title, settings avatar.
///
/// Deliberately spare — the archive is a place for looking at old passes, so
/// nothing from the wallet shell (tabs, add button, carousel) comes along.
class ArchiveScaffold extends StatelessWidget {
  const ArchiveScaffold({
    super.key,
    required this.title,
    required this.meshSeed,
    required this.washes,
    required this.child,
  });

  final String title;

  /// Passed down from the dashboard so the avatar keeps its identity mesh.
  final String meshSeed;
  final List<Color> washes;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color ink = AppTheme.ink(theme.brightness);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: <Widget>[
          const StudioBackdrop(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
                  child: SizedBox(
                    height: AppTheme.controlHeightSm,
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: ink,
                          ),
                          tooltip: 'Back',
                          onPressed: () {
                            HapticService.select();
                            Navigator.of(context).pop();
                          },
                        ),
                        Expanded(
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                              color: ink,
                            ),
                          ),
                        ),
                        ProfileMeshButton(
                          meshSeed: meshSeed,
                          washes: washes,
                          onTap: () => openSettingsRoute(context),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
