import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:docket/features/tickets/domain/pass_history_category.dart';
import 'package:docket/features/tickets/domain/movie_pass_models.dart';
import 'package:docket/features/tickets/domain/ticket_models.dart';
import 'package:docket/features/tickets/presentation/history/archive_pass_deck.dart';
import 'package:docket/features/tickets/presentation/history/movie_poster_art.dart';
import 'package:docket/features/tickets/presentation/movie/movie_ticket_face.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

TrainPass _train({
  required String id,
  required String date,
  required String destination,
}) {
  return TrainPass(
    id: id,
    operator: 'IRCTC',
    trainNumber: '12028',
    trainName: 'Shatabdi Express',
    fromCode: 'MAS',
    fromName: 'Chennai Central',
    toCode: destination.substring(0, 3).toUpperCase(),
    toName: destination,
    departTime: '06:00',
    arriveTime: '11:00',
    date: date,
    arrivalDate: date,
    duration: '5h',
    ticketClass: 'CC',
    passengers: const <TicketPassenger>[
      TicketPassenger(name: 'Test', coach: 'C3', seat: '67', berth: 'Seat'),
    ],
    pnr: '9901234567',
    bookingId: 'BK-$id',
    status: TicketStatus.expired,
  );
}

List<WalletPassItem> _items() => <WalletPassItem>[
  TrainPassItem(
    _train(id: 'jan', date: '10 Jan 2026', destination: 'Bengaluru'),
  ),
  TrainPassItem(_train(id: 'feb', date: '12 Feb 2025', destination: 'Mumbai')),
  TrainPassItem(_train(id: 'mar', date: '08 Mar 2024', destination: 'Delhi')),
];

List<WalletPassItem> _manyItems(int count) => <WalletPassItem>[
  for (int index = 0; index < count; index++)
    TrainPassItem(
      _train(
        id: 'pass-$index',
        date: '${10 + index} Jan ${2026 - index}',
        destination: 'City $index',
      ),
    ),
];

MoviePass _movie({required String id, required String title}) => MoviePass(
  id: id,
  brand: MoviePassBrand.bookMyShow,
  movieTitle: title,
  movieSubtitle: 'Drama',
  cinemaName: 'Test Cinema',
  cinemaAddress: 'Somewhere',
  screen: 'Screen 1',
  showDate: 'Mon, 10 Feb 2025',
  showTime: '7:00 PM',
  format: '2D',
  language: 'English',
  seats: const <MovieSeat>[MovieSeat(row: 'A', number: '1')],
  bookingId: 'BK-$id',
  orderId: 'OR-$id',
  status: TicketStatus.expired,
);

Future<void> _pumpDeck(
  WidgetTester tester, {
  List<WalletPassItem>? items,
}) async {
  tester.view.physicalSize = const Size(390, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: Scaffold(
        body: SafeArea(
          child: ArchivePassDeck(
            category: PassHistoryCategory.train,
            items: items ?? _items(),
            onRemove: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('centres the active pass and leaves its neighbour visible', (
    WidgetTester tester,
  ) async {
    await _pumpDeck(tester);

    final Rect viewport = tester.getRect(find.byType(ArchivePassDeck));
    final Rect active = tester.getRect(
      find.byKey(ArchivePassDeck.cardKey('jan')),
    );
    final Rect next = tester.getRect(
      find.byKey(ArchivePassDeck.cardKey('feb')),
    );

    expect(active.center.dx, closeTo(viewport.center.dx, 0.5));
    expect(next.left, lessThan(viewport.right));
    expect(next.center.dx, greaterThan(active.center.dx));
    expect(find.text('JAN'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
    expect(find.byKey(ArchivePassDeck.dialKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drag position drives the cards and dial continuously', (
    WidgetTester tester,
  ) async {
    await _pumpDeck(tester);
    final ArchivePassDeckState state = tester.state<ArchivePassDeckState>(
      find.byType(ArchivePassDeck),
    );

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ArchivePassDeck.dialKey)),
    );
    await gesture.moveBy(const Offset(-160, 0));
    await tester.pump();

    expect(state.debugPosition, greaterThan(0));
    expect(state.debugPosition, lessThan(1));
    final CustomPaint dialPaint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byKey(ArchivePassDeck.dialKey),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(
      (dialPaint.painter! as ArchiveDialPainter).position,
      closeTo(state.debugPosition, 0.001),
    );
    // The two readouts cross-fade before the swipe has committed.
    expect(find.text('JAN'), findsOneWidget);
    expect(find.text('FEB'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(state.debugPosition, closeTo(1, 0.01));
    final Rect viewport = tester.getRect(find.byType(ArchivePassDeck));
    final Rect previous = tester.getRect(
      find.byKey(ArchivePassDeck.cardKey('jan')),
    );
    final Rect next = tester.getRect(
      find.byKey(ArchivePassDeck.cardKey('mar')),
    );
    expect(previous.right, greaterThan(viewport.left));
    expect(next.left, lessThan(viewport.right));
    expect(find.text('FEB'), findsOneWidget);
    expect(find.text('2025'), findsOneWidget);
    expect(find.text('JAN'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edge drag uses resistance and returns to the first pass', (
    WidgetTester tester,
  ) async {
    await _pumpDeck(tester);
    final ArchivePassDeckState state = tester.state<ArchivePassDeckState>(
      find.byType(ArchivePassDeck),
    );

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(ArchivePassDeck)),
    );
    await gesture.moveBy(const Offset(180, 0));
    await tester.pump();

    expect(state.debugPosition, lessThan(0));
    expect(state.debugPosition, greaterThan(-0.35));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(state.debugPosition, closeTo(0, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('even a hard flick advances the deck one pass', (
    WidgetTester tester,
  ) async {
    await _pumpDeck(tester, items: _manyItems(8));
    final ArchivePassDeckState state = tester.state<ArchivePassDeckState>(
      find.byType(ArchivePassDeck),
    );

    await tester.fling(
      find.byKey(ArchivePassDeck.cardKey('pass-0')),
      const Offset(-220, 0),
      3500,
    );
    await tester.pumpAndSettle();

    // Release speed decides whether a short drag counts, never how far it
    // travels: throwing the deck several passes down loses your place. The
    // dial is what crosses an archive.
    expect(state.debugPosition, closeTo(1, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a short flick past halfway still falls back', (
    WidgetTester tester,
  ) async {
    await _pumpDeck(tester, items: _manyItems(8));
    final ArchivePassDeckState state = tester.state<ArchivePassDeckState>(
      find.byType(ArchivePassDeck),
    );

    // Dragged well short of a pass and released without speed.
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(ArchivePassDeck)),
    );
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(state.debugPosition, closeTo(0, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long drag still travels as far as the finger does', (
    WidgetTester tester,
  ) async {
    await _pumpDeck(tester, items: _manyItems(8));
    final ArchivePassDeckState state = tester.state<ArchivePassDeckState>(
      find.byType(ArchivePassDeck),
    );

    // Capping the flick must not cap the drag itself.
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(ArchivePassDeck)),
    );
    for (int step = 0; step < 12; step++) {
      await gesture.moveBy(const Offset(-72, 0));
      await tester.pump(const Duration(milliseconds: 24));
    }
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(state.debugPosition, closeTo(3, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a visible neighbour brings it to the front', (
    WidgetTester tester,
  ) async {
    await _pumpDeck(tester);
    final ArchivePassDeckState state = tester.state<ArchivePassDeckState>(
      find.byType(ArchivePassDeck),
    );

    final Rect viewport = tester.getRect(find.byType(ArchivePassDeck));
    final Rect active = tester.getRect(
      find.byKey(ArchivePassDeck.cardKey('jan')),
    );
    final Rect neighbour = tester.getRect(
      find.byKey(ArchivePassDeck.cardKey('feb')),
    );
    // The sliver of the neighbour that is on screen and not covered by the
    // focused card. Most of that card hangs off the right edge, so the
    // midpoint of its rect is not a place a finger can reach.
    final Offset exposed = Offset(
      (active.right + viewport.right) / 2,
      neighbour.center.dy,
    );
    expect(neighbour.contains(exposed), isTrue);
    expect(active.contains(exposed), isFalse);
    expect(viewport.contains(exposed), isTrue);

    await tester.tapAt(exposed);
    await tester.pumpAndSettle();

    expect(state.debugPosition, closeTo(1, 0.01));
    expect(find.text('FEB'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the ruler is drawn at the gearing the drag uses', (
    WidgetTester tester,
  ) async {
    for (final int count in <int>[3, 10, 40]) {
      await _pumpDeck(tester, items: _manyItems(count));
      final ArchivePassDeckState state = tester.state<ArchivePassDeckState>(
        find.byType(ArchivePassDeck),
      );
      final ArchiveDialPainter painter =
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byKey(ArchivePassDeck.dialKey),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as ArchiveDialPainter;

      // A pass of finger travel must move the scale by exactly a pass of
      // ticks, or the dial slips under the fingertip. On a deep archive one
      // pass is narrower than the drag slop, so cross several at once.
      final int passes = math.max(1, (40 / painter.passSpacing).ceil());
      final Rect dial = tester.getRect(find.byKey(ArchivePassDeck.dialKey));
      final double before = state.debugPosition;
      final TestGesture gesture = await tester.startGesture(dial.center);
      await gesture.moveBy(Offset(-painter.passSpacing * passes, 0));
      await tester.pump();
      expect(
        state.debugPosition - before,
        closeTo(passes, 0.01),
        reason: 'gearing disagrees with the ruler at $count passes',
      );
      await gesture.up();
      await tester.pumpAndSettle();

      // And the ticks stay legible whatever that gearing turns out to be.
      expect(painter.tickSpacing, greaterThanOrEqualTo(6.0));
      expect(painter.tickSpacing, lessThanOrEqualTo(26.0));
    }
  });

  testWidgets('the dial is an adjustable control for a screen reader', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pumpDeck(tester);
    final ArchivePassDeckState state = tester.state<ArchivePassDeckState>(
      find.byType(ArchivePassDeck),
    );

    final SemanticsFinder dial = find.semantics.byLabel(
      'Trains archive position',
    );
    expect(dial, findsOne);
    expect(
      dial.evaluate().single,
      // isSemantics, not matchesSemantics: the gesture detector below
      // contributes its own tap and scroll actions, and those are welcome.
      isSemantics(
        isSlider: true,
        hasIncreaseAction: true,
        hasDecreaseAction: false,
        label: 'Trains archive position',
        value: '1 of 3',
        increasedValue: '2 of 3',
      ),
    );

    tester.semantics.increase(dial);
    await tester.pumpAndSettle();
    expect(state.debugPosition, closeTo(1, 0.01));
    expect(state.debugFocused, 1);

    tester.semantics.decrease(dial);
    await tester.pumpAndSettle();
    expect(state.debugPosition, closeTo(0, 0.01));

    handle.dispose();
  });

  testWidgets('one dial sweep can scrub from the first to the final pass', (
    WidgetTester tester,
  ) async {
    await _pumpDeck(tester, items: _manyItems(10));
    final ArchivePassDeckState state = tester.state<ArchivePassDeckState>(
      find.byType(ArchivePassDeck),
    );
    final Finder dial = find.byKey(ArchivePassDeck.dialKey);
    final Rect dialBounds = tester.getRect(dial);
    final TestGesture gesture = await tester.startGesture(
      Offset(dialBounds.right - 24, dialBounds.center.dy),
    );

    await gesture.moveBy(const Offset(-342, 0));
    await tester.pump();
    expect(state.debugPosition, greaterThan(8.5));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(state.debugPosition, closeTo(9, 0.01));
    expect(find.text('2017'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('movie cards are poster-first with only the title below', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          body: SafeArea(
            child: ArchivePassDeck(
              category: PassHistoryCategory.movie,
              items: <WalletPassItem>[
                MoviePassItem(_movie(id: 'dune', title: 'Dune: Part Two')),
              ],
              onRemove: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(MoviePosterArt), findsOneWidget);
    expect(find.byType(MovieTicketFace), findsNothing);
    expect(find.text('Dune: Part Two'), findsOneWidget);
    final Size card = tester.getSize(
      find.byKey(ArchivePassDeck.cardKey('dune')),
    );
    expect(card.width, greaterThan(320));
    expect(card.width / card.height, closeTo(0.70, 0.01));
    expect(tester.takeException(), isNull);
  });
}
