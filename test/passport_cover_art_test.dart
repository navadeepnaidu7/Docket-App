import 'package:docket/features/passport/presentation/widgets/passport_cover_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders both passport cover variants', (WidgetTester tester) async {
    // flutter_svg loads and parses off the test's fake-async zone, so the
    // artwork only appears if the load is allowed to run for real.
    await tester.runAsync(() async {
      await PassportCoverArt.warmUp();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFFF5F0E8),
          body: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const <Widget>[
                PassportCoverArt(
                  variant: PassportCoverVariant.regular,
                  height: 120,
                ),
                SizedBox(width: 32),
                PassportCoverArt(
                  variant: PassportCoverVariant.ePassport,
                  height: 120,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PassportCoverArt), findsNWidgets(2));
    await expectLater(
      find.byType(Row),
      matchesGoldenFile('goldens/passport_covers.png'),
    );
  });
}
