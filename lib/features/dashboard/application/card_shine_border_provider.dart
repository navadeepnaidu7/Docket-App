import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kCardShineBorderKey = 'experimental_card_shine_border';

final cardShineBorderProvider =
    StateNotifierProvider<CardShineBorderNotifier, bool>(
  (ref) => CardShineBorderNotifier(),
);

class CardShineBorderNotifier extends StateNotifier<bool> {
  CardShineBorderNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kCardShineBorderKey) ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCardShineBorderKey, state);
  }
}