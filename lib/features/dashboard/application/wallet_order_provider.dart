import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/secure_document_store.dart';

class WalletOrderController extends StateNotifier<List<String>> {
  WalletOrderController() : super([]);

  static const _storageKey = 'wallet_items_order';
  bool isLoaded = false;
  Future<void>? _loadFuture;
  Future<void> _saveQueue = Future<void>.value();
  List<String>? _pendingOrder;

  Future<void> loadOrder() => _loadFuture ??= _loadOrder();

  Future<void> _loadOrder() async {
    List<String> order;
    try {
      order = await SecureDocumentStore.readList(_storageKey);
    } catch (_) {
      order = <String>[];
    }
    if (!mounted) return;
    isLoaded = true;
    state = _pendingOrder ?? order;
    _pendingOrder = null;
  }

  Future<void> saveOrder(List<String> order) async {
    if (!mounted) return;
    if (!isLoaded) _pendingOrder = order;
    state = order;
    final save = _saveQueue.then((_) async {
      if (!isLoaded && _loadFuture != null) await _loadFuture;
      await SecureDocumentStore.writeList(_storageKey, order);
    });
    _saveQueue = save.catchError((_) {});
    // UI callers are fire-and-forget. A keystore failure must not become an
    // unhandled startup error or poison subsequent ordering writes.
    await _saveQueue;
  }

  /// Records a newly added item's position in the carousel.
  ///
  /// Inserts at the front by default, because both list controllers prepend
  /// their new record and the dashboard renders by *this* order — appending
  /// here sent every freshly saved card to the end of the wallet, which is the
  /// opposite of what the prepend was for.
  void updateOrderOnItemAdded(String id, {bool atFront = true}) {
    if (!isLoaded && _loadFuture != null) {
      _loadFuture!.then((_) {
        if (mounted) updateOrderOnItemAdded(id, atFront: atFront);
      });
      return;
    }
    if (!state.contains(id)) {
      final newState = atFront
          ? <String>[id, ...state]
          : <String>[...state, id];
      saveOrder(newState);
    }
  }

  void updateOrderOnItemRemoved(String id) {
    if (!isLoaded && _loadFuture != null) {
      _loadFuture!.then((_) {
        if (mounted) updateOrderOnItemRemoved(id);
      });
      return;
    }
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
