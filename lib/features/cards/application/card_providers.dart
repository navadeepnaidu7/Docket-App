import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/card_scan_store.dart';
import '../../../core/storage/secure_document_store.dart';
import '../../dashboard/application/trash_provider.dart';
import '../domain/payment_card.dart';
import 'card_list_provider.dart';
import 'card_scan_provider.dart';

/// Deletes scan folders no live or trashed card points at.
///
/// Same gates as the ID attachment sweep. Both lists start empty, and a
/// failed decrypt also looks empty, so an ungated sweep would delete every
/// photo on the device. Trashed cards still own their files.
Future<void> sweepCardScanOrphans(WidgetRef ref) async {
  final CardListController cards;
  final TrashController trash;
  final CardScanStore store;
  try {
    cards = ref.read(cardListProvider.notifier);
    trash = ref.read(trashProvider.notifier);
    store = ref.read(cardScanStoreProvider);
  } catch (_) {
    return;
  }

  try {
    await cards.loaded;
    await trash.loaded;
  } catch (_) {
    return;
  }

  if (SecureDocumentStore.isUnreadable(savedPaymentCardsKey) ||
      SecureDocumentStore.isUnreadable(trashPaymentCardsKey) ||
      store.keyUnreadable ||
      !cards.mounted ||
      !trash.mounted) {
    return;
  }

  final Set<String> live = <String>{
    for (final PaymentCard card in cards.documents) card.id,
    for (final PaymentCard card in trash.contents.cards) card.id,
  };

  try {
    await store.sweepOrphans(live);
  } catch (_) {}
}
