// Render with: flutter test tool/pass_particle_preview_test.dart --update-goldens
// Outputs go to build/particle-preview, outside the checked-in golden suite.
import 'package:docket/features/tickets/application/pass_ingest_controller.dart';
import 'package:docket/features/tickets/application/pass_ingest_service.dart';
import 'package:docket/features/tickets/data/mock_pass_fixtures.dart';
import 'package:docket/features/tickets/presentation/add/pass_ingest_particle_card.dart';
import 'package:docket/features/tickets/presentation/train/train_ticket_face.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('particle contact sheet', (tester) async {
    tester.view.physicalSize = const Size(1320, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Row(
          children: [
            for (final (dark, withTicket) in [
              (false, false),
              (true, false),
              (false, true),
              (true, true),
            ])
              Expanded(
                child: Theme(
                  data: ThemeData(
                    brightness: dark ? Brightness.dark : Brightness.light,
                  ),
                  child: ColoredBox(
                    color: dark
                        ? const Color(0xFF101012)
                        : const Color(0xFFF5F5F7),
                    child: ClipRect(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (withTicket)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: FittedBox(
                                child: SizedBox(
                                  width: 366,
                                  height: 630,
                                  child: TrainTicketFace(
                                    ticket: mockTrainPasses.first,
                                    density: TrainTicketDensity.glance,
                                    clock: () => DateTime(2026, 8, 13, 9),
                                  ),
                                ),
                              ),
                            ),
                          PassIngestParticleCard(
                            state: const PassIngestRunning(
                              request: PnrPassIngestRequest('1234567890'),
                              phase: PassIngestPhase.submitting,
                            ),
                            isActive: true,
                            onFinished: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));
    const label = String.fromEnvironment(
      'PREVIEW_LABEL',
      defaultValue: 'after',
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../build/particle-preview/$label.png'),
    );
    for (final frame in ['mid', 'late']) {
      await tester.pump(const Duration(milliseconds: 2000));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../build/particle-preview/${label}_$frame.png'),
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
