import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Model ──────────────────────────────────────────────────────────────────

enum AppThemePreference { light, dark, schedule }

enum ScheduleKind { sunriseSunset, custom }

/// Fixed local-day window for the "Sunrise–sunset" schedule (device clock).
const int kSunriseLightStartMinutes = 7 * 60; // 7:00 AM
const int kSunriseLightEndMinutes = 18 * 60; // 6:00 PM

@immutable
class ThemeSettings {
  const ThemeSettings({
    required this.preference,
    required this.scheduleKind,
    required this.lightStartMinutes,
    required this.lightEndMinutes,
  });

  static const ThemeSettings defaults = ThemeSettings(
    preference: AppThemePreference.light,
    scheduleKind: ScheduleKind.custom,
    lightStartMinutes: 7 * 60,
    lightEndMinutes: 18 * 60,
  );

  final AppThemePreference preference;
  final ScheduleKind scheduleKind;

  /// Minutes from local midnight [0, 1439] for custom light start.
  final int lightStartMinutes;

  /// Minutes from local midnight [0, 1439] for custom light end (dark from).
  /// When end ≤ start, the light window wraps midnight.
  final int lightEndMinutes;

  /// Effective light-window start for the active schedule kind.
  int get effectiveLightStartMinutes =>
      scheduleKind == ScheduleKind.sunriseSunset
          ? kSunriseLightStartMinutes
          : lightStartMinutes;

  /// Effective light-window end for the active schedule kind.
  int get effectiveLightEndMinutes =>
      scheduleKind == ScheduleKind.sunriseSunset
          ? kSunriseLightEndMinutes
          : lightEndMinutes;

  ThemeSettings copyWith({
    AppThemePreference? preference,
    ScheduleKind? scheduleKind,
    int? lightStartMinutes,
    int? lightEndMinutes,
  }) {
    return ThemeSettings(
      preference: preference ?? this.preference,
      scheduleKind: scheduleKind ?? this.scheduleKind,
      lightStartMinutes: lightStartMinutes ?? this.lightStartMinutes,
      lightEndMinutes: lightEndMinutes ?? this.lightEndMinutes,
    );
  }
}

@immutable
class ThemeControllerState {
  const ThemeControllerState({
    required this.settings,
    required this.resolvedMode,
  });

  final ThemeSettings settings;
  final ThemeMode resolvedMode;

  ThemeControllerState copyWith({
    ThemeSettings? settings,
    ThemeMode? resolvedMode,
  }) {
    return ThemeControllerState(
      settings: settings ?? this.settings,
      resolvedMode: resolvedMode ?? this.resolvedMode,
    );
  }
}

// ── Prefs keys ─────────────────────────────────────────────────────────────

const _kPreference = 'theme_preference';
const _kScheduleKind = 'theme_schedule_kind';
const _kLightStart = 'theme_light_start_min';
const _kLightEnd = 'theme_light_end_min';
const _kLegacyMode = 'theme_mode';

// ── Pure resolve ───────────────────────────────────────────────────────────

/// Whether [nowMinutes] falls in the light window [start, end).
/// If [end] ≤ [start], the window wraps past midnight.
bool isInLightWindow({
  required int nowMinutes,
  required int start,
  required int end,
}) {
  final int n = nowMinutes.clamp(0, 24 * 60 - 1);
  final int s = start.clamp(0, 24 * 60 - 1);
  final int e = end.clamp(0, 24 * 60 - 1);
  if (s == e) return false;
  if (s < e) return n >= s && n < e;
  return n >= s || n < e;
}

int minutesOfDay(DateTime dt) => dt.hour * 60 + dt.minute;

ThemeMode resolveThemeMode(ThemeSettings settings, DateTime now) {
  switch (settings.preference) {
    case AppThemePreference.light:
      return ThemeMode.light;
    case AppThemePreference.dark:
      return ThemeMode.dark;
    case AppThemePreference.schedule:
      final bool light = isInLightWindow(
        nowMinutes: minutesOfDay(now),
        start: settings.effectiveLightStartMinutes,
        end: settings.effectiveLightEndMinutes,
      );
      return light ? ThemeMode.light : ThemeMode.dark;
  }
}

/// Next local instant when the resolved mode may change, or null if fixed.
DateTime? nextThemeBoundary(ThemeSettings settings, DateTime now) {
  if (settings.preference != AppThemePreference.schedule) return null;

  final int start = settings.effectiveLightStartMinutes;
  final int end = settings.effectiveLightEndMinutes;

  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime startDt = today.add(Duration(minutes: start));
  final DateTime endDt = today.add(Duration(minutes: end));

  if (start < end) {
    if (now.isBefore(startDt)) return startDt;
    if (now.isBefore(endDt)) return endDt;
    return today.add(const Duration(days: 1)).add(Duration(minutes: start));
  }

  // Overnight window.
  if (now.isBefore(endDt)) return endDt;
  if (now.isBefore(startDt)) return startDt;
  return today.add(const Duration(days: 1)).add(Duration(minutes: end));
}

// ── Provider ───────────────────────────────────────────────────────────────

final themeControllerProvider =
    StateNotifierProvider<ThemeController, ThemeControllerState>(
  (ref) => ThemeController(),
);

/// Resolved light/dark mode for [MaterialApp.themeMode].
final resolvedThemeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(themeControllerProvider).resolvedMode;
});

/// Full settings for Appearance UI.
final themeSettingsProvider = Provider<ThemeSettings>((ref) {
  return ref.watch(themeControllerProvider).settings;
});

class ThemeController extends StateNotifier<ThemeControllerState>
    with WidgetsBindingObserver {
  ThemeController()
      : super(
          const ThemeControllerState(
            settings: ThemeSettings.defaults,
            resolvedMode: ThemeMode.light,
          ),
        ) {
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Timer? _boundaryTimer;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _boundaryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recompute(scheduleTimer: true);
    }
  }

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final ThemeSettings settings = await _readSettings(prefs);
    if (_disposed) return;
    state = state.copyWith(settings: settings);
    _recompute(scheduleTimer: true);
  }

  Future<ThemeSettings> _readSettings(SharedPreferences prefs) async {
    final String? prefRaw = prefs.getString(_kPreference);
    if (prefRaw != null) {
      return ThemeSettings(
        preference: _parsePreference(prefRaw),
        scheduleKind: prefs.getString(_kScheduleKind) == 'sunrise'
            ? ScheduleKind.sunriseSunset
            : ScheduleKind.custom,
        lightStartMinutes: prefs.getInt(_kLightStart) ??
            ThemeSettings.defaults.lightStartMinutes,
        lightEndMinutes:
            prefs.getInt(_kLightEnd) ?? ThemeSettings.defaults.lightEndMinutes,
      );
    }

    // Legacy theme_mode migration.
    final Object? legacy = prefs.get(_kLegacyMode);
    AppThemePreference preference = AppThemePreference.light;
    if (legacy is String) {
      preference = switch (legacy) {
        'dark' => AppThemePreference.dark,
        'light' => AppThemePreference.light,
        'system' =>
          SchedulerBinding.instance.platformDispatcher.platformBrightness ==
                  Brightness.dark
              ? AppThemePreference.dark
              : AppThemePreference.light,
        _ => AppThemePreference.light,
      };
    } else if (legacy is bool) {
      preference = legacy ? AppThemePreference.dark : AppThemePreference.light;
    }

    final ThemeSettings migrated = ThemeSettings.defaults.copyWith(
      preference: preference,
    );
    await _persist(migrated);
    return migrated;
  }

  AppThemePreference _parsePreference(String raw) {
    return switch (raw) {
      'dark' => AppThemePreference.dark,
      'schedule' => AppThemePreference.schedule,
      _ => AppThemePreference.light,
    };
  }

  Future<void> _persist(ThemeSettings s) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kPreference,
      switch (s.preference) {
        AppThemePreference.light => 'light',
        AppThemePreference.dark => 'dark',
        AppThemePreference.schedule => 'schedule',
      },
    );
    await prefs.setString(
      _kScheduleKind,
      s.scheduleKind == ScheduleKind.sunriseSunset ? 'sunrise' : 'custom',
    );
    await prefs.setInt(_kLightStart, s.lightStartMinutes);
    await prefs.setInt(_kLightEnd, s.lightEndMinutes);
  }

  void _recompute({required bool scheduleTimer}) {
    final ThemeSettings settings = state.settings;
    final DateTime now = DateTime.now();
    final ThemeMode mode = resolveThemeMode(settings, now);
    state = ThemeControllerState(settings: settings, resolvedMode: mode);

    if (scheduleTimer) {
      _armBoundaryTimer(settings, now);
    }
  }

  void _armBoundaryTimer(ThemeSettings settings, DateTime now) {
    _boundaryTimer?.cancel();
    final DateTime? next = nextThemeBoundary(settings, now);
    if (next == null) return;

    Duration wait = next.difference(now);
    if (wait.isNegative || wait.inMilliseconds < 500) {
      wait = const Duration(seconds: 1);
    }
    if (wait > const Duration(hours: 24)) {
      wait = const Duration(hours: 24);
    }

    _boundaryTimer = Timer(wait, () {
      if (_disposed) return;
      _recompute(scheduleTimer: true);
    });
  }

  Future<void> setPreference(AppThemePreference preference) async {
    final ThemeSettings next = state.settings.copyWith(preference: preference);
    state = state.copyWith(settings: next);
    _recompute(scheduleTimer: true);
    await _persist(next);
  }

  Future<void> setScheduleKind(ScheduleKind kind) async {
    final ThemeSettings next = state.settings.copyWith(scheduleKind: kind);
    state = state.copyWith(settings: next);
    _recompute(scheduleTimer: true);
    await _persist(next);
  }

  Future<void> setCustomLightWindow({
    required int startMinutes,
    required int endMinutes,
  }) async {
    final ThemeSettings next = state.settings.copyWith(
      lightStartMinutes: startMinutes.clamp(0, 24 * 60 - 1),
      lightEndMinutes: endMinutes.clamp(0, 24 * 60 - 1),
    );
    state = state.copyWith(settings: next);
    _recompute(scheduleTimer: true);
    await _persist(next);
  }

  Future<void> setLightStartMinutes(int minutes) async {
    await setCustomLightWindow(
      startMinutes: minutes,
      endMinutes: state.settings.lightEndMinutes,
    );
  }

  Future<void> setLightEndMinutes(int minutes) async {
    await setCustomLightWindow(
      startMinutes: state.settings.lightStartMinutes,
      endMinutes: minutes,
    );
  }

  void refresh() => _recompute(scheduleTimer: true);
}
