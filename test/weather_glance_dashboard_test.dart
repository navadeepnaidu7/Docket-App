import 'package:docket/app.dart';
import 'package:docket/core/dev/sky_preview.dart';
import 'package:docket/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:docket/features/dashboard/presentation/widgets/easter_egg_drawer.dart';
import 'package:docket/features/dashboard/presentation/widgets/pill_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, null);
  });

  Future<void> open(
    WidgetTester tester, {
    WeatherGlancePreview preview = WeatherGlancePreview.movie,
  }) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          weatherGlancePreviewProvider.overrideWith((ref) => preview),
        ],
        child: const DocketApp(hasSeenOnboarding: true),
      ),
    );
  }

  double offset(WidgetTester tester) => tester
      .widget<Transform>(
        find.byKey(
          const ValueKey('weather_wallet_translation'),
          skipOffstage: false,
        ),
      )
      .transform
      .storage[13];

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  }

  for (final preview in [
    WeatherGlancePreview.movie,
    WeatherGlancePreview.train,
  ]) {
    testWidgets('automatic ${preview.name} glance reveals, cycles and closes', (
      tester,
    ) async {
      await open(tester, preview: preview);
      await tester.pump(const Duration(milliseconds: 999));
      expect(offset(tester), 0);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(offset(tester), greaterThan(0));
      expect(find.byType(EasterEggDrawer), findsOneWidget);
      expect(
        tester
            .widget<ImageFiltered>(
              find.byKey(const ValueKey('weather_refresh_blur')),
            )
            .enabled,
        isTrue,
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.textContaining('24°C'), findsOneWidget);
      expect(
        tester
            .widget<ImageFiltered>(
              find.byKey(const ValueKey('weather_refresh_blur')),
            )
            .enabled,
        isFalse,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text(preview.label), findsOneWidget);
      expect(find.textContaining('24°C'), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 1));
      expect(offset(tester), lessThan(0.5));
      expect(find.byType(EasterEggDrawer), findsNothing);
      await close(tester);
    });
  }

  testWidgets('manual pull and upward dismissal remain available', (
    tester,
  ) async {
    await open(tester);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.drag(find.byType(DashboardHeader), const Offset(0, 160));
    await tester.pump(const Duration(milliseconds: 700));
    expect(offset(tester), greaterThan(100));
    final gesture = await tester.startGesture(const Offset(180, 80));
    await gesture.moveBy(const Offset(0, -170));
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    expect(offset(tester), lessThan(0.5));
    await tester.pump(const Duration(seconds: 2));
    expect(offset(tester), lessThan(0.5));
    await close(tester);
  });

  testWidgets(
    'resuming mid-refresh keeps the veil until the latest refresh ends',
    (tester) async {
      await open(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 200));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      expect(
        tester
            .widget<ImageFiltered>(
              find.byKey(const ValueKey('weather_refresh_blur')),
            )
            .enabled,
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(
        tester
            .widget<ImageFiltered>(
              find.byKey(const ValueKey('weather_refresh_blur')),
            )
            .enabled,
        isFalse,
      );
      await close(tester);
    },
  );

  testWidgets('early navigation cancels automatic movement', (tester) async {
    await open(tester);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is TabLabel && widget.label == 'Passes',
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(offset(tester), 0);
    expect(find.byType(EasterEggDrawer), findsNothing);
    await close(tester);
  });

  testWidgets('backgrounding cancels movement without replaying on resume', (
    tester,
  ) async {
    await open(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 2));
    expect(offset(tester), 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 999));
    expect(offset(tester), 0);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(offset(tester), 0);
    await close(tester);
  });

  testWidgets('closing a dialog does not replay the automatic reveal', (
    tester,
  ) async {
    await open(tester);
    final context = tester.element(find.byType(DashboardHeader));
    showDialog<void>(
      context: context,
      builder: (_) => const AlertDialog(content: Text('Another task')),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(offset(tester), 0);
    Navigator.of(context).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(offset(tester), 0);
    await close(tester);
  });

  testWidgets('returning to the dashboard does not replay the glance', (
    tester,
  ) async {
    await open(tester);
    final navigator = Navigator.of(
      tester.element(find.byType(DashboardHeader)),
    );
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Another screen')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 2));
    expect(offset(tester), 0);
    navigator.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    await tester.pump();
    expect(find.text('Another screen'), findsNothing);
    await tester.pump(const Duration(milliseconds: 999));
    expect(offset(tester), 0);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(offset(tester), 0);
    await close(tester);
  });
}
