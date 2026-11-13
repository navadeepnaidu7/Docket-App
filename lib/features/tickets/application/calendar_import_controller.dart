import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/dev/dev_flags_provider.dart';
import '../data/docket_api_client.dart';
import '../domain/calendar_import.dart';
import '../domain/pass_ingest.dart';
import 'api_providers.dart';
import 'pass_list_provider.dart';

/// The calendar endpoints. Null in mock mode or with no API URL, so mock mode can never
/// pretend a real calendar is linked.
final calendarImportApiProvider = Provider<CalendarImportApi?>((Ref ref) {
  final bool mock = ref.watch(
    devFlagsProvider.select((flags) => flags.isMockPassesActive),
  );
  if (mock) return null;
  return ref.watch(docketApiClientProvider);
});

typedef ExternalUrlLauncher = Future<bool> Function(Uri uri);

/// Opens Google's consent page in the system browser (never an in-app web view, which
/// Google refuses for OAuth and which would let the app observe the password page).
final calendarUrlLauncherProvider = Provider<ExternalUrlLauncher>((Ref ref) {
  return (Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
});

enum CalendarImportPhase { idle, loading, authorizing, syncing, disconnecting }

@immutable
class CalendarImportState {
  const CalendarImportState({
    this.status,
    this.phase = CalendarImportPhase.loading,
    this.error,
  });

  final CalendarConnectionStatus? status;
  final CalendarImportPhase phase;
  final String? error;

  bool get busy => phase != CalendarImportPhase.idle;

  CalendarImportState copyWith({
    CalendarConnectionStatus? status,
    CalendarImportPhase? phase,
    String? error,
    bool clearError = false,
  }) {
    return CalendarImportState(
      status: status ?? this.status,
      phase: phase ?? this.phase,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final calendarImportProvider =
    StateNotifierProvider.autoDispose<
      CalendarImportController,
      CalendarImportState
    >((Ref ref) {
      return CalendarImportController(ref);
    });

/// Drives the Calendar connection screen.
///
/// Sync is server-side and asynchronous: after connect or "Sync now" this polls status a
/// bounded number of times and refreshes the wallet once a run has finished. Nothing here
/// waits for the browser; the screen calls [onAppResumed] when the user comes back.
class CalendarImportController extends StateNotifier<CalendarImportState> {
  CalendarImportController(
    this._ref, {
    this.pollInterval = const Duration(seconds: 5),
    this.pollAttempts = 12,
  }) : super(const CalendarImportState()) {
    unawaited(refresh());
  }

  final Ref _ref;
  final Duration pollInterval;
  final int pollAttempts;
  int _pollGeneration = 0;

  CalendarImportApi? get _api => _ref.read(calendarImportApiProvider);

  Future<void> refresh() async {
    final CalendarImportApi? api = _api;
    if (api == null) {
      state = const CalendarImportState(
        status: CalendarConnectionStatus.mockMode,
        phase: CalendarImportPhase.idle,
      );
      return;
    }
    try {
      final CalendarConnectionStatus status = await api.fetchCalendarStatus();
      if (!mounted) return;
      final bool keepAuthorizing =
          state.phase == CalendarImportPhase.authorizing && !status.isLinked;
      state = CalendarImportState(
        status: status,
        phase: keepAuthorizing
            ? CalendarImportPhase.authorizing
            : (state.phase == CalendarImportPhase.syncing
                  ? CalendarImportPhase.syncing
                  : CalendarImportPhase.idle),
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        phase: CalendarImportPhase.idle,
        error: _message(e),
      );
    }
  }

  Future<void> connect() async {
    final CalendarImportApi? api = _api;
    if (api == null ||
        state.busy && state.phase != CalendarImportPhase.authorizing) {
      return;
    }
    state = state.copyWith(
      phase: CalendarImportPhase.loading,
      clearError: true,
    );
    try {
      final Uri url = await api.startCalendarConnect();
      final bool opened = await _ref.read(calendarUrlLauncherProvider)(url);
      if (!mounted) return;
      state = state.copyWith(
        phase: opened
            ? CalendarImportPhase.authorizing
            : CalendarImportPhase.idle,
        error: opened ? null : 'Could not open the browser.',
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        phase: CalendarImportPhase.idle,
        error: _message(e),
      );
    }
  }

  /// The user returned from the browser (or cancelled). The server is the source of truth.
  Future<void> onAppResumed() async {
    if (state.phase != CalendarImportPhase.authorizing) return;
    final bool wasLinked = state.status?.isLinked ?? false;
    final DateTime? previousSync = state.status?.lastSyncAt;
    await refresh();
    if (!mounted) return;
    final CalendarConnectionStatus? status = state.status;
    if (status != null && status.isLinked) {
      state = state.copyWith(phase: CalendarImportPhase.syncing);
      unawaited(_awaitSync(wasLinked ? previousSync : null));
    }
  }

  void cancelAuthorizing() {
    if (state.phase == CalendarImportPhase.authorizing) {
      state = state.copyWith(phase: CalendarImportPhase.idle);
    }
  }

  Future<void> syncNow() async {
    final CalendarImportApi? api = _api;
    if (api == null || state.busy) return;
    final DateTime? before = state.status?.lastSyncAt;
    state = state.copyWith(
      phase: CalendarImportPhase.syncing,
      clearError: true,
    );
    try {
      final CalendarConnectionStatus status = await api.requestCalendarSync();
      if (!mounted) return;
      state = state.copyWith(status: status);
      unawaited(_awaitSync(before));
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        phase: CalendarImportPhase.idle,
        error: _message(e),
      );
    }
  }

  Future<void> disconnect() async {
    final CalendarImportApi? api = _api;
    if (api == null || state.busy) return;
    _pollGeneration++;
    state = state.copyWith(
      phase: CalendarImportPhase.disconnecting,
      clearError: true,
    );
    try {
      await api.disconnectCalendar();
      if (!mounted) return;
      state = state.copyWith(phase: CalendarImportPhase.idle);
      await refresh();
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        phase: CalendarImportPhase.idle,
        error: _message(e),
      );
    }
  }

  /// Polls until a sync run newer than [since] has finished, then refreshes the wallet.
  Future<void> _awaitSync(DateTime? since) async {
    final int generation = ++_pollGeneration;
    final CalendarImportApi? api = _api;
    if (api == null) return;
    for (int i = 0; i < pollAttempts; i++) {
      await Future<void>.delayed(pollInterval);
      if (!mounted || generation != _pollGeneration) return;
      try {
        final CalendarConnectionStatus status = await api.fetchCalendarStatus();
        if (!mounted || generation != _pollGeneration) return;
        final DateTime? last = status.lastSyncAt;
        final bool finished =
            status.state != CalendarLinkState.syncing &&
            last != null &&
            (since == null || last.isAfter(since));
        if (finished || !status.isLinked) {
          state = CalendarImportState(
            status: status,
            phase: CalendarImportPhase.idle,
          );
          if (status.lastSuccessfulSyncAt != null) {
            await _ref.read(passListProvider.notifier).refresh();
          }
          return;
        }
        state = state.copyWith(status: status);
      } catch (_) {
        // Keep polling; a transient network blip should not strand the spinner.
      }
    }
    if (mounted && generation == _pollGeneration) {
      // The run is still queued; it will land in the background regardless.
      state = state.copyWith(phase: CalendarImportPhase.idle);
    }
  }

  String _message(Object e) => switch (e) {
    CalendarImportException(:final String message) => message,
    PassIngestException(:final String message) => message,
    _ => 'Could not reach the server. Try again.',
  };
}
