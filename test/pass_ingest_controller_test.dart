import 'dart:async';

import 'package:docket/core/dev/dev_flags.dart';
import 'package:docket/core/dev/dev_flags_provider.dart';
import 'package:docket/features/tickets/application/pass_ingest_controller.dart';
import 'package:docket/features/tickets/application/pass_ingest_service.dart';
import 'package:docket/features/tickets/application/ticket_code_scanner.dart';
import 'package:docket/features/tickets/data/docket_api_client.dart';
import 'package:docket/features/tickets/data/mock_pass_fixtures.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:docket/features/tickets/domain/pass_ingest.dart';
import 'package:docket/features/tickets/domain/pass_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApi implements DocketApi {
  _FakeApi(this.item);

  final WalletPassItem item;
  Completer<String>? pendingCreate;
  bool failCreate = false;
  int listFetches = 0;

  @override
  Future<String> createFromPnr(String pnr) async {
    if (failCreate) {
      throw const PassIngestException(PassIngestCode.failed, 'Offline.');
    }
    final Completer<String>? pending = pendingCreate;
    if (pending != null) return pending.future;
    return item.id;
  }

  @override
  Future<WalletPassItem?> fetchPassById(String id) async => item;

  @override
  Future<PassListResponse> fetchPasses({TicketStatus? status}) async {
    listFetches++;
    return PassListResponse(items: <WalletPassItem>[item]);
  }

  @override
  Future<String> extractFile({
    required List<int> bytes,
    required String filename,
    required String mimeType,
    required String categoryHint,
    ScannedTicketCode? code,
  }) async => item.id;

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
  testWidgets(
    'reports real phases, rejects overlap, and refreshes before success',
    (WidgetTester tester) async {
      final WalletPassItem item = TrainPassItem(mockTrainPasses.first);
      final _FakeApi api = _FakeApi(item)..pendingCreate = Completer<String>();
      final ProviderContainer container = _container(api);
      addTearDown(container.dispose);

      final List<PassIngestUiState> states = <PassIngestUiState>[];
      final ProviderSubscription<PassIngestUiState> subscription = container
          .listen<PassIngestUiState>(
            passIngestControllerProvider,
            (_, PassIngestUiState next) => states.add(next),
            fireImmediately: true,
          );
      addTearDown(subscription.close);

      final PassIngestController controller = container.read(
        passIngestControllerProvider.notifier,
      );
      expect(controller.startPnr('1234567890'), isTrue);
      expect(controller.startPnr('0987654321'), isFalse);
      expect(
        container.read(passIngestControllerProvider),
        isA<PassIngestRunning>(),
      );

      api.pendingCreate!.complete(item.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 710));

      expect(
        states.whereType<PassIngestRunning>().map((state) => state.phase),
        contains(PassIngestPhase.syncingWallet),
      );
      expect(api.listFetches, greaterThan(0));
      expect(
        container.read(passIngestControllerProvider),
        isA<PassIngestSucceeded>(),
      );

      controller.finishSuccess();
      expect(
        container.read(passIngestControllerProvider),
        isA<PassIngestIdle>(),
      );
    },
  );

  testWidgets('failure retains the request for retry and dismiss clears it', (
    WidgetTester tester,
  ) async {
    final _FakeApi api = _FakeApi(TrainPassItem(mockTrainPasses.first))
      ..failCreate = true;
    final ProviderContainer container = _container(api);
    addTearDown(container.dispose);
    final PassIngestController controller = container.read(
      passIngestControllerProvider.notifier,
    );

    expect(controller.startPnr('1234567890'), isTrue);
    await tester.pump();
    final PassIngestFailed failed =
        container.read(passIngestControllerProvider) as PassIngestFailed;
    expect((failed.request as PnrPassIngestRequest).pnr, '1234567890');
    expect(failed.error.message, 'Offline.');

    api.failCreate = false;
    controller.retry();
    expect(
      container.read(passIngestControllerProvider),
      isA<PassIngestRunning>(),
    );
    await tester.pump(const Duration(milliseconds: 710));
    expect(
      container.read(passIngestControllerProvider),
      isA<PassIngestSucceeded>(),
    );

    controller.dismiss();
    expect(container.read(passIngestControllerProvider), isA<PassIngestIdle>());
  });

  test('invalid PNR never starts an operation', () {
    final ProviderContainer container = _container(
      _FakeApi(TrainPassItem(mockTrainPasses.first)),
    );
    addTearDown(container.dispose);

    expect(
      container.read(passIngestControllerProvider.notifier).startPnr('123'),
      isFalse,
    );
    expect(container.read(passIngestControllerProvider), isA<PassIngestIdle>());
  });
}
