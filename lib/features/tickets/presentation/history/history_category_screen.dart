import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/motion/entry_reveal.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/prompt_typography.dart';
import '../../application/history_folders_provider.dart';
import '../../domain/history_folder.dart';
import '../../domain/pass_catalog.dart';
import '../../domain/pass_history_category.dart';
import 'archive_scaffold.dart';
import 'history_pass_card.dart';
import 'history_visuals.dart';
import 'passes_archive_screen.dart';

/// Every archived pass in one category, bucketed by month, newest first.
class HistoryCategoryScreen extends ConsumerWidget {
  const HistoryCategoryScreen({
    super.key,
    required this.category,
    required this.meshSeed,
    required this.washes,
  });

  final PassHistoryCategory category;
  final String meshSeed;
  final List<Color> washes;

  /// Re-derived rather than passed in, so deleting a pass while this screen is
  /// open updates it instead of showing a frozen snapshot.
  HistoryFolderSummary? _folderFrom(List<HistoryFolderSummary> folders) {
    for (final HistoryFolderSummary folder in folders) {
      if (folder.category == category) return folder;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<HistoryFolderSummary>> folders = ref.watch(
      historyFoldersProvider,
    );

    return ArchiveScaffold(
      title: category.label,
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
        data: (List<HistoryFolderSummary> list) {
          final HistoryFolderSummary? folder = _folderFrom(list);
          // The last pass in this category can be removed while the screen is
          // open. Show the empty state rather than popping during a build.
          if (folder == null || folder.items.isEmpty) {
            return ArchiveNotice(
              message: 'No archived ${category.singularLabel} passes',
              detail: 'This folder will fill as passes are completed.',
              actionLabel: 'Back to archive',
              onAction: () => Navigator.of(context).maybePop(),
            );
          }
          return _MonthSections(
            category: category,
            sections: buildHistoryMonthSections(folder.items),
          );
        },
      ),
    );
  }
}

class _MonthSections extends StatelessWidget {
  const _MonthSections({required this.category, required this.sections});

  final PassHistoryCategory category;
  final List<HistoryMonthSection> sections;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle headerStyle = theme.textTheme.promptSectionLabel(
      theme.colorScheme,
    );

    // One reveal for the whole list — see the note in PassesArchiveScreen.
    return EntryReveal(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.x4,
              Space.gutter,
              Space.x2,
            ),
            sliver: SliverToBoxAdapter(
              child: _CategoryIntro(category: category, sections: sections),
            ),
          ),
          for (final HistoryMonthSection section in sections) ...<Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.x5,
                Space.gutter,
                Space.x2,
              ),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: <Widget>[
                    Text(section.label, style: headerStyle),
                    const SizedBox(width: Space.x3),
                    Expanded(
                      child: Container(
                        height: 0.5,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              sliver: SliverList.separated(
                itemCount: section.items.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(height: 10),
                itemBuilder: (BuildContext context, int index) {
                  final WalletPassItem item = section.items[index];
                  return HistoryPassCard(
                    key: ValueKey<String>(item.id),
                    item: item,
                  );
                },
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.paddingOf(context).bottom + Space.x6,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryIntro extends StatelessWidget {
  const _CategoryIntro({required this.category, required this.sections});

  final PassHistoryCategory category;
  final List<HistoryMonthSection> sections;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color accent = HistoryStripLook.forCategory(category).gradient.first;
    final int passCount = sections.fold<int>(
      0,
      (int total, HistoryMonthSection section) => total + section.items.length,
    );
    final String passLabel = passCount == 1 ? 'pass' : 'passes';

    return Row(
      children: <Widget>[
        Hero(
          tag: 'history-category-${category.name}',
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              child: Center(
                child: HistoryCategoryMark(category: category, size: 18),
              ),
            ),
          ),
        ),
        const SizedBox(width: Space.x3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '$passCount archived $passLabel',
                style: themeText(context, scheme),
              ),
              const SizedBox(height: 2),
              Text(
                'Finished ${category.label.toLowerCase()}, ordered by date.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.60),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  TextStyle themeText(BuildContext context, ColorScheme scheme) =>
      Theme.of(context).textTheme.titleSmall!.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: scheme.onSurface,
      );
}
