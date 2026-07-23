import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dev/dev_flags.dart';
import '../../../core/dev/dev_flags_provider.dart';
import '../data/mock_pass_repository.dart';
import '../data/remote_pass_repository.dart';
import '../domain/pass_catalog.dart';
import '../domain/pass_repository.dart';
import '../domain/pass_status.dart';

/// Resolves mock vs remote from [devFlagsProvider].
///
/// Override in tests:
/// ```dart
/// passRepositoryProvider.overrideWithValue(MockPassRepository(...))
/// ```
final passRepositoryProvider = Provider<PassRepository>((Ref ref) {
  final DevFlags flags = ref.watch(devFlagsProvider);
  if (flags.isMockPassesActive) {
    return MockPassRepository();
  }
  return RemotePassRepository(
    baseUrl: flags.apiBaseUrl.trim(),
    enabled: true,
  );
});

/// Async list of wallet passes (train + movie).
///
/// Rebuilds when the repository instance changes (mock ↔ remote).
final passListProvider =
    AsyncNotifierProvider<PassListNotifier, List<WalletPassItem>>(
  PassListNotifier.new,
);

class PassListNotifier extends AsyncNotifier<List<WalletPassItem>> {
  @override
  Future<List<WalletPassItem>> build() {
    // Depend on flags so toggle invalidates and reloads.
    ref.watch(devFlagsProvider);
    ref.watch(passRepositoryProvider);
    return _load();
  }

  PassRepository get _repo => ref.read(passRepositoryProvider);

  Future<List<WalletPassItem>> _load({TicketStatus? status}) {
    return _repo.fetchPasses(status: status);
  }

  /// Pull-to-refresh / retry.
  Future<void> refresh({TicketStatus? status}) async {
    state = const AsyncLoading<List<WalletPassItem>>();
    state = await AsyncValue.guard(() => _load(status: status));
  }
}

/// Convenience: active-only slice (does not re-fetch).
final activePassesProvider = Provider<AsyncValue<List<WalletPassItem>>>((
  Ref ref,
) {
  return ref.watch(passListProvider).whenData(
        (List<WalletPassItem> items) => items
            .where((WalletPassItem p) => p.status == TicketStatus.active)
            .toList(growable: false),
      );
});

/// Convenience: expired-only slice.
final expiredPassesProvider = Provider<AsyncValue<List<WalletPassItem>>>((
  Ref ref,
) {
  return ref.watch(passListProvider).whenData(
        (List<WalletPassItem> items) => items
            .where((WalletPassItem p) => p.status == TicketStatus.expired)
            .toList(growable: false),
      );
});
