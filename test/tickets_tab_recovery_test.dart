import 'package:docket/core/dev/dev_flags.dart';
import 'package:docket/core/dev/dev_flags_provider.dart';
import 'package:docket/features/tickets/application/pass_ingest_controller.dart';
import 'package:docket/features/tickets/application/pass_ingest_service.dart';
import 'package:docket/features/tickets/application/pass_list_provider.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:docket/features/tickets/domain/pass_ingest.dart';
import 'package:docket/features/tickets/presentation/tickets_tab.dart';
import 'package:docket/features/tickets/presentation/add/pass_ingest_particle_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Ingest extends PassIngestController {
  _Ingest(this.initial);
  final PassIngestUiState initial;
  @override
  PassIngestUiState build() => initial;
  @override
  void retry() => state = const PassIngestRunning(
    request: PnrPassIngestRequest('1234567890'),
    phase: PassIngestPhase.submitting,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<ProviderContainer> pump(
    WidgetTester tester,
    PassIngestUiState state,
  ) async {
    final container = ProviderContainer(
      overrides: [
        passIngestControllerProvider.overrideWith(() => _Ingest(state)),
        activePassesProvider.overrideWith((ref) => const AsyncData([])),
        devFlagsProvider.overrideWith(
          (ref) => DevFlagsNotifier.fixed(
            const DevFlags(useMockPasses: true, apiBaseUrl: ''),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: TicketsTab(isActive: true)),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('tab keeps failed request and retries through its controller', (
    tester,
  ) async {
    final container = await pump(
      tester,
      const PassIngestFailed(
        request: PnrPassIngestRequest('1234567890'),
        error: PassIngestException(
          PassIngestCode.failed,
          'Connection interrupted.',
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 30));
    expect(
      container.read(passIngestControllerProvider),
      isA<PassIngestFailed>(),
    );
    expect(find.text('Sample passes · For exploring Docket'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(
      container.read(passIngestControllerProvider),
      isA<PassIngestRunning>(),
    );
    expect(find.text('Preparing your pass…'), findsNothing);
    expect(find.byType(PassIngestParticleCard), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'archived success names the ticket, then clears without a result page',
    (tester) async {
      final item = MoviePassItem.fromJson({
        'id': 'archive',
        'movieTitle': 'Arrival',
        'status': 'expired',
      });
      final container = await pump(
        tester,
        PassIngestSucceeded(
          request: const PnrPassIngestRequest('1234567890'),
          item: item,
        ),
      );
      await tester.pump(const Duration(milliseconds: 540));
      expect(find.text('Your movie ticket is in Archive'), findsOneWidget);
      expect(find.text('View pass'), findsNothing);
      expect(find.text('Pass added'), findsNothing);
      expect(
        container.read(passIngestControllerProvider),
        isA<PassIngestSucceeded>(),
      );
      await tester.pump(const Duration(milliseconds: 1900));
      await tester.pump();
      expect(
        container.read(passIngestControllerProvider),
        isA<PassIngestIdle>(),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
