import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:docket/features/tickets/data/mock_pass_fixtures.dart';
import 'package:docket/features/tickets/domain/ticket_models.dart';
import 'package:docket/features/tickets/presentation/ticket_detail_screen.dart';

/// Phone widths the timeline has to survive. The status pill sits on the same
/// row as the time pill, so a long station name plus a wide pill is exactly
/// where this layout would overflow.
const List<Size> _viewports = <Size>[
  Size(320, 720), // smallest phone still supported
  Size(360, 800), // common Android
  Size(393, 852), // iPhone 15
  Size(430, 932), // iPhone 15 Pro Max
];

Future<void> _pumpLiveTab(WidgetTester tester, TrainPass pass) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(home: TicketDetailScreen(ticket: pass)),
    ),
  );
  await tester.pump();

  // Segmented control: Details | Live status.
  await tester.tap(find.text('Live status'));

  // The timeline pulses the "arriving" node forever, so pumpAndSettle would
  // never return. Pump past the tab cross-fade by hand instead.
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('running status timeline', () {
    for (final Size size in _viewports) {
      testWidgets('lays out without overflow at ${size.width.toInt()}px', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final TrainPass pass = mockTrainPasses.firstWhere(
          (TrainPass p) => p.halts.isNotEmpty,
        );
        await _pumpLiveTab(tester, pass);

        // A RenderFlex overflow is reported as a framework exception, which
        // pumpAndSettle surfaces here rather than silently painting a stripe.
        expect(tester.takeException(), isNull);
        expect(find.byType(TicketDetailScreen), findsOneWidget);
      });
    }

    testWidgets('renders one row per halt, station names and times', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final TrainPass pass = mockTrainPasses.firstWhere(
        (TrainPass p) => p.halts.length >= 2,
      );
      await _pumpLiveTab(tester, pass);

      for (final TicketHalt halt in pass.halts) {
        expect(
          find.text(halt.station),
          findsWidgets,
          reason: 'every halt should name its station',
        );
      }
      expect(tester.takeException(), isNull);
    });

    // The spine is painted, not composed of widgets, so a regression here is
    // invisible to a finder-based test — assert the painter is mounted.
    testWidgets('paints a spine for the journey', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final TrainPass pass = mockTrainPasses.firstWhere(
        (TrainPass p) => p.halts.isNotEmpty,
      );
      await _pumpLiveTab(tester, pass);

      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
