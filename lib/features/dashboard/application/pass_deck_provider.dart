import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kPassDeckKey = 'experimental_pass_deck';

/// Swaps the Passes tab's vertical roll carousel for the horizontal stacked
/// deck. A user preference rather than a `DevFlag`, so it survives in release
/// builds. See `docs/features/pass-deck.md`.
final passDeckModeProvider = StateNotifierProvider<PassDeckModeNotifier, bool>(
  (ref) => PassDeckModeNotifier(),
);

class PassDeckModeNotifier extends StateNotifier<bool> {
  PassDeckModeNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kPassDeckKey) ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPassDeckKey, state);
  }
}
