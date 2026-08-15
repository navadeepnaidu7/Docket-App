import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:docket/features/tickets/domain/movie_pass_models.dart';
import 'package:docket/features/tickets/presentation/history/history_poster_grid.dart';
import 'package:docket/features/tickets/presentation/history/movie_poster_art.dart';

/// Fixtures deliberately carry no posterUrl/posterAsset, so tiles take the
/// gradient path and nothing here touches the network.
MoviePass _movie({
  required String id,
  required String title,
  MoviePassBrand brand = MoviePassBrand.bookMyShow,
}) {
  return MoviePass(
    id: id,
    brand: brand,
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
    // Everything in the archive is expired — that is the whole point of it.
    status: TicketStatus.expired,
  );
}

/// One grid cell at the real geometry: three columns inside 20dp gutters with
/// 14dp between them.
double _cellWidth(double screen) => (screen - 40 - 28) / 3;

Future<void> _pumpGrid(
  WidgetTester tester,
  List<MoviePass> passes, {
  double screenWidth = 393,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = Size(screenWidth, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: GridView.count(
          crossAxisCount: 3,
          childAspectRatio: kPosterAspect,
          mainAxisSpacing: 16,
          crossAxisSpacing: 14,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: <Widget>[
            for (final MoviePass p in passes) HistoryPosterTile(pass: p),
          ],
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

Object? _layoutError() => TestWidgetsFlutterBinding.instance.takeException();

void main() {
  group('HistoryPosterTile', () {
    testWidgets('lays out a full row of posters without overflow', (
      WidgetTester tester,
    ) async {
      await _pumpGrid(tester, <MoviePass>[
        _movie(id: 'a', title: 'Dune: Part Three'),
        _movie(id: 'b', title: 'The Odyssey', brand: MoviePassBrand.district),
        _movie(id: 'c', title: 'Spider-Man', brand: MoviePassBrand.universal),
      ]);

      expect(_layoutError(), isNull);
      expect(find.byType(HistoryPosterTile), findsNWidgets(3));
      expect(find.byType(MoviePosterArt), findsNWidgets(3));
    });

    testWidgets('keeps poster proportions', (WidgetTester tester) async {
      await _pumpGrid(tester, <MoviePass>[_movie(id: 'a', title: 'Solo')]);

      final Size size = tester.getSize(find.byType(HistoryPosterTile).first);
      expect(size.width, closeTo(_cellWidth(393), 1.0));
      // 2:3 one-sheet, which is what makes the grid read as a shelf of posters.
      expect(size.height / size.width, closeTo(1 / kPosterAspect, 0.02));
    });

    // A film with no artwork is a normal state, not an error — the tile must
    // still say which film it is rather than being an anonymous rectangle.
    testWidgets('names the film when there is no poster', (
      WidgetTester tester,
    ) async {
      await _pumpGrid(tester, <MoviePass>[
        _movie(id: 'a', title: 'Kalki 2898 AD'),
      ]);

      expect(_layoutError(), isNull);
      expect(find.text('Kalki 2898 AD'), findsOneWidget);
    });

    testWidgets('survives a long title and dark mode', (
      WidgetTester tester,
    ) async {
      await _pumpGrid(
        tester,
        <MoviePass>[
          _movie(
            id: 'a',
            title: 'A Very Long Film Title That Should Not Overflow The Tile',
          ),
        ],
        brightness: Brightness.dark,
      );

      expect(_layoutError(), isNull);
    });

    testWidgets('lays out on a narrow phone', (WidgetTester tester) async {
      await _pumpGrid(tester, <MoviePass>[
        _movie(id: 'a', title: 'Dune'),
        _movie(id: 'b', title: 'The Odyssey', brand: MoviePassBrand.district),
        _movie(id: 'c', title: 'Spider-Man'),
      ], screenWidth: 320);

      expect(_layoutError(), isNull);
    });

    testWidgets('opens the pass on tap', (WidgetTester tester) async {
      await _pumpGrid(tester, <MoviePass>[_movie(id: 'a', title: 'Dune')]);

      await tester.tap(find.byType(HistoryPosterTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // The scale route is a real push, so the archive grid is left behind.
      expect(find.byType(HistoryPosterTile), findsNothing);
      expect(_layoutError(), isNull);
    });
  });

  group('posterScaleRoute', () {
    testWidgets('scales and fades its page in', (WidgetTester tester) async {
      final PageRoute<void> route = posterScaleRoute<void>(
        builder: (_) => const Scaffold(body: Text('destination')),
      );

      expect(route.transitionDuration.inMilliseconds, greaterThan(0));

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(route),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      // Mid-flight the page is present but not yet at full size.
      await tester.pump(const Duration(milliseconds: 120));

      final ScaleTransition scale = tester.widget<ScaleTransition>(
        find.ancestor(
          of: find.text('destination'),
          matching: find.byType(ScaleTransition),
        ),
      );
      expect(scale.scale.value, lessThan(1.0));
      expect(scale.scale.value, greaterThan(0.5));

      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('destination'), findsOneWidget);
    });
  });
}
