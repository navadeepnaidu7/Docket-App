import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const paymentCardStackPreferenceKey = 'experimental_payment_card_stack';

final paymentCardStackProvider =
    StateNotifierProvider<PaymentCardStackNotifier, bool>(
      (ref) => PaymentCardStackNotifier(),
    );

class PaymentCardStackNotifier extends StateNotifier<bool> {
  PaymentCardStackNotifier() : super(false) {
    _load();
  }

  bool _changed = false;
  Future<void> _writes = Future<void>.value();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted && !_changed) {
      state = prefs.getBool(paymentCardStackPreferenceKey) ?? false;
    }
  }

  Future<void> setEnabled(bool enabled) {
    _changed = true;
    state = enabled;
    return _writes = _writes.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(paymentCardStackPreferenceKey, enabled);
    });
  }
}
