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

  void updateOrderOnItemAdded(String id) {
    if (!state.contains(id)) {
      final newState = [...state, id];
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
