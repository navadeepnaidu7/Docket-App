import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalletOrderController extends StateNotifier<List<String>> {
  WalletOrderController() : super([]);

  static const _storageKey = 'wallet_items_order';

  Future<void> loadOrder() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_storageKey) ?? [];
  }

  Future<void> saveOrder(List<String> order) async {
    final prefs = await SharedPreferences.getInstance();
    state = order;
    await prefs.setStringList(_storageKey, order);
  }

  void updateOrderOnItemAdded(String id) {
    if (!state.contains(id)) {
      final newState = [id, ...state];
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

final walletOrderProvider = StateNotifierProvider<WalletOrderController, List<String>>((ref) {
  final controller = WalletOrderController();
  controller.loadOrder();
  return controller;
});
