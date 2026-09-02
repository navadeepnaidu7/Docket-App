import '../domain/pass_catalog.dart';
import '../domain/pass_repository.dart';
import '../domain/pass_status.dart';
import 'docket_api_client.dart';

/// HTTP-backed repository against `GET /v1/passes`.
class RemotePassRepository implements PassRepository {
  RemotePassRepository(this._api);

  final DocketApi _api;

  @override
  Future<List<WalletPassItem>> fetchPasses({TicketStatus? status}) {
    return _api.fetchPasses(status: status).then(
          (PassListResponse res) => res.items,
        );
  }

  @override
  Future<WalletPassItem?> fetchPassById(String id) {
    return _api.fetchPassById(id);
  }

  @override
  Future<void> deletePass(String id) {
    return _api.deletePass(id);
  }
}

/// Documented paths for the backend contract (see docs/api/passes.md).
abstract final class PassApiPaths {
  PassApiPaths._();

  static const String passes = '/v1/passes';
  static String passById(String id) => '/v1/passes/$id';
  static String liveStatus(String id) => '/v1/passes/$id/live';
  static String code(String id) => '/v1/passes/$id/code';
  static const String extract = '/tickets/extract';
  static const String tickets = '/tickets';
  static const String authGoogle = '/v1/auth/google';
  static const String authRefresh = '/v1/auth/refresh';
}
