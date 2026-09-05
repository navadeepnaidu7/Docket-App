import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/history_folders_provider.dart';
import '../../domain/history_folder.dart';
import '../../domain/pass_catalog.dart';
import '../../domain/pass_history_category.dart';
import '../pass_remove_flow.dart';
import 'archive_pass_deck.dart';
import 'archive_scaffold.dart';
import 'passes_archive_screen.dart';

/// Every archived pass in one category, newest first, as a single deck you
/// move through card by card. See [ArchivePassDeck].
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
          return ArchivePassDeck(
            category: category,
            items: folder.items,
            onRemove: (WalletPassItem item) {
              confirmAndRemovePass(context, ref, item);
            },
          );
        },
      ),
    );
  }
}
