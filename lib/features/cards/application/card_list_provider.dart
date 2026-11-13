import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/document_record_decoder.dart';
import '../../../core/storage/secure_document_store.dart';
import '../../dashboard/application/wallet_loading_provider.dart';
import '../domain/card_number.dart';
import '../domain/payment_card.dart';

const String savedPaymentCardsKey = 'saved_payment_cards';

class DuplicateCardException implements Exception {
  const DuplicateCardException(this.card);
  final PaymentCard card;
}

final cardListProvider =
    StateNotifierProvider<CardListController, List<PaymentCard>>((ref) {
      final CardListController controller = CardListController(ref);
      controller.loaded = controller.loadCards();
      return controller;
    });

class CardListController extends StateNotifier<List<PaymentCard>> {
  CardListController(this.ref) : super(const <PaymentCard>[]);

  final Ref ref;

  Future<void> _saveQueue = Future<void>.value();
  Future<void>? _loadFuture;
  bool _initialLoadComplete = false;

  late final Future<void> loaded;

  List<PaymentCard> get documents => state;

  Future<void> loadCards() => _loadFuture ??= _loadCards().whenComplete(
    () => _initialLoadComplete = true,
  );

  bool _deferDuringLoad(void Function() operation) {
    if (_loadFuture == null || _initialLoadComplete) return false;
    _loadFuture!.then((_) {
      if (mounted) operation();
    });
    return true;
  }

  Future<void> _loadCards() async {
    final List<String> saved;
    try {
      saved = await SecureDocumentStore.readList(savedPaymentCardsKey);
    } catch (_) {
      if (mounted) ref.read(cardLoadingProvider.notifier).state = false;
      return;
    }
    if (!mounted) return;
    final DecodedRecords<PaymentCard> decoded = await decodeStoredRecords(
      saved,
      decodePaymentCardRecords,
    );
    if (!mounted) return;
    if (decoded.hasInvalidRecords) {
      SecureDocumentStore.markUnreadable(savedPaymentCardsKey);
    }
    state = decoded.records;
    ref.read(cardLoadingProvider.notifier).state = false;
  }

  Future<void> _save(List<PaymentCard> cards) async {
    await SecureDocumentStore.writeList(
      savedPaymentCardsKey,
      cards.map((PaymentCard card) => card.toJson()).toList(),
    );
  }

  Future<void> _queueSaveAwaited(List<PaymentCard> cards) {
    final Future<void> save = _saveQueue.then((_) => _save(cards));
    _saveQueue = save.catchError((_) {});
    return save;
  }

  PaymentCard? findByNumber(String raw, {String? exceptId}) {
    final String digits = cardDigits(raw);
    if (digits.isEmpty) return null;
    for (final PaymentCard card in state) {
      if (card.id == exceptId) continue;
      if (card.number == digits) return card;
    }
    return null;
  }

  /// Replaces [card] when its id is already stored, otherwise prepends it.
  ///
  /// The in-memory list is rolled back if the write is refused, so a failed
  /// save cannot leave a card on screen that the next launch will not have.
  Future<void> saveCard(PaymentCard card) async {
    await loaded;
    if (!mounted) return;
    if (_deferDuringLoad(() => saveCard(card))) return;
    final PaymentCard? duplicate = findByNumber(card.number, exceptId: card.id);
    if (duplicate != null) throw DuplicateCardException(duplicate);
    final int index = state.indexWhere(
      (PaymentCard item) => item.id == card.id,
    );
    final List<PaymentCard> next = <PaymentCard>[...state];
    if (index >= 0) {
      next[index] = card;
    } else {
      next.insert(0, card);
    }
    final List<PaymentCard> previous = state;
    state = next;
    try {
      await _queueSaveAwaited(next);
    } catch (_) {
      if (mounted) state = previous;
      rethrow;
    }
  }

  void removeCard(String id) {
    if (_deferDuringLoad(() => removeCard(id))) return;
    final List<PaymentCard> next = state
        .where((PaymentCard card) => card.id != id)
        .toList();
    state = next;
    _saveQueue = _saveQueue.then((_) => _save(next)).catchError((_) {});
  }
}
