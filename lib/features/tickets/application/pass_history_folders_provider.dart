import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/history_folder.dart';
import '../domain/pass_catalog.dart';
import 'pass_list_provider.dart';

/// Expired passes grouped into non-empty history folders.
///
/// Derives from [passListProvider]; empty while loading or on error.
final passHistoryFoldersProvider =
    Provider<AsyncValue<List<HistoryFolderSummary>>>((Ref ref) {
  final AsyncValue<List<WalletPassItem>> async = ref.watch(passListProvider);
  return async.whenData(buildHistoryFolders);
});
