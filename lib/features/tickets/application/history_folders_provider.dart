import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/history_folder.dart';
import 'pass_list_provider.dart';

/// Archive folders derived from the wallet (does not re-fetch).
///
/// The archive screens watch this rather than receiving a snapshot at push
/// time: a pushed route outlives the tab that opened it, so a captured list
/// would freeze on refresh or delete.
final historyFoldersProvider = Provider<AsyncValue<List<HistoryFolderSummary>>>(
  (Ref ref) => ref.watch(passListProvider).whenData(buildHistoryFolders),
);
