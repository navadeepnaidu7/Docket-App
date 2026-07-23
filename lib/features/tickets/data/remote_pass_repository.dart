import '../domain/pass_catalog.dart';
import '../domain/pass_repository.dart';
import '../domain/pass_status.dart';

/// HTTP-backed repository — wire [PassApiPaths] when backend ships.
///
/// Default behaviour: empty list so the app does not crash if switched early.
/// Set [enabled] true and inject an HTTP client before production use.
class RemotePassRepository implements PassRepository {
  RemotePassRepository({
    this.baseUrl = '',
    this.enabled = false,
  });

  /// e.g. `https://api.example.com`
  final String baseUrl;

  /// When false, methods return empty / null (safe stub).
  final bool enabled;

  @override
  Future<List<WalletPassItem>> fetchPasses({TicketStatus? status}) async {
    if (!enabled || baseUrl.isEmpty) {
      return const <WalletPassItem>[];
    }
    // TODO(backend): GET $baseUrl${PassApiPaths.passes}
    //   query: status?.name
    //   headers: Authorization Bearer …
    //   body → PassListResponse.fromJson
    throw UnimplementedError(
      'RemotePassRepository.fetchPasses: implement HTTP against '
      '${PassApiPaths.passes}',
    );
  }

  @override
  Future<WalletPassItem?> fetchPassById(String id) async {
    if (!enabled || baseUrl.isEmpty) return null;
    // TODO(backend): GET $baseUrl${PassApiPaths.passById(id)}
    throw UnimplementedError(
      'RemotePassRepository.fetchPassById: implement HTTP against '
      '${PassApiPaths.passById(id)}',
    );
  }
}

/// Documented paths for the backend contract (see docs/api/passes.md).
abstract final class PassApiPaths {
  PassApiPaths._();

  static const String passes = '/v1/passes';
  static String passById(String id) => '/v1/passes/$id';
  static String liveStatus(String id) => '/v1/passes/$id/live';
  static String code(String id) => '/v1/passes/$id/code';
}
