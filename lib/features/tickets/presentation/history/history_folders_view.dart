import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/motion/entry_reveal.dart';
import '../../../../core/wallet/wallet_layout.dart';
import '../../domain/history_folder.dart';
import 'history_folder_tile.dart';

/// Two-column grid of history category folders.
class HistoryFoldersView extends StatelessWidget {
  const HistoryFoldersView({
    super.key,
    required this.folders,
    required this.onOpenFolder,
  });

  final List<HistoryFolderSummary> folders;
  final ValueChanged<HistoryFolderSummary> onOpenFolder;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color muted =
        isDark ? const Color(0xFFAEAEB2) : const Color(0xFF636366);
    final Color ink =
        isDark ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E);
    final double fabClearance = WalletLayout.fabClearance(context);

    // Transparent — sits on the dashboard backdrop (no nested black route).
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: EntryReveal(
              slideY: 10,
              duration: const Duration(milliseconds: 380),
              child: Text(
                'Archived Passes',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: ink,
                ),
              ),
            ),
          ),
        ),
        if (folders.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'No archived passes',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, fabClearance),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.92,
              ),
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  final HistoryFolderSummary folder = folders[index];
                  return EntryReveal(
                    delay: Duration(milliseconds: 50 + index * 55),
                    duration: const Duration(milliseconds: 460),
                    slideY: 16,
                    child: HistoryFolderTile(
                      key: ValueKey<String>(folder.category.name),
                      folder: folder,
                      onTap: () => onOpenFolder(folder),
                    ),
                  );
                },
                childCount: folders.length,
              ),
            ),
          ),
      ],
    );
  }
}
