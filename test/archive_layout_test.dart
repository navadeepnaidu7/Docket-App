import 'package:docket/features/tickets/domain/history_folder.dart';
import 'package:docket/features/tickets/domain/movie_pass_models.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:docket/features/tickets/domain/pass_history_category.dart';
import 'package:docket/features/tickets/domain/ticket_models.dart';
import 'package:docket/features/tickets/presentation/history/history_folder_tile.dart';
import 'package:docket/features/tickets/presentation/history/history_pass_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixtures carry no posterUrl/posterAsset so nothing here touches the network.
MoviePass movie({required String id, required String title}) {
  return MoviePass(
    id: id,
    brand: MoviePassBrand.universal,
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
}

TrainPass train({required String id}) {
  return TrainPass(
    id: id,
    operator: 'IRCTC',
    trainNumber: '12028',
    trainName: 'Shatabdi Express',
    fromCode: 'MAS',
    fromName: 'Chennai Central',
    toCode: 'SBC',
    toName: 'KSR Bengaluru',
    departTime: '06:00',
    arriveTime: '11:00',
    date: '03 Sep 2023',
    arrivalDate: '03 Sep 2023',
    duration: '5h',
    ticketClass: 'CC',
    passengers: const <TicketPassenger>[
      TicketPassenger(name: 'Test', coach: 'C3', seat: '67', berth: 'Seat'),
    ],
    pnr: '9901234567',
    bookingId: 'E0',
    status: TicketStatus.expired,
  );
}

HistoryFolderSummary folder(List<WalletPassItem> items) {
  return HistoryFolderSummary(
    category: items.first.kind.historyCategory,
    count: items.length,
    items: items,
    lastAddedLabel: 'Last added 10 Feb 2025',
  );
}

/// One grid cell on a 390dp-wide phone: (390 - 40 gutters - 16 spacing) / 2.
const Size _cell = Size(167, 167 / HistoryFolderTile.aspectRatio);

void main() {
  Future<void> pumpTile(
    WidgetTester tester,
    HistoryFolderSummary summary, {
    Brightness brightness = Brightness.light,
    double textScale = 1.0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Scaffold(
          body: Center(
            child: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: SizedBox(
                width: _cell.width,
                height: _cell.height,
                child: HistoryFolderTile(folder: summary, onTap: () {}),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('HistoryFolderTile', () {
    testWidgets('lays out a movie folder', (WidgetTester t) async {
      await pumpTile(
        t,
        folder(<WalletPassItem>[
          MoviePassItem(movie(id: 'a', title: 'Dune: Part Two')),
          MoviePassItem(movie(id: 'b', title: 'Kalki 2898 AD')),
          MoviePassItem(movie(id: 'c', title: 'Pushpa 2')),
        ]),
      );

      expect(takeLayoutError(), isNull);
      expect(find.text('Movies'), findsOneWidget);
      expect(find.text('3 passes'), findsOneWidget);
      expect(find.text('Last added 10 Feb 2025'), findsNothing);
      // The whole tile is the target; a per-tile arrow badge would be chrome.
      expect(find.byIcon(Icons.arrow_outward_rounded), findsNothing);
      expect(find.bySemanticsLabel('Movies, 3 passes'), findsOneWidget);
    });

    testWidgets('lays out a train folder without peeking contents', (
      WidgetTester t,
    ) async {
      await pumpTile(
        t,
        folder(<WalletPassItem>[
          TrainPassItem(train(id: 'a')),
          TrainPassItem(train(id: 'b')),
        ]),
      );

      expect(takeLayoutError(), isNull);
      expect(find.text('Trains'), findsOneWidget);
      expect(find.text('2 passes'), findsOneWidget);
      expect(find.text('MAS'), findsNothing);
      expect(find.text('SBC'), findsNothing);
    });

    testWidgets('handles a single-item folder', (WidgetTester t) async {
      await pumpTile(
        t,
        folder(<WalletPassItem>[MoviePassItem(movie(id: 'a', title: 'Solo'))]),
      );

      expect(takeLayoutError(), isNull);
      expect(find.text('1 pass'), findsOneWidget);
      expect(find.bySemanticsLabel('Movies, 1 pass'), findsOneWidget);
    });

    testWidgets('lays out in dark mode', (WidgetTester t) async {
      await pumpTile(
        t,
        folder(<WalletPassItem>[
          TrainPassItem(train(id: 'a')),
          MoviePassItem(movie(id: 'b', title: 'Mixed')),
        ]),
        brightness: Brightness.dark,
      );

      expect(takeLayoutError(), isNull);
      expect(find.text('Trains'), findsOneWidget);
      expect(find.text('2 passes'), findsOneWidget);
    });

    testWidgets('keeps the label block compact at large text scale', (
      WidgetTester t,
    ) async {
      await pumpTile(
        t,
        folder(<WalletPassItem>[
          MoviePassItem(movie(id: 'a', title: 'Scaled')),
          MoviePassItem(movie(id: 'b', title: 'Up')),
        ]),
        textScale: 2.0,
      );

      expect(takeLayoutError(), isNull);
      expect(find.text('Movies'), findsOneWidget);
      expect(find.text('Last added 10 Feb 2025'), findsNothing);
    });

    test('paper thickness tracks how full the folder is', () {
      // Bands, not a per-pass count: the stack has to stay legible at 167dp.
      expect(HistoryFolderTile.sheetsFor(1), 1);
      expect(HistoryFolderTile.sheetsFor(2), 2);
      expect(HistoryFolderTile.sheetsFor(4), 2);
      expect(HistoryFolderTile.sheetsFor(5), 3);
      expect(HistoryFolderTile.sheetsFor(200), 3);
      // buildHistoryFolders never emits an empty folder, but a zero must not
      // paint a folder with no paper in it at all.
      expect(HistoryFolderTile.sheetsFor(0), 1);
    });
  });

  group('HistoryPassCard', () {
    testWidgets('shows title and normalised date, nothing else', (
      WidgetTester t,
    ) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: HistoryPassCard(
                item: MoviePassItem(movie(id: 'a', title: 'Dune: Part Two')),
              ),
            ),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 300));

      expect(takeLayoutError(), isNull);
      expect(find.text('Dune: Part Two'), findsOneWidget);
      // "Mon, 10 Feb 2025" is normalised; the year lives in the month header.
      expect(find.text('10 Feb'), findsOneWidget);
      expect(find.text('Test Cinema'), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    testWidgets('falls back to the raw date when unparseable', (
      WidgetTester t,
    ) async {
      final MoviePass pass = MoviePass(
        id: 'x',
        brand: MoviePassBrand.universal,
        movieTitle: 'Mystery',
        movieSubtitle: 'Drama',
        cinemaName: 'Test Cinema',
        cinemaAddress: 'Somewhere',
        screen: 'Screen 1',
        showDate: 'sometime soon',
        showTime: '7:00 PM',
        format: '2D',
        language: 'English',
        seats: const <MovieSeat>[MovieSeat(row: 'A', number: '1')],
        bookingId: 'BK',
        orderId: 'OR',
        status: TicketStatus.expired,
      );

      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: HistoryPassCard(item: MoviePassItem(pass)),
            ),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 300));

      expect(find.text('sometime soon'), findsOneWidget);
    });
  });
}

/// Surfaces layout overflow and painter assertions, which otherwise only print
/// to the console and would let a broken tile pass silently.
Object? takeLayoutError() => TestWidgetsFlutterBinding.instance.takeException();
