import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../../../../core/wallet/wallet_layout.dart';
import '../../../../shared/widgets/bounce_tap.dart';
import '../../domain/history_folder.dart';
import '../../domain/pass_catalog.dart';
import '../../domain/pass_history_category.dart';
import 'history_pass_strip.dart';

/// Scrollable list of horizontal pass strips for one history category.
class HistoryCategoryPassesView extends StatelessWidget {
  const HistoryCategoryPassesView({
    super.key,
    required this.folder,
    required this.onBack,
  });

  final HistoryFolderSummary folder;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color ink =
        isDark ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E);
    final Color muted =
        isDark ? const Color(0xFFAEAEB2) : const Color(0xFF636366);
    final double fabClearance = WalletLayout.fabClearance(context);
    final PassHistoryCategory category = folder.category;
    final List<WalletPassItem> items = folder.items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 20, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Semantics(
                button: true,
                label: 'Back',
                child: BounceTap(
                  onTap: () {
                    HapticService.select();
                    onBack();
                  },
                  scaleFactor: 0.92,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: ink.withValues(alpha: 0.88),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  category.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    height: 1.1,
                    color: ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                folder.countLabel,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: muted,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    'No archived ${category.singularLabel} passes',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: muted,
                    ),
                  ),
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  // No staggered EntryReveal — it stacked on the shell
                  // cross-fade and felt jerky.
                  padding: EdgeInsets.fromLTRB(16, 12, 16, fabClearance),
                  itemCount: items.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (BuildContext context, int index) {
                    final WalletPassItem item = items[index];
                    return HistoryPassStrip(
                      key: ValueKey<String>(item.id),
                      item: item,
                    );
                  },
                ),
        ),
      ],
    );
  }
}
