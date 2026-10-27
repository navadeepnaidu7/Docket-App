import 'package:docket/features/dashboard/presentation/widgets/account_summary.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('hides when no pass has a future scheduled time', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: UpNextSummary(passes: [])),
      ),
    );
    expect(find.byType(RichText), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('shows the nearest pass and wraps at large text sizes', (
    tester,
  ) async {
    final start = DateTime.now().add(const Duration(hours: 3));
    final soon = MoviePassItem.fromJson({
      'id': 'soon',
      'status': 'active',
      'movieTitle': 'A very long movie title that should wrap across lines',
      'showAt': start.toIso8601String(),
    });
    final later = MoviePassItem.fromJson({
      'id': 'later',
      'status': 'active',
      'movieTitle': 'Later movie',
      'showAt': start.add(const Duration(days: 1)).toIso8601String(),
    });
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: Scaffold(
            body: SizedBox(
              width: 290,
              child: SingleChildScrollView(
                child: UpNextSummary(passes: [later, soon]),
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      find.textContaining('A very long movie', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Later movie', findRichText: true),
      findsNothing,
    );
    expect(find.textContaining('Tap to open'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
