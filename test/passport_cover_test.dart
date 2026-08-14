import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:docket/core/theme/app_theme.dart';
import 'package:docket/features/dashboard/presentation/wallet_passport_card.dart';
import 'package:docket/features/passport/domain/passport_profile.dart';

PassportProfile _profile({bool ePassport = false}) => PassportProfile(
      id: 'test',
      name: 'Ramachandra Venkataraman',
      passportNumber: 'Z1234567',
      nationality: 'INDIAN',
      dateOfBirth: '1992-08-15',
      expiryDate: '2030-01-01',
      imagePath: '',
      mrzRaw: '',
      isEPassport: ePassport,
    );

Future<void> _pumpCard(WidgetTester tester, PassportProfile profile) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            height: 480,
            child: WalletPassportCard(profile: profile),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _flipToBack(WidgetTester tester) async {
  await tester.tap(find.byType(WalletPassportCard));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ordinary cover is the official lockup, not a wallet header',
      (WidgetTester tester) async {
    await _pumpCard(tester, _profile());

    expect(find.text('भारत गणराज्य'), findsWidgets);
    expect(find.text('REPUBLIC OF INDIA'), findsWidgets);
    expect(find.text('सत्यमेव जयते'), findsOneWidget);
    expect(find.text('पासपोर्ट'), findsOneWidget);
    expect(find.text('PASSPORT'), findsOneWidget);

    // Old front chrome. The back still holds the name / number, and both
    // faces stay in the flip stack, so those strings are not asserted here.
    expect(find.text('Tap to view details'), findsNothing);
    expect(find.text('HOLDER NAME'), findsNothing);
    expect(find.byKey(const Key('e-passport-chip')), findsNothing);
  });

  testWidgets('e-passport cover adds the chip without dropping the lockup',
      (WidgetTester tester) async {
    await _pumpCard(tester, _profile(ePassport: true));

    expect(find.text('REPUBLIC OF INDIA'), findsWidgets);
    expect(find.text('PASSPORT'), findsWidgets);
    expect(find.byKey(const Key('e-passport-chip')), findsOneWidget);
  });

  testWidgets('data page is an English biodata layout, not wallet chrome',
      (WidgetTester tester) async {
    await _pumpCard(
      tester,
      _profile().copyWith(
        placeOfBirth: 'HYDERABAD',
        issueDate: '2020-01-01',
        issuingAuthority: 'HYDERABAD',
        gender: 'MALE',
      ),
    );
    await _flipToBack(tester);

    expect(find.text('SURNAME'), findsOneWidget);
    expect(find.text('GIVEN NAMES'), findsOneWidget);
    expect(find.text('VENKATARAMAN'), findsOneWidget);
    expect(find.text('RAMACHANDRA'), findsOneWidget);
    expect(find.text('15/08/1992'), findsOneWidget);
    expect(find.text('01/01/2030'), findsOneWidget);
    expect(find.text('01/01/2020'), findsOneWidget);
    expect(find.text('P'), findsOneWidget);
    expect(find.text('IND'), findsOneWidget);
    expect(find.text('INDIAN'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('HYDERABAD'), findsNWidgets(2));

    expect(find.text('MACHINE READABLE ZONE'), findsNothing);
    expect(find.text('Tap to view details'), findsNothing);
    expect(find.text('1992 August 15'), findsNothing);
  });

  testWidgets('data page keeps missing fields blank and hides a fake MRZ',
      (WidgetTester tester) async {
    await _pumpCard(
      tester,
      PassportProfile(
        id: 'empty',
        name: '',
        passportNumber: '',
        nationality: '',
        dateOfBirth: '',
        expiryDate: '',
        imagePath: '',
        mrzRaw: '',
      ),
    );
    await _flipToBack(tester);

    expect(find.text('—'), findsWidgets);
    expect(find.textContaining('P<'), findsNothing);
  });

  testWidgets('data page shows an MRZ when name and number are present',
      (WidgetTester tester) async {
    await _pumpCard(tester, _profile());
    await _flipToBack(tester);

    expect(find.textContaining('P<IND'), findsOneWidget);
  });
}
