import 'pass_catalog.dart';
import 'pass_status.dart';

/// Single source of truth for wallet passes.
///
/// Swap [MockPassRepository] → [RemotePassRepository] when APIs are ready.
abstract class PassRepository {
  /// Full list; optional [status] filters client- or server-side.
  Future<List<WalletPassItem>> fetchPasses({TicketStatus? status});

  /// Single pass by server id, or null if missing.
  Future<WalletPassItem?> fetchPassById(String id);
}
