import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_config.dart';
import 'dev_flags.dart';

const String _kUseMockPasses = 'dev_use_mock_passes';
const String _kApiBaseUrl = 'dev_api_base_url';

final devFlagsProvider =
    StateNotifierProvider<DevFlagsNotifier, DevFlags>((Ref ref) {
  return DevFlagsNotifier();
});

class DevFlagsNotifier extends StateNotifier<DevFlags> {
  DevFlagsNotifier() : super(DevFlags.compileTimeDefaults()) {
    _load();
  }

  /// Fixed flags for tests (skips prefs).
  DevFlagsNotifier.fixed(super.state);

  Future<void> _load() async {
    if (!DevConfig.allowRuntimeOverrides) {
      state = DevFlags.lockedConsumer();
      return;
    }
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool useMock = prefs.getBool(_kUseMockPasses) ??
          DevConfig.defaultUseMockPasses;
      final String url =
          prefs.getString(_kApiBaseUrl) ?? DevConfig.defaultApiBaseUrl;
      state = DevFlags(useMockPasses: useMock, apiBaseUrl: url);
    } catch (e, st) {
      debugPrint('DevFlags load failed: $e\n$st');
      state = DevFlags.compileTimeDefaults();
    }
  }

  Future<void> setUseMockPasses(bool value) async {
    if (!DevConfig.allowRuntimeOverrides) return;
    state = state.copyWith(useMockPasses: value);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kUseMockPasses, value);
  }

  Future<void> toggleUseMockPasses() =>
      setUseMockPasses(!state.useMockPasses);

  Future<void> setApiBaseUrl(String url) async {
    if (!DevConfig.allowRuntimeOverrides) return;
    final String trimmed = url.trim();
    state = state.copyWith(apiBaseUrl: trimmed);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kApiBaseUrl, trimmed);
  }

  Future<void> resetToCompileTimeDefaults() async {
    if (!DevConfig.allowRuntimeOverrides) return;
    state = DevFlags.compileTimeDefaults();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUseMockPasses);
    await prefs.remove(_kApiBaseUrl);
  }
}
