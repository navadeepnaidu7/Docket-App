import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dev/dev_flags_provider.dart';
import '../data/api_session_store.dart';
import '../data/docket_api_client.dart';

final apiSessionStoreProvider = Provider<ApiSessionStore>((Ref ref) {
  return ApiSessionStore();
});

final docketApiClientProvider = Provider<DocketApiClient?>((Ref ref) {
  final (String base, String devToken) = ref.watch(
    devFlagsProvider.select(
      (flags) => (flags.apiBaseUrl.trim(), flags.devAuthIdToken.trim()),
    ),
  );
  if (base.isEmpty) return null;
  return DocketApiClient(
    baseUrl: base,
    session: ref.watch(apiSessionStoreProvider),
    devIdToken: devToken,
  );
});

final docketApiProvider = Provider<DocketApi?>((Ref ref) {
  return ref.watch(docketApiClientProvider);
});
