import '../domain/pass_catalog.dart';
import '../domain/pass_repository.dart';
import '../domain/pass_status.dart';
import 'mock_pass_fixtures.dart';

/// Local fixtures — same cards as the previous hardcoded Passes tab.
class MockPassRepository implements PassRepository {
  MockPassRepository({
    List<WalletPassItem>? seed,
    this.artificialDelay = const Duration(milliseconds: 280),
  }) : _items = seed ??
            buildWalletPassCatalog(
              trains: mockTrainPasses,
              movies: mockMoviePasses,
              buses: mockBusPasses,
            );

  final List<WalletPassItem> _items;
  final Duration artificialDelay;

  Future<void> _simulateLatency() async {
    if (artificialDelay > Duration.zero) {
      await Future<void>.delayed(artificialDelay);
    }
  }

  @override
  Future<List<WalletPassItem>> fetchPasses({TicketStatus? status}) async {
    await _simulateLatency();
    if (status == null) return List<WalletPassItem>.unmodifiable(_items);
    return List<WalletPassItem>.unmodifiable(
      _items.where((WalletPassItem p) => p.status == status),
    );
  }

  @override
  Future<WalletPassItem?> fetchPassById(String id) async {
    await _simulateLatency();
    for (final WalletPassItem p in _items) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<void> deletePass(String id) async {
    await _simulateLatency();
    _items.removeWhere((WalletPassItem p) => p.id == id);
  }
}

/// Signed-out remote wallet: nothing to show, no network.
class EmptyPassRepository implements PassRepository {
  const EmptyPassRepository();

  @override
  Future<List<WalletPassItem>> fetchPasses({TicketStatus? status}) async =>
      const <WalletPassItem>[];

  @override
  Future<WalletPassItem?> fetchPassById(String id) async => null;

  @override
  Future<void> deletePass(String id) async {}
}
