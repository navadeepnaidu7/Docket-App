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
    final AsyncValue<List<HistoryFolderSummary>> folders =
        ref.watch(historyFoldersProvider);

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
            );
          }
          return _MonthSections(
            sections: buildHistoryMonthSections(folder.items),
          );
        },
      ),
    );
  }
}

class _MonthSections extends StatelessWidget {
  const _MonthSections({required this.sections});

  final List<HistoryMonthSection> sections;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle headerStyle =
        theme.textTheme.promptSectionLabel(theme.colorScheme);

    // One reveal for the whole list — see the note in PassesArchiveScreen.
    return EntryReveal(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: <Widget>[
          for (final HistoryMonthSection section in sections) ...<Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.x6,
                Space.gutter,
                Space.x2,
              ),
              sliver: SliverToBoxAdapter(
                child: Text(
                  section.label.toUpperCase(),
                  style: headerStyle,
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
