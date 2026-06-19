import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kShowNavLabelsKey = 'show_nav_labels';

final showNavLabelsProvider = StateNotifierProvider<ShowNavLabelsNotifier, bool>(
  (ref) => ShowNavLabelsNotifier(),
);

class ShowNavLabelsNotifier extends StateNotifier<bool> {
  ShowNavLabelsNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kShowNavLabelsKey) ?? true;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowNavLabelsKey, state);
  }
}
