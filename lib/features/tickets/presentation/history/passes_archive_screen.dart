import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/motion/entry_reveal.dart';
import '../../../../core/motion/studio_page_route.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../application/history_folders_provider.dart';
import '../../domain/history_folder.dart';
import 'archive_scaffold.dart';
import 'history_category_screen.dart';
import 'history_folder_tile.dart';

/// Archive root: one folder per category of archived passes.
class PassesArchiveScreen extends ConsumerWidget {
  const PassesArchiveScreen({
    super.key,
    required this.meshSeed,
    required this.washes,
  });

  final String meshSeed;
  final List<Color> washes;

  void _openCategory(BuildContext context, HistoryFolderSummary folder) {
    Navigator.of(context).push(
      studioPageRoute<void>(
        builder: (_) => HistoryCategoryScreen(
          category: folder.category,
          meshSeed: meshSeed,
          washes: washes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<HistoryFolderSummary>> folders = ref.watch(
      historyFoldersProvider,
    );

    return ArchiveScaffold(
      title: 'Archive',
      meshSeed: meshSeed,
      washes: washes,
      child: folders.when(
        loading: () => const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
        error: (Object err, StackTrace st) => ArchiveNotice(
          message: 'Couldn’t load your archive',
          detail: err.toString(),
        ),
        data: (List<HistoryFolderSummary> list) => list.isEmpty
            ? ArchiveNotice(
                message: 'No archived passes yet',
                detail: 'Finished journeys and shows will appear here.',
                actionLabel: 'View active passes',
                onAction: () => Navigator.of(context).maybePop(),
              )
            : _FolderGrid(
                folders: list,
                onOpen: (HistoryFolderSummary f) => _openCategory(context, f),
              ),
      ),
    );
  }
}

class _FolderGrid extends StatelessWidget {
  const _FolderGrid({required this.folders, required this.onOpen});

  final List<HistoryFolderSummary> folders;
  final ValueChanged<HistoryFolderSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    // One reveal for the whole grid. Per-tile stagger would replay every time a
    // recycled sliver child scrolled back into view.
    return EntryReveal(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: <Widget>[
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              Space.gutter,
              Space.x3,
              Space.gutter,
              MediaQuery.paddingOf(context).bottom + Space.x6,
            ),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: HistoryFolderTile.aspectRatio,
              ),
              delegate: SliverChildBuilderDelegate((
                BuildContext context,
                int index,
              ) {
                final HistoryFolderSummary folder = folders[index];
                return HistoryFolderTile(
                  key: ValueKey<String>(folder.category.name),
                  folder: folder,
                  onTap: () => onOpen(folder),
                );
              }, childCount: folders.length),
            ),
          ),
        ],
      ),
    );
  }
}

/// Centred empty / error message shared by both archive screens.
class ArchiveNotice extends StatelessWidget {
  const ArchiveNotice({
    super.key,
    required this.message,
    this.detail,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color muted = AppTokens.secondaryLabel(scheme);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SvgPicture.asset(
              AppAssets.passesHistory,
              width: 40,
              height: 40,
              colorFilter: ColorFilter.mode(
                muted.withValues(alpha: 0.45),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: Space.x3),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: muted,
              ),
            ),
            if (detail != null) ...<Widget>[
              const SizedBox(height: Space.x2),
              Text(
                detail!,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTokens.tertiaryLabel(scheme),
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: Space.x4),
              TextButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
