import 'package:cached_network_image/cached_network_image.dart';
import 'package:docket/features/tickets/domain/movie_pass_models.dart';
import 'package:docket/features/tickets/presentation/movie/movie_brand_style.dart';
import 'package:docket/features/tickets/presentation/movie/movie_ticket_face.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// NOTE: never use pumpAndSettle here. The poster placeholder runs a repeating shimmer, so
/// settling never completes — the same trap that makes bare `flutter test` hang on
/// widget_test.dart. Pump fixed durations instead.
void main() {
  MoviePass buildPass({
    required MoviePassBrand brand,
    String? posterUrl,
    String? posterAsset,
    TicketStatus status = TicketStatus.active,
  }) {
    return MoviePass(
      id: 'test_${brand.name}',
      brand: brand,
      movieTitle: 'Test Film',
      movieSubtitle: 'Drama',
      cinemaName: 'Test Cinema',
      cinemaAddress: 'Somewhere',
      screen: 'Screen 1',
      showDate: 'Sat, 12 Apr 2025',
      showTime: '7:15 PM',
      format: '2D',
      language: 'English',
      seats: const <MovieSeat>[MovieSeat(row: 'A', number: '1')],
      bookingId: 'BK-1',
      orderId: 'OR-1',
      status: status,
      posterHint: MoviePosterHint.action,
      posterUrl: posterUrl,
      posterAsset: posterAsset,
    );
  }

  Future<void> pumpFace(WidgetTester tester, MoviePass pass) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 382,
            height: 620,
            child: SingleChildScrollView(
              child: MovieTicketFace(
                pass: pass,
                density: MovieTicketDensity.glance,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('movie hero band', () {
    // The brand chip and status pill previously sat in an unreachable else-branch: the guard
    // tested all three MoviePassBrand values, so no movie pass ever showed them. These are
    // the regression tests for that.
    for (final MoviePassBrand brand in MoviePassBrand.values) {
      testWidgets('renders the brand chip and status pill for ${brand.name}',
          (WidgetTester tester) async {
        final MoviePass pass = buildPass(brand: brand);
        await pumpFace(tester, pass);

        expect(find.text('Active'), findsOneWidget,
            reason: 'status pill missing for ${brand.name}');
        expect(find.text(MovieBrandStyle.forPass(pass).chipLabel), findsWidgets,
            reason: 'brand chip missing for ${brand.name}');
      });
    }

    testWidgets('shows the expired pill for an expired pass', (WidgetTester tester) async {
      await pumpFace(
        tester,
        buildPass(brand: MoviePassBrand.bookMyShow, status: TicketStatus.expired),
      );
      expect(find.text('Expired'), findsOneWidget);
    });

    // No poster must mean the gradient fallback, with no network request attempted.
    testWidgets('requests no image when there is no poster URL', (WidgetTester tester) async {
      await pumpFace(tester, buildPass(brand: MoviePassBrand.bookMyShow));

      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('uses a cached network image when a poster URL is present',
        (WidgetTester tester) async {
      await pumpFace(
        tester,
        buildPass(
          brand: MoviePassBrand.district,
          posterUrl: 'https://api.docket.app/img/poster/w500/abc123abc123abc123abc12.jpg',
        ),
      );

      expect(find.byType(CachedNetworkImage), findsOneWidget);
    });

    // A fixture-pinned local asset still wins, so the offline demo path keeps working.
    testWidgets('prefers a bundled asset over the network URL', (WidgetTester tester) async {
      await pumpFace(
        tester,
        buildPass(
          brand: MoviePassBrand.universal,
          posterAsset: 'assets/passes/history_clock.svg',
          posterUrl: 'https://api.docket.app/img/poster/w500/abc123abc123abc123abc12.jpg',
        ),
      );

      expect(find.byType(CachedNetworkImage), findsNothing);
    });
  });
}
