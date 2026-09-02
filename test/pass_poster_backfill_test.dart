import 'package:docket/core/dev/dev_flags.dart';
import 'package:docket/core/dev/dev_flags_provider.dart';
import 'package:docket/features/tickets/application/pass_ingest_service.dart';
import 'package:docket/features/tickets/data/docket_api_client.dart';
import 'package:docket/features/tickets/domain/movie_pass_models.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:docket/features/tickets/domain/pass_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The server saves a movie ticket before its poster exists — extraction returns immediately
/// and the TMDB lookup runs on the worker. These tests pin the client-side backfill that
/// closes that window, because nothing else re-reads an already-added pass.

const String _posterUrl = 'https://api.test/img/poster/w500/abc.jpg';

MoviePassItem _movie({String? posterUrl}) {
  return MoviePassItem(
    MoviePass.fromJson(<String, dynamic>{
      'id': 'm1',
      'movieTitle': 'Irumudi',
      'status': 'expired',
      if (posterUrl != null) 'posterUrl': posterUrl,
    }),
  );
}

class _FakeApi implements DocketApi {
  _FakeApi({this.posterFromCall = 1, this.throwOnFetchById = false});

  /// 1-indexed: the fetchPassById call at which a poster starts coming back.
  final int posterFromCall;
  final bool throwOnFetchById;

  int fetchByIdCalls = 0;
  int fetchPassesCalls = 0;

  @override
  Future<WalletPassItem?> fetchPassById(String id) async {
    fetchByIdCalls++;
    if (throwOnFetchById && fetchByIdCalls > 1) {
      throw Exception('network down');
    }
    return fetchByIdCalls >= posterFromCall
        ? _movie(posterUrl: _posterUrl)
        : _movie();
  }

  @override
  Future<PassListResponse> fetchPasses({TicketStatus? status}) async {
    fetchPassesCalls++;
    return const PassListResponse(items: <WalletPassItem>[]);
  }

  @override
  Future<String> extractFile({
    required List<int> bytes,
    required String filename,
    required String mimeType,
    required String categoryHint,
  }) async =>
      'm1';

  @override
  Future<String> createFromPnr(String pnr) async => 'm1';

  @override
  Future<void> deletePass(String id) async {}
}

ProviderContainer _container(_FakeApi api) {
  return ProviderContainer(
    overrides: <Override>[
      devFlagsProvider.overrideWith(
        (Ref ref) => DevFlagsNotifier.fixed(
          const DevFlags(useMockPasses: false, apiBaseUrl: 'https://api.test'),
        ),
      ),
      docketApiProvider.overrideWithValue(api),
    ],
  );
}

void main() {
  testWidgets('a pass saved without a poster is re-read until one arrives',
      (WidgetTester tester) async {
    final _FakeApi api = _FakeApi(posterFromCall: 2);
    final ProviderContainer c = _container(api);
    addTearDown(c.dispose);

    await c.read(passIngestServiceProvider).submitPnr('1234567890');
    expect(api.fetchByIdCalls, 1, reason: 'the initial read happens inline');

    // First backfill probe lands at +2s and already has the poster.
    await tester.pump(const Duration(seconds: 3));
    expect(api.fetchByIdCalls, 2);

    // Having found it, the loop stops rather than running its remaining probes.
    await tester.pump(const Duration(seconds: 20));
    expect(api.fetchByIdCalls, 2);
  });

  testWidgets('backfill gives up when no poster ever arrives',
      (WidgetTester tester) async {
    // Never returns a poster: TMDB has no match, or the server scored it below threshold.
    final _FakeApi api = _FakeApi(posterFromCall: 9999);
    final ProviderContainer c = _container(api);
    addTearDown(c.dispose);

    await c.read(passIngestServiceProvider).submitPnr('1234567890');
    await tester.pump(const Duration(seconds: 60));

    // One inline read plus exactly three bounded probes, then it stops for good.
    expect(api.fetchByIdCalls, 4);
  });

  testWidgets('a pass that already has a poster is not polled at all',
      (WidgetTester tester) async {
    final _FakeApi api = _FakeApi(posterFromCall: 1);
    final ProviderContainer c = _container(api);
    addTearDown(c.dispose);

    await c.read(passIngestServiceProvider).submitPnr('1234567890');
    await tester.pump(const Duration(seconds: 60));

    expect(api.fetchByIdCalls, 1);
  });

  testWidgets('a failed probe abandons the backfill instead of surfacing an error',
      (WidgetTester tester) async {
    final _FakeApi api = _FakeApi(posterFromCall: 9999, throwOnFetchById: true);
    final ProviderContainer c = _container(api);
    addTearDown(c.dispose);

    // The pass is already saved, so a dead network here must stay silent.
    await c.read(passIngestServiceProvider).submitPnr('1234567890');
    await tester.pump(const Duration(seconds: 60));

    expect(api.fetchByIdCalls, 2, reason: 'stops at the first failure');
  });
}
