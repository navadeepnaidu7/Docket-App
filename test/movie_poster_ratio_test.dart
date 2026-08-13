import 'package:docket/features/tickets/data/mock_pass_fixtures.dart';
import 'package:docket/features/tickets/domain/movie_pass_models.dart';
import 'package:docket/features/tickets/presentation/movie/movie_ticket_chrome.dart';
import 'package:docket/features/tickets/presentation/movie/movie_ticket_face.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two densities size the poster differently on purpose:
///
/// - **detail** shows the whole one-sheet at TMDB's 2:3, so the art is not cropped
/// - **glance** keeps a fixed-height crop, because a full-height poster on the
///   wallet card would push the ticket's actual information off the card
///
/// Without this test the difference reads like an inconsistency and someone
/// "fixes" it by making both the same.

Future<Rect> _heroRect(
  WidgetTester tester, {
  required MovieTicketDensity density,
  required double width,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: SingleChildScrollView(
              child: MovieTicketFace(
                pass: mockMoviePasses.first,
                density: density,
                useBrandColors: true,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return tester.getRect(find.byKey(MovieTicketFace.heroKey));
}

void main() {
  testWidgets('the detail poster is a full 2:3 one-sheet',
      (WidgetTester tester) async {
    final Rect hero = await _heroRect(
      tester,
      density: MovieTicketDensity.detail,
      width: 382,
    );

    expect(
      hero.width / hero.height,
      moreOrLessEquals(MovieTicketMetrics.posterAspect, epsilon: 0.01),
    );
  });

  testWidgets('the detail poster tracks the width it is given',
      (WidgetTester tester) async {
    // Derived from width rather than pinned, so it stays a one-sheet on any
    // screen instead of only on the one it was measured against.
    final Rect narrow = await _heroRect(
      tester,
      density: MovieTicketDensity.detail,
      width: 320,
    );
    final Rect wide = await _heroRect(
      tester,
      density: MovieTicketDensity.detail,
      width: 420,
    );

    expect(wide.height, greaterThan(narrow.height));
    for (final Rect hero in <Rect>[narrow, wide]) {
      expect(
        hero.width / hero.height,
        moreOrLessEquals(MovieTicketMetrics.posterAspect, epsilon: 0.01),
      );
    }
  });

  testWidgets('the glance poster keeps its fixed-height crop',
      (WidgetTester tester) async {
    final Rect hero = await _heroRect(
      tester,
      density: MovieTicketDensity.glance,
      width: 382,
    );

    // 190 * glanceTallScale, unchanged by this work.
    expect(
      hero.height,
      moreOrLessEquals(190.0 * MovieTicketMetrics.glanceTallScale, epsilon: 0.5),
    );
    // ...and is emphatically not a one-sheet.
    expect(
      hero.width / hero.height,
      greaterThan(MovieTicketMetrics.posterAspect + 0.3),
    );
  });

  testWidgets('a pass with no poster still gets the one-sheet frame',
      (WidgetTester tester) async {
    // "No poster" is a normal state — the gradient hint is the art, and it has
    // to occupy the same frame or the layout jumps when a poster arrives.
    final MoviePass bare = MoviePass.fromJson(<String, dynamic>{
      'id': 'x',
      'movieTitle': 'Untitled',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 382,
              child: SingleChildScrollView(
                child: MovieTicketFace(
                  pass: bare,
                  density: MovieTicketDensity.detail,
                  useBrandColors: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final Rect hero = tester.getRect(find.byKey(MovieTicketFace.heroKey));
    expect(bare.resolvedPosterUrl, isNull);
    expect(
      hero.width / hero.height,
      moreOrLessEquals(MovieTicketMetrics.posterAspect, epsilon: 0.01),
    );
  });
}
