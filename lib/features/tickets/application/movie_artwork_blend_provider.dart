import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const movieArtworkBlendPreferenceKey = 'experimental_movie_artwork_blend';

final movieArtworkBlendProvider =
    StateNotifierProvider<MovieArtworkBlendNotifier, bool>(
      (ref) => MovieArtworkBlendNotifier(),
    );

/// An opt-in movie treatment; existing installs keep their current pass faces.
class MovieArtworkBlendNotifier extends StateNotifier<bool> {
  MovieArtworkBlendNotifier() : super(false) {
    _load();
  }

  bool _changed = false;
  Future<void> _writes = Future<void>.value();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted && !_changed) {
      state = prefs.getBool(movieArtworkBlendPreferenceKey) ?? false;
    }
  }

  Future<void> setEnabled(bool enabled) {
    _changed = true;
    state = enabled;
    return _writes = _writes.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(movieArtworkBlendPreferenceKey, enabled);
    });
  }
}
