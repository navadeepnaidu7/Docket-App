import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/wallet/wallet_filter.dart';

const _kWalletFilterEnabledKey = 'experimental_wallet_filter_enabled';
const _kWalletFilterCategoryKey = 'wallet_filter_category';

final walletFilterEnabledProvider =
    StateNotifierProvider<WalletFilterEnabledNotifier, bool>(
  (ref) => WalletFilterEnabledNotifier(),
);

class WalletFilterEnabledNotifier extends StateNotifier<bool> {
  WalletFilterEnabledNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kWalletFilterEnabledKey) ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWalletFilterEnabledKey, state);
  }
}

final walletFilterCategoryProvider =
    StateNotifierProvider<WalletFilterCategoryNotifier, WalletFilterCategory>(
  (ref) => WalletFilterCategoryNotifier(),
);

class WalletFilterCategoryNotifier extends StateNotifier<WalletFilterCategory> {
  WalletFilterCategoryNotifier() : super(WalletFilterCategory.all) {
    _load();
  }

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_kWalletFilterCategoryKey);
    if (raw == null) return;
    state = WalletFilterCategory.values.firstWhere(
      (c) => c.name == raw,
      orElse: () => WalletFilterCategory.all,
    );
  }

  Future<void> select(WalletFilterCategory category) async {
    if (state == category) return;
    state = category;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kWalletFilterCategoryKey, category.name);
  }

  void resetToAll() {
    if (state == WalletFilterCategory.all) return;
    select(WalletFilterCategory.all);
  }
}