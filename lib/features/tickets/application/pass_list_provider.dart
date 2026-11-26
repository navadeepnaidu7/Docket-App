import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dev/dev_flags_provider.dart';
import '../../auth/application/auth_session_provider.dart';
import '../data/docket_api_client.dart';
import '../data/mock_pass_repository.dart';
import '../data/network_failure.dart';
import '../data/pass_offline_store.dart';
import '../data/remote_pass_repository.dart';
import '../domain/pass_catalog.dart';
import '../domain/pass_repository.dart';
import '../domain/pass_status.dart';
import '../data/airline_logo_cache.dart';
import 'api_providers.dart';

/// Resolves mock vs remote from [devFlagsProvider].
///
/// Override in tests:
/// ```dart
/// passRepositoryProvider.overrideWithValue(MockPassRepository(...))
/// ```
final passRepositoryProvider = Provider<PassRepository>((Ref ref) {
  final bool mock = ref.watch(
    devFlagsProvider.select((flags) => flags.isMockPassesActive),
  );
  if (mock) {
    return MockPassRepository();
  }
  final DocketApi? api = ref.watch(docketApiProvider);
  if (api == null) {
    return MockPassRepository();
  }
  final (bool signedIn, String? _) = ref.watch(
    authSessionProvider.select((session) => (session.isSignedIn, session.id)),
  );
  final bool hasDevToken = ref.watch(
    devFlagsProvider.select((flags) => flags.devAuthIdToken.trim().isNotEmpty),
  );
  if (!signedIn && !hasDevToken) {
    return const EmptyPassRepository();
  }
  return RemotePassRepository(api);
});

final passOfflineStoreProvider = Provider<PassOfflineStore>(
  (Ref ref) => PassOfflineStore(),
);

/// Where this wallet's passes are saved on the phone, or null when they are
/// not saved at all (mock passes, signed out, no API).
final passOfflineScopeProvider = Provider<String?>((Ref ref) {
  if (ref.watch(passRepositoryProvider) is! RemotePassRepository) return null;
  final String origin = ref.watch(
    devFlagsProvider.select((flags) => flags.apiBaseUrl.trim()),
  );
  final String? id = ref.watch(authSessionProvider.select((s) => s.id));
  return PassOfflineStore.scopeFor(
    origin: origin,
    account: id == null || id.isEmpty ? 'dev-token' : id,
  );
});

@immutable
class PassSyncStatus {
  const PassSyncStatus({this.offline = false, this.lastSyncedAt});

  /// The last sync could not reach the server; saved passes are showing.
  final bool offline;
  final DateTime? lastSyncedAt;
}

final passSyncStatusProvider = StateProvider<PassSyncStatus>(
  (Ref ref) => const PassSyncStatus(),
);

/// Async list of wallet passes (train + movie).
///
/// Rebuilds when the repository instance changes (mock ↔ remote).
final passListProvider =
    AsyncNotifierProvider<PassListNotifier, List<WalletPassItem>>(
      PassListNotifier.new,
    );

class PassListNotifier extends AsyncNotifier<List<WalletPassItem>> {
  Future<void> _mutate = Future<void>.value();
  Timer? _pendingRefresh;
  Timer? _reconnect;
  int _pendingAttempts = 0;
  int _generation = 0;

  @override
  Future<List<WalletPassItem>> build() async {
    // The repository watches only data-source settings; visual changes should
    // keep the loaded wallet and its scroll position intact.
    ref.watch(passRepositoryProvider);
    final String? scope = ref.watch(passOfflineScopeProvider);
    _pendingAttempts = 0;
    ref.onDispose(() {
      _generation++;
      _pendingRefresh?.cancel();
      _reconnect?.cancel();
    });
    if (scope == null) return _load();
    // Passes saved on this phone paint first; the sync below replaces them.
    final OfflinePassSnapshot? saved = await ref
        .read(passOfflineStoreProvider)
        .read(scope);
    if (saved == null) return _load();
    final int generation = _generation;
    _setSync(offline: false, at: saved.savedAt);
    unawaited(Future<void>(() => _syncSaved(generation)));
    return saved.items;
  }

  Future<void> _syncSaved(int generation) async {
    try {
      final List<WalletPassItem> items = await _load();
      if (generation == _generation) state = AsyncData(items);
    } catch (error) {
      // Saved passes stay on screen whatever the cause.
      if (generation == _generation && isNetworkFailure(error)) {
        _setSync(offline: true);
      }
    }
  }

  void _setSync({required bool offline, DateTime? at}) {
    final StateController<PassSyncStatus> sync = ref.read(
      passSyncStatusProvider.notifier,
    );
    sync.state = PassSyncStatus(
      offline: offline,
      lastSyncedAt: at ?? sync.state.lastSyncedAt,
    );
    // While offline, probe again so the wallet updates on its own once the
    // connection returns. A failed probe re-arms this timer.
    _reconnect?.cancel();
    if (offline) {
      _reconnect = Timer(const Duration(seconds: 30), () => refresh());
    }
  }

  void _save(List<WalletPassItem> items) {
    final String? scope = ref.read(passOfflineScopeProvider);
    if (scope == null) return;
    unawaited(
      ref
          .read(passOfflineStoreProvider)
          .write(scope, items)
          .catchError((Object _) {}),
    );
  }

  PassRepository get _repo => ref.read(passRepositoryProvider);

  Future<List<WalletPassItem>> _load({TicketStatus? status}) async {
    final generation = _generation;
    final items = await _repo.fetchPasses(status: status);
    // Only the unfiltered list is the whole wallet worth saving.
    if (generation == _generation && status == null) {
      _save(items);
      _setSync(offline: false, at: DateTime.now());
    }
    // Logos already on disk land before the cards first paint.
    await AirlineLogos.warm(<String>[
      for (final item in items)
        if (item is FlightPassItem) item.pass.resolvedAirlineCode,
    ]);
    if (generation == _generation) _watchPendingJourneys(items);
    return items;
  }

  void _watchPendingJourneys(List<WalletPassItem> items) {
    _pendingRefresh?.cancel();
    if (_repo is! RemotePassRepository || _pendingAttempts >= 6) return;
    if (!items.any(
      (item) => item is TrainPassItem && item.ticket.isAwaitingJourney,
    )) {
      return;
    }
    final generation = _generation;
    _pendingRefresh = Timer(
      Duration(seconds: 3 + _pendingAttempts * 3),
      () async {
        _pendingAttempts++;
        try {
          final items = await _load();
          if (generation == _generation) state = AsyncData(items);
        } catch (_) {
          // Keep the saved wallet visible during a temporary provider outage.
          if (generation == _generation) {
            _watchPendingJourneys(state.valueOrNull ?? const []);
          }
        }
      },
    );
  }

  /// Pull-to-refresh / retry.
  Future<void> refresh({TicketStatus? status}) async {
    _pendingAttempts = 0;
    // Carry the current list into the loading state. A bare AsyncLoading has no
    // value, and every derived provider that maps over this one (the archive
    // folders, the active-passes slice) would then hand its screen a spinner
    // instead of the list it is already showing, resetting scroll position.
    final AsyncValue<List<WalletPassItem>> previous = state;
    state = const AsyncLoading<List<WalletPassItem>>().copyWithPrevious(state);
    try {
      state = AsyncData(await _load(status: status));
    } catch (error, stack) {
      // Offline with passes on screen: keep them rather than an error page.
      if (isNetworkFailure(error) && previous.hasValue) {
        state = AsyncData(previous.requireValue);
        _setSync(offline: true);
      } else {
        state = AsyncError<List<WalletPassItem>>(
          error,
          stack,
        ).copyWithPrevious(previous);
      }
    }
  }

  /// Drops [id] from the wallet. The row leaves the list first; a repository
  /// failure puts the previous list back so the card does not vanish on a
  /// network error. Calls are queued so two confirms cannot interleave that
  /// rollback.
  Future<void> removePass(String id) {
    final Future<void> op = _mutate.then((_) => _removePass(id));
    _mutate = op.catchError((_) {});
    return op;
  }

  Future<void> _removePass(String id) async {
    final List<WalletPassItem>? previous = state.valueOrNull;
    if (previous != null) {
      state = AsyncData<List<WalletPassItem>>(
        previous
            .where((WalletPassItem p) => p.id != id)
            .toList(growable: false),
      );
    }
    try {
      await _repo.deletePass(id);
      final List<WalletPassItem>? current = state.valueOrNull;
      if (current != null) _save(current);
    } catch (e, st) {
      if (previous != null) {
        state = AsyncData<List<WalletPassItem>>(previous);
      }
      Error.throwWithStackTrace(e, st);
    }
  }
}

/// Convenience: active-only slice (does not re-fetch).
final activePassesProvider = Provider<AsyncValue<List<WalletPassItem>>>((
  Ref ref,
) {
  return ref
      .watch(passListProvider)
      .whenData(
        (List<WalletPassItem> items) => items
            .where((WalletPassItem p) => p.status == TicketStatus.active)
            .toList(growable: false),
      );
});
