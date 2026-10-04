import 'dart:async';
import 'dart:convert';

import 'package:docket/app.dart';
import 'package:docket/features/dashboard/application/wallet_order_provider.dart';
import 'package:docket/features/dashboard/presentation/dashboard_screen.dart';
import 'package:docket/features/dashboard/presentation/widgets/pill_tab_bar.dart';
import 'package:docket/features/passport/domain/passport_profile.dart';
import 'package:docket/features/tickets/presentation/tickets_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_storage, (call) async => null);
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_storage, null),
  );

  Future<void> open(WidgetTester tester, {ProviderContainer? container}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      container == null
          ? const ProviderScope(child: DocketApp(hasSeenOnboarding: true))
          : UncontrolledProviderScope(
              container: container,
              child: const DocketApp(hasSeenOnboarding: true),
            ),
    );
  }

  testWidgets('first frame paints without mounting hidden Passes', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byType(TicketsTab), findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(TicketsTab), findsNothing);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.byType(TicketsTab), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('repeated immediate close cancels every startup timer', (
    tester,
  ) async {
    for (var attempt = 0; attempt < 10; attempt++) {
      await open(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('early and rapid tab switches stay interactive', (tester) async {
    await open(tester);
    for (var attempt = 0; attempt < 20; attempt++) {
      final label = attempt.isEven ? 'Passes' : 'IDs';
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is TabLabel && widget.label == label,
        ),
      );
      await tester.pump(const Duration(milliseconds: 45));
      expect(tester.takeException(), isNull);
    }
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(TicketsTab), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('slow documents never overwrite persisted wallet order', (
    tester,
  ) async {
    final passports = Completer<String?>();
    final reads = <String>[];
    final writes = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_storage, (
      call,
    ) async {
      final args = Map<String, dynamic>.from(call.arguments as Map);
      final key = args['key'] as String;
      if (call.method == 'write') {
        writes.add(key);
        return null;
      }
      reads.add(key);
      if (key == 'saved_passports') return passports.future;
      if (key == 'wallet_items_order') return jsonEncode(['p2', 'p1']);
      return null;
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await open(tester, container: container);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(container.read(walletOrderProvider), ['p2', 'p1']);
    expect(writes, isNot(contains('wallet_items_order')));
    passports.complete(
      jsonEncode([
        PassportProfile.empty().copyWith(id: 'p1').toJson(),
        PassportProfile.empty().copyWith(id: 'p2').toJson(),
      ]),
    );
    await tester.pump();
    await tester.pump();
    expect(container.read(walletOrderProvider), ['p2', 'p1']);
    expect(writes, isNot(contains('wallet_items_order')));
    expect(reads.where((key) => key == 'saved_passports'), hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
    'closing with secure reads pending does not touch disposed providers',
    (tester) async {
      final read = Completer<String?>();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _storage,
        (call) async => read.future,
      );
      await open(tester);
      // Also start the cleanup load, then dispose its provider scope.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpWidget(const SizedBox.shrink());
      read.complete(null);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('keystore failure still opens a usable dashboard', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _storage,
      (call) async => throw PlatformException(code: 'locked'),
    );
    await open(tester);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(find.text('Your documents, close at hand'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
