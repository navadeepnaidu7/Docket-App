import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dev/dev_flags.dart';
import '../../../core/dev/dev_flags_provider.dart';
import '../data/api_session_store.dart';
import '../data/docket_api_client.dart';

final apiSessionStoreProvider = Provider<ApiSessionStore>((Ref ref) {
  return ApiSessionStore();
});

final docketApiClientProvider = Provider<DocketApiClient?>((Ref ref) {
  final DevFlags flags = ref.watch(devFlagsProvider);
  final String base = flags.apiBaseUrl.trim();
  if (base.isEmpty) return null;
  return DocketApiClient(
    baseUrl: base,
    session: ref.watch(apiSessionStoreProvider),
    devIdToken: flags.devAuthIdToken.trim().isNotEmpty
        ? flags.devAuthIdToken.trim()
        : '',
  );
});

final docketApiProvider = Provider<DocketApi?>((Ref ref) {
  return ref.watch(docketApiClientProvider);
});
