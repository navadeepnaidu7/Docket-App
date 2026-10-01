// flutter test --no-pub tool/bus_card_preview_test.dart --update-goldens
// Review images live in build/bus-preview rather than committed goldens.
import 'dart:io';

import 'package:docket/core/assets/app_assets.dart';
import 'package:docket/core/wallet/wallet_card_metrics.dart';
import 'package:docket/features/tickets/domain/bus_pass_models.dart';
import 'package:docket/features/tickets/domain/pass_status.dart';
import 'package:docket/features/tickets/presentation/bus/bus_pass_theme.dart';
import 'package:docket/features/tickets/presentation/bus/bus_ticket_face.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  testWidgets('bus cards with artwork at wallet sizes', (tester) async {
    final fontCache = Directory('build/bus-preview/fonts')
      ..createSync(recursive: true);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => fontCache.absolute.path,
    );
    await tester.runAsync(() async {
      HttpOverrides.global = null;
      BusPassType.warmUp();
      BusPassType.wordmarkLead(Colors.white);
      BusPassType.operatorName(Colors.white);
      await GoogleFonts.pendingFonts();
    });
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final entry in <(String, String, TicketStatus)>[
      ('redbus', 'redBus', TicketStatus.active),
      ('universal', 'KSRTC Airavat', TicketStatus.active),
      (
        'long_provider',
        'Thiruvananthapuram Interstate Coach Services Limited',
        TicketStatus.active,
      ),
      ('expired', 'KSRTC Airavat', TicketStatus.expired),
    ]) {
      final (name, operator, status) = entry;
      final pass = BusPass(
        id: name,
        operator: operator,
        fromCity: 'Bengaluru',
        toCity: 'Mysuru',
        boardingLocation: 'Bengaluru, Kempegowda Bus Station',
        dropLocation: 'Mysuru, Mysuru City Bus Stand',
        boardingPoint: 'Kempegowda Bus Station',
        platform: 'Platform 15',
        date: '20 Aug 2026',
        arrivalDate: '20 Aug 2026',
        departTime: '08:30 AM',
        arriveTime: '11:45 AM',
        seatDetails: '12A',
        fare: '₹650',
        passengers: const <BusPassenger>[],
        bookingId: 'BUS8842119',
        status: status,
      );
      for (final width in <double>[382, 288]) {
        tester.view.physicalSize = Size(width + 48, 720);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: const Color(0xFF121718),
              body: Center(
                child: SizedBox(
                  width: width,
                  height: width / WalletCardMetrics.ticketAspect,
                  child: WalletCardCanvas(
                    designSize: BusPassMetrics.canvas,
                    child: BusTicketFace(pass: pass),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          final context = tester.element(find.byType(BusTicketFace));
          await precacheImage(const AssetImage(AppAssets.redBusCoach), context);
          await precacheImage(const AssetImage(AppAssets.busCoach), context);
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final image = tester.getRect(find.byType(Image));
        final provider = tester.getRect(find.text(operator));
        final route = tester.getRect(find.textContaining('→'));
        expect(image.top, greaterThan(provider.bottom));
        expect(image.bottom, lessThan(route.top));
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../build/bus-preview/${name}_${width.toInt()}.png',
          ),
        );
      }
    }
  });
}
