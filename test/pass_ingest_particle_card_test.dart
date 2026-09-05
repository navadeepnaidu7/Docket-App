import 'package:docket/features/tickets/application/pass_ingest_controller.dart';
import 'package:docket/features/tickets/application/pass_ingest_service.dart';
import 'package:docket/features/tickets/data/mock_pass_fixtures.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:docket/features/tickets/domain/pass_ingest.dart';
import 'package:docket/features/tickets/domain/pass_status.dart';
import 'package:docket/features/tickets/presentation/add/pass_ingest_particle_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const PnrPassIngestRequest _request = PnrPassIngestRequest('1234567890');

Widget _host(
  PassIngestUiState state, {
  bool reduceMotion = false,
  bool isActive = true,
  VoidCallback? onFinished,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        disableAnimations: reduceMotion,
      ),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: 330,
            height: 560,
            child: PassIngestParticleCard(
              state: state,
              isActive: isActive,
              onFinished: onFinished ?? () {},
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('pauses the field and stage animation when the tab is inactive', (
    WidgetTester tester,
  ) async {
    const reading = PassIngestRunning(
      request: _request,
      phase: PassIngestPhase.readingSource,
    );
    const syncing = PassIngestRunning(
      request: _request,
      phase: PassIngestPhase.syncingWallet,
    );
    await tester.pumpWidget(_host(reading));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(_host(syncing));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(_host(syncing, isActive: false));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(_host(syncing));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion keeps the loading field static across stages', (
    WidgetTester tester,
  ) async {
    for (final phase in PassIngestPhase.values) {
      await tester.pumpWidget(
        _host(
          PassIngestRunning(request: _request, phase: phase),
          reduceMotion: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('keeps loading visual-only while preserving accessible status', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const PassIngestRunning(
          request: _request,
          phase: PassIngestPhase.syncingWallet,
        ),
        reduceMotion: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 240));

    expect(find.text('Syncing your wallet'), findsNothing);
    expect(find.text('Building your pass'), findsNothing);
    final Semantics status = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Semantics &&
            (widget.properties.label ?? '').startsWith('Syncing your wallet.'),
      ),
    );
    expect(status.properties.liveRegion, isTrue);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(find.text('Dismiss'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failure is a quiet message and clears automatically', (
    WidgetTester tester,
  ) async {
    int completions = 0;
    await tester.pumpWidget(
      _host(
        const PassIngestFailed(
          request: _request,
          error: PassIngestException(PassIngestCode.failed, 'Network down.'),
        ),
        onFinished: () => completions++,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Could not add pass'), findsOneWidget);
    expect(find.text('Network down.'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(find.text('Dismiss'), findsNothing);
    expect(completions, 0);
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump();
    expect(completions, 1);
  });

  testWidgets(
    'expired success shows only an archive message and clears automatically',
    (WidgetTester tester) async {
      final WalletPassItem expired = TrainPassItem(
        mockTrainPasses.firstWhere(
          (ticket) => ticket.status == TicketStatus.expired,
        ),
      );
      int completions = 0;
      await tester.pumpWidget(
        _host(
          PassIngestSucceeded(request: _request, item: expired),
          onFinished: () => completions++,
        ),
      );
      await tester.pump(const Duration(milliseconds: 540));

      expect(find.text('Pass archived'), findsOneWidget);
      expect(find.text('View Archive'), findsNothing);
      expect(find.text('Done'), findsNothing);
      expect(completions, 0);
      await tester.pump(const Duration(milliseconds: 1900));
      await tester.pump();
      expect(completions, 1);
    },
  );

  testWidgets(
    'active success reveals the real card before clearing the overlay',
    (WidgetTester tester) async {
      final WalletPassItem active = TrainPassItem(mockTrainPasses.first);
      int completions = 0;
      await tester.pumpWidget(
        _host(
          PassIngestSucceeded(request: _request, item: active),
          onFinished: () => completions++,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(completions, 0);
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pump();
      expect(completions, 1);
    },
  );
}
