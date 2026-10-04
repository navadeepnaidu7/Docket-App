import '../../features/ids/domain/id_document.dart';
import '../../features/passport/domain/passport_profile.dart';

/// Stable id for any item shown in the wallet carousel or manage list.
String walletItemId(Object item) {
  return switch (item) {
    PassportProfile profile => profile.id,
    IdDocument document => document.id,
    _ => throw ArgumentError('Unknown wallet item type: ${item.runtimeType}'),
  };
}

/// All ids currently stored in passport and ID lists.
List<String> activeWalletItemIds({
  required List<PassportProfile> passports,
  required List<IdDocument> idDocs,
}) {
  return [...passports.map((p) => p.id), ...idDocs.map((d) => d.id)];
}

/// Merges documents in persisted order in O(items + order) time.
List<Object> sortWalletItems({
  required List<PassportProfile> passports,
  required List<IdDocument> idDocs,
  required List<String> order,
}) {
  final items = <Object>[...passports, ...idDocs];
  final byId = <String, List<Object>>{};
  for (final item in items) {
    (byId[walletItemId(item)] ??= <Object>[]).add(item);
  }
  final result = <Object>[];
  for (final id in order) {
    final matches = byId.remove(id);
    if (matches != null) result.addAll(matches);
  }
  // Unlisted items always come last, in their original order. Avoid a numeric
  // sentinel (9999) that places them ahead of real entries in a large wallet.
  for (final item in items) {
    if (byId.containsKey(walletItemId(item))) result.add(item);
  }
  return result;
}

/// Keeps stored order in sync when items are added or removed.
List<String> reconcileWalletOrder({
  required List<String> order,
  required List<String> activeIds,
}) {
  final active = activeIds.toSet();
  final seen = <String>{};
  final reconciled = <String>[];
  for (final id in order) {
    if (active.contains(id) && seen.add(id)) reconciled.add(id);
  }
  for (final id in activeIds) {
    if (seen.add(id)) reconciled.add(id);
  }
  return reconciled;
}
