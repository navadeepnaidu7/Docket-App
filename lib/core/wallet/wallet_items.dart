import '../../features/cards/domain/payment_card.dart';
import '../../features/ids/domain/id_document.dart';
import '../../features/passport/domain/passport_profile.dart';

/// A presentation-only group. Stored records and wallet order stay individual.
class PaymentCardStackGroup {
  PaymentCardStackGroup(List<PaymentCard> cards)
    : assert(cards.isNotEmpty),
      cards = List.unmodifiable(cards);

  static const walletId = 'payment-card-stack';
  final List<PaymentCard> cards;

  bool containsId(String id) => cards.any((card) => card.id == id);
}

/// Groups at the first payment card, preserving every other document's order.
List<Object> groupWalletPaymentCards(List<Object> items) {
  final cards = items.whereType<PaymentCard>().toList(growable: false);
  if (cards.isEmpty) return items;
  final group = PaymentCardStackGroup(cards);
  bool added = false;
  final result = <Object>[];
  for (final item in items) {
    if (item is! PaymentCard) {
      result.add(item);
    } else if (!added) {
      result.add(group);
      added = true;
    }
  }
  return result;
}

/// Stable id for any item shown in the wallet carousel or manage list.
String walletItemId(Object item) {
  return switch (item) {
    PassportProfile profile => profile.id,
    IdDocument document => document.id,
    PaymentCard card => card.id,
    PaymentCardStackGroup() => PaymentCardStackGroup.walletId,
    _ => throw ArgumentError('Unknown wallet item type: ${item.runtimeType}'),
  };
}

/// All ids currently stored in passport and ID lists.
List<String> activeWalletItemIds({
  required List<PassportProfile> passports,
  required List<IdDocument> idDocs,
  List<PaymentCard> cards = const <PaymentCard>[],
}) {
  return <String>[
    ...passports.map((PassportProfile profile) => profile.id),
    ...idDocs.map((IdDocument document) => document.id),
    ...cards.map((PaymentCard card) => card.id),
  ];
}

/// Merges documents in persisted order in O(items + order) time.
List<Object> sortWalletItems({
  required List<PassportProfile> passports,
  required List<IdDocument> idDocs,
  List<PaymentCard> cards = const <PaymentCard>[],
  required List<String> order,
}) {
  final items = <Object>[...passports, ...idDocs, ...cards];
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
