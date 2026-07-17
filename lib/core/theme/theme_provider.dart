import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kKey = 'theme_mode';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final Object? raw = prefs.get(_kKey);

    // New string storage: 'system' | 'light' | 'dark'
    if (raw is String) {
      state = switch (raw) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      };
      return;
    }

    // Legacy bool storage (true = dark).
    if (raw is bool) {
      state = raw ? ThemeMode.dark : ThemeMode.light;
      await prefs.setString(_kKey, raw ? 'dark' : 'light');
      return;
    }

    state = ThemeMode.system;
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    final String value = switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_kKey, value);
  }

  /// Toggle between light and dark (skips system). Used by the settings switch.
  Future<void> toggle() async {
    final ThemeMode next =
        state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setMode(next);
  }
}
