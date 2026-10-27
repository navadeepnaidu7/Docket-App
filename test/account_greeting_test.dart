import 'package:docket/features/dashboard/presentation/widgets/account_greeting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  Widget scene(String name, {bool reducedMotion = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(
        body: SizedBox(width: 290, child: AccountGreeting(displayName: name)),
      ),
    ),
  );

  Future<void> loadWave(WidgetTester tester) async {
    await tester.runAsync(() async {
      await AssetLottie('assets/emoji/waving_hand.json').load();
    });
    await tester.pump();
    await tester.pump();
  }

  testWidgets('uses first name and plays the authored wave once, then rests', (
    tester,
  ) async {
    await tester.pumpWidget(scene('  Navadeep   Reddy '));
    await loadWave(tester);
    expect(find.text('Hey Navadeep'), findsOneWidget);
    final wave = tester.widget<Lottie>(find.byType(Lottie)).controller!;
    expect(wave.isAnimating, isTrue);
    await tester.pump(const Duration(milliseconds: 700));
    expect(wave.value, greaterThan(0));
    await tester.pump(const Duration(seconds: 2));
    expect(wave.isAnimating, isFalse);
    expect(wave.value, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'unknown name has a natural fallback and reduced motion stays still',
    (tester) async {
      await tester.pumpWidget(scene('  ', reducedMotion: true));
      await loadWave(tester);
      expect(find.text('Hey there'), findsOneWidget);
      final wave = tester.widget<Lottie>(find.byType(Lottie)).controller!;
      expect(wave.isAnimating, isFalse);
      await tester.pump(const Duration(seconds: 2));
      expect(wave.value, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
