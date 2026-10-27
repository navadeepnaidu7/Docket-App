import 'package:docket/features/tickets/application/pass_list_provider.dart';
import 'package:docket/features/tickets/data/docket_api_client.dart';
import 'package:docket/features/tickets/data/remote_pass_repository.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:docket/features/tickets/domain/pass_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _TrainApi implements DocketApi {
  int fetches = 0;
  bool ready = false;
  bool offline = false;

  @override
  Future<PassListResponse> fetchPasses({TicketStatus? status}) async {
    fetches++;
    if (offline) throw StateError('Offline');
    return PassListResponse(
      items: [
        TrainPassItem.fromJson({
          'id': 'saved-pnr',
          'pnr': '1234567890',
          'status': 'active',
          if (ready) 'trainNumber': '12345',
        }),
      ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('pending train refresh replaces saved PNR and then stops', (
    tester,
  ) async {
    final api = _TrainApi();
    final container = ProviderContainer(
      overrides: [
        passRepositoryProvider.overrideWithValue(RemotePassRepository(api)),
      ],
    );
    addTearDown(container.dispose);
    final first = await container.read(passListProvider.future);
    expect((first.single as TrainPassItem).ticket.isAwaitingJourney, isTrue);
    api.ready = true;
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    final fresh =
        container.read(passListProvider).requireValue.single as TrainPassItem;
    expect(fresh.ticket.trainNumber, '12345');
    await tester.pump(const Duration(minutes: 2));
    expect(api.fetches, 2);
  });

  testWidgets('outage retains saved PNR and automatic retries are bounded', (
    tester,
  ) async {
    final api = _TrainApi();
    final container = ProviderContainer(
      overrides: [
        passRepositoryProvider.overrideWithValue(RemotePassRepository(api)),
      ],
    );
    await container.read(passListProvider.future);
    api.offline = true;
    for (var attempt = 0; attempt < 6; attempt++) {
      await tester.pump(Duration(seconds: 3 + attempt * 3));
      await tester.pump();
      expect(
        container.read(passListProvider).requireValue.single.id,
        'saved-pnr',
      );
    }
    await tester.pump(const Duration(minutes: 2));
    expect(api.fetches, 7);
    container.dispose();
    await tester.pump(const Duration(minutes: 2));
    expect(api.fetches, 7);
  });
}
