import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_pass_repository.dart';
import '../domain/pass_catalog.dart';
import '../domain/pass_repository.dart';
import '../domain/pass_status.dart';

/// Override in tests or when switching to [RemotePassRepository]:
///
/// ```dart
/// passRepositoryProvider.overrideWithValue(RemotePassRepository(...))
/// ```
final passRepositoryProvider = Provider<PassRepository>((Ref ref) {
  return MockPassRepository();
});

/// Async list of wallet passes (train + movie).
final passListProvider =
    AsyncNotifierProvider<PassListNotifier, List<WalletPassItem>>(
  PassListNotifier.new,
);

class PassListNotifier extends AsyncNotifier<List<WalletPassItem>> {
  @override
  Future<List<WalletPassItem>> build() => _load();

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
