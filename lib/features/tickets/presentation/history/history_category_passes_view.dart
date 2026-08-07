import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../../../../core/motion/entry_reveal.dart';
import '../../../../core/wallet/wallet_layout.dart';
import '../../domain/history_folder.dart';
import '../../domain/pass_catalog.dart';
import '../../domain/pass_history_category.dart';
import 'history_folder_open_route.dart';
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
    final Color surface =
        isDark ? const Color(0xFF161820) : const Color(0xFFFFFFFF);
    final Color border = ink.withValues(alpha: isDark ? 0.08 : 0.06);
    final double fabClearance = WalletLayout.fabClearance(context);
    final PassHistoryCategory category = folder.category;
    final List<WalletPassItem> items = folder.items;
    final Object heroTag = historyFolderHeroTag(category.name);

    // Transparent column over the dashboard backdrop — no solid black page.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: <Widget>[
              _BackChip(
                surface: surface,
                ink: ink,
                border: border,
                onTap: () {
                  HapticService.select();
                  onBack();
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Hero(
                  tag: heroTag,
                  child: Material(
                    color: Colors.transparent,
                    child: _CategoryHeaderCard(
                      category: category,
                      countLabel: folder.countLabel,
                      lastAddedLabel: folder.lastAddedLabel,
                      ink: ink,
                      muted: muted,
                      surface: surface,
                      border: border,
                      isDark: isDark,
                    ),
                  ),
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
                  padding: EdgeInsets.fromLTRB(16, 8, 16, fabClearance),
                  itemCount: items.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (BuildContext context, int index) {
                    final WalletPassItem item = items[index];
                    return EntryReveal(
                      delay: Duration(milliseconds: 40 + index * 45),
                      duration: const Duration(milliseconds: 420),
                      slideY: 14,
                      child: HistoryPassStrip(
                        key: ValueKey<String>(item.id),
                        item: item,
                        category: category,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _BackChip extends StatelessWidget {
  const _BackChip({
    required this.surface,
    required this.ink,
    required this.border,
    required this.onTap,
  });

  final Color surface;
  final Color ink;
  final Color border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Icon(Icons.arrow_back_rounded, size: 20, color: ink),
        ),
      ),
    );
  }
}

class _CategoryHeaderCard extends StatelessWidget {
  const _CategoryHeaderCard({
    required this.category,
    required this.countLabel,
    required this.lastAddedLabel,
    required this.ink,
    required this.muted,
    required this.surface,
    required this.border,
    required this.isDark,
  });

  final PassHistoryCategory category;
  final String countLabel;
  final String? lastAddedLabel;
  final Color ink;
  final Color muted;
  final Color surface;
  final Color border;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final Color accent = category.accent(Theme.of(context).brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.28 : 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(category.icon, size: 18, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  category.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: ink,
                  ),
                ),
                Text(
                  lastAddedLabel ?? countLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            countLabel,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }
}
