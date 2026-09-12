import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kSearchButtonEnabledKey = 'show_search_button';

/// Opt-in header control, like the wallet filter and pass deck: off until the
/// user adds it from Settings, so the header keeps its default shape.
final searchButtonEnabledProvider =
    StateNotifierProvider<SearchButtonEnabledNotifier, bool>(
      (ref) => SearchButtonEnabledNotifier(),
    );

class SearchButtonEnabledNotifier extends StateNotifier<bool> {
  SearchButtonEnabledNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kSearchButtonEnabledKey) ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSearchButtonEnabledKey, state);
  }
}
