import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:docket/core/theme/app_theme.dart';
import 'package:docket/core/wallet/wallet_card_metrics.dart';
import 'package:docket/features/dashboard/presentation/wallet_passport_card.dart';
import 'package:docket/features/ids/domain/id_document.dart';
import 'package:docket/features/ids/presentation/cards/id_card_registry.dart';
import 'package:docket/features/ids/presentation/wallet_id_card.dart';
import 'package:docket/features/passport/domain/passport_profile.dart';
import 'package:docket/features/tickets/data/mock_pass_fixtures.dart';
import 'package:docket/features/tickets/presentation/wallet_movie_card.dart';
import 'package:docket/features/tickets/presentation/wallet_ticket_card.dart';

/// Screen sizes we support. The app is portrait-locked, but the short-viewport
/// cases stay covered: Android multi-window and split screen still hand a
/// portrait-locked activity a wide, short box.
const Map<String, Size> _devices = <String, Size>{
  'iPhone SE': Size(320, 568),
  'Pixel 5': Size(393, 851),
  'iPhone 15 Pro Max': Size(430, 932),
  'iPad mini': Size(744, 1133),
  'iPad Pro': Size(1024, 1366),
  'Pixel 5 landscape': Size(851, 393),
  'iPad Pro landscape': Size(1366, 1024),
};

/// Including the accessibility range, which previously blew the cards apart.
const List<double> _textScales = <double>[1.0, 1.3, 2.0];

/// Horizontal padding the wallet tabs apply around a card.
const double _hPad = 48;

IdDocument _doc(IdDocumentType type) => IdDocument(
      id: 'test',
      type: type,
      holderName: 'Ramachandra Venkataraman',
      documentNumber:
          type == IdDocumentType.pan ? 'ABCDE1234F' : '123412341234',
      dateOfBirth: '1992-08-15',
      gender: 'MALE',
    );

PassportProfile _passport() => PassportProfile(
      id: 'test',
      name: 'Ramachandra Venkataraman',
      passportNumber: 'Z1234567',
      nationality: 'INDIAN',
      dateOfBirth: '1992-08-15',
      expiryDate: '2030-01-01',
      imagePath: '',
      mrzRaw: '',
      placeOfBirth: 'HYDERABAD',
      issueDate: '2020-01-01',
      issuingAuthority: 'HYDERABAD',
      gender: 'MALE',
    );

/// Renders [child] in a viewport of [size] at [scale] and returns any
/// overflow errors Flutter raised during layout.
Future<List<String>> _renderAndCollect(
  WidgetTester tester,
  Widget child,
  Size size,
  double scale,
) async {
  final List<String> errors = <String>[];
  final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    errors.add(details.exceptionAsString());
  };

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      // The real theme: font metrics change layout, so a default ThemeData
      // here would measure a card the app never renders.
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _hPad / 2),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  FlutterError.onError = previous;
  return errors.where((String e) => e.contains('overflow')).toList();
}

void main() {
  group('ID card faces never overflow their design canvas', () {
    for (final IdDocumentType type in <IdDocumentType>[
      IdDocumentType.pan,
      IdDocumentType.aadhaar,
    ]) {
      for (final MapEntry<String, Size> device in _devices.entries) {
        for (final double scale in _textScales) {
          testWidgets('${type.name} on ${device.key} @${scale}x',
              (WidgetTester tester) async {
            final double boxW = device.value.width - _hPad;
            final Widget card = SizedBox(
              width: boxW,
              height: boxW / WalletCardMetrics.idAspect,
              child: IdCardRegistry.buildFront(_doc(type)),
            );

            final List<String> overflows = await _renderAndCollect(
              tester,
              card,
              device.value,
              scale,
            );
            expect(overflows, isEmpty,
                reason: 'overflowed: ${overflows.join(" | ")}');
          });
        }
      }
    }
  });

  group('Wallet card shells fit the viewport', () {
    for (final MapEntry<String, Size> device in _devices.entries) {
      testWidgets('WalletIdCard fits ${device.key}',
          (WidgetTester tester) async {
        final List<String> overflows = await _renderAndCollect(
          tester,
          WalletIdCard(document: _doc(IdDocumentType.aadhaar)),
          device.value,
          1.0,
        );
        expect(overflows, isEmpty);

        final Size card = tester.getSize(find.byType(WalletIdCard));
        expect(card.width, lessThanOrEqualTo(device.value.width),
            reason: 'card wider than the screen');
        expect(card.height, lessThanOrEqualTo(device.value.height),
            reason: 'card taller than the screen');
        expect(card.width, lessThanOrEqualTo(WalletCardMetrics.maxCardWidth));
      });

      testWidgets('WalletPassportCard fits ${device.key}',
          (WidgetTester tester) async {
        final List<String> overflows = await _renderAndCollect(
          tester,
          WalletPassportCard(profile: _passport()),
          device.value,
          1.0,
        );
        expect(overflows, isEmpty);

        final Size card = tester.getSize(find.byType(WalletPassportCard));
        expect(card.height, lessThanOrEqualTo(device.value.height),
            reason: 'passport card taller than the screen');
      });
    }
  });

  group('Ticket cards fit the viewport', () {
    for (final MapEntry<String, Size> device in _devices.entries) {
      for (final double scale in _textScales) {
        testWidgets('train on ${device.key} @${scale}x',
            (WidgetTester tester) async {
          final List<String> overflows = await _renderAndCollect(
            tester,
            WalletTicketCard(ticket: mockTrainPasses.first),
            device.value,
            scale,
          );
          expect(overflows, isEmpty,
              reason: 'overflowed: ${overflows.join(" | ")}');

          final Size card = tester.getSize(find.byType(WalletTicketCard));
          expect(card.height, lessThanOrEqualTo(device.value.height));
        });

        testWidgets('movie on ${device.key} @${scale}x',
            (WidgetTester tester) async {
          final List<String> overflows = await _renderAndCollect(
            tester,
            WalletMovieCard(pass: mockMoviePasses.first),
            device.value,
            scale,
          );
          expect(overflows, isEmpty,
              reason: 'overflowed: ${overflows.join(" | ")}');

          final Size card = tester.getSize(find.byType(WalletMovieCard));
          expect(card.height, lessThanOrEqualTo(device.value.height));
        });
      }
    }
  });

  group('WalletCardMetrics.resolve', () {
    test('honours the height axis when width would overflow it', () {
      // Landscape-ish: lots of width, very little height.
      final Size size = WalletCardMetrics.resolve(
        const BoxConstraints(maxWidth: 800, maxHeight: 200),
        WalletCardMetrics.idAspect,
      );
      expect(size.height, lessThanOrEqualTo(200));
    });

    test('caps card width on large screens', () {
      final Size size = WalletCardMetrics.resolve(
        const BoxConstraints(maxWidth: 1200, maxHeight: 2000),
        WalletCardMetrics.idAspect,
      );
      expect(size.width, WalletCardMetrics.maxCardWidth);
    });

    test('fills the width on a normal phone', () {
      final Size size = WalletCardMetrics.resolve(
        const BoxConstraints(maxWidth: 345, maxHeight: 800),
        WalletCardMetrics.idAspect,
      );
      expect(size.width, 345);
      expect(size.height, closeTo(345 / WalletCardMetrics.idAspect, 0.01));
    });

    test('handles unbounded height', () {
      final Size size = WalletCardMetrics.resolve(
        const BoxConstraints(maxWidth: 345),
        WalletCardMetrics.idAspect,
      );
      expect(size.width, 345);
    });
  });
}
