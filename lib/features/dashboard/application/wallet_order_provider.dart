import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/secure_document_store.dart';

class WalletOrderController extends StateNotifier<List<String>> {
  WalletOrderController() : super([]);

  static const _storageKey = 'wallet_items_order';

  Future<void> loadOrder() async {
    state = await SecureDocumentStore.readList(_storageKey);
  }

  Future<void> saveOrder(List<String> order) async {
    state = order;
    await SecureDocumentStore.writeList(_storageKey, order);
  }

  /// Records a newly added item's position in the carousel.
  ///
  /// Inserts at the front by default, because both list controllers prepend
  /// their new record and the dashboard renders by *this* order — appending
  /// here sent every freshly saved card to the end of the wallet, which is the
  /// opposite of what the prepend was for.
  void updateOrderOnItemAdded(String id, {bool atFront = true}) {
    if (!state.contains(id)) {
      final newState = atFront ? <String>[id, ...state] : <String>[...state, id];
      saveOrder(newState);
    }
  }

  void updateOrderOnItemRemoved(String id) {
    if (state.contains(id)) {
      final newState = state.where((item) => item != id).toList();
      saveOrder(newState);
    }
  }
}

final walletOrderProvider =
    StateNotifierProvider<WalletOrderController, List<String>>((ref) {
      final controller = WalletOrderController();
      controller.loadOrder();
      return controller;
    });
