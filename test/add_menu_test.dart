import 'package:docket/features/dashboard/presentation/widgets/add_menu.dart';
import 'package:docket/features/ids/domain/id_document.dart';
import 'package:docket/features/passport/presentation/widgets/passport_cover_art.dart';
import 'package:docket/shared/widgets/morph_sheet.dart';
import 'package:docket/shared/widgets/squircle_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a screen whose only job is to open the Documents menu.
Future<void> _openDocumentsMenu(
  WidgetTester tester, {
  void Function(bool)? onSelectPassportKind,
  void Function(IdDocumentType)? onSelectIdType,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => Center(
            child: ElevatedButton(
              onPressed: () => showAddDocumentsMenu(
                context: context,
                onSelectPassportKind: onSelectPassportKind ?? (_) {},
                onSelectIdType: onSelectIdType ?? (_) {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('root step shows the Documents grid', (WidgetTester tester) async {
    await _openDocumentsMenu(tester);

    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Passport'), findsOneWidget);
    expect(find.text('ID Cards'), findsOneWidget);
    // Passport is illustrated with real cover art, not a glyph.
    expect(find.byType(PassportCoverArt), findsOneWidget);
  });

  testWidgets('choosing Passport morphs to the kind step without a new route', (
    WidgetTester tester,
  ) async {
    await _openDocumentsMenu(tester);

    // Exactly one modal route is on the navigator before and after the morph.
    int modalRoutes() => tester
        .widgetList<MorphSheet>(find.byType(MorphSheet, skipOffstage: false))
        .length;
    expect(modalRoutes(), 1);

    await tester.tap(find.text('Passport'));
    await tester.pumpAndSettle();

    expect(find.text('Which kind are you adding?'), findsOneWidget);
    expect(find.text('E-Passport'), findsOneWidget);
    expect(find.text('Regular Passport'), findsOneWidget);
    // The category grid is gone, not stacked underneath.
    expect(find.text('ID Cards'), findsNothing);
    expect(modalRoutes(), 1);
  });

  testWidgets('back returns to the root step', (WidgetTester tester) async {
    await _openDocumentsMenu(tester);

    await tester.tap(find.text('Passport'));
    await tester.pumpAndSettle();
    expect(find.text('E-Passport'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.text('ID Cards'), findsOneWidget);
    expect(find.text('E-Passport'), findsNothing);
    // Back becomes close again at the root.
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('system back pops one step and leaves the sheet open', (
    WidgetTester tester,
  ) async {
    await _openDocumentsMenu(tester);

    await tester.tap(find.text('Passport'));
    await tester.pumpAndSettle();
    expect(find.text('E-Passport'), findsOneWidget);

    // Android hardware back.
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(
        const MethodCall('popRoute'),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();

    // One step back, sheet still up.
    expect(find.text('ID Cards'), findsOneWidget);
    expect(find.byType(MorphSheet), findsOneWidget);
  });

  testWidgets('close dismisses the whole sheet', (WidgetTester tester) async {
    await _openDocumentsMenu(tester);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(MorphSheet), findsNothing);
  });

  testWidgets('close is still one tap out from a sub-step', (
    WidgetTester tester,
  ) async {
    final List<bool> chosen = <bool>[];
    await _openDocumentsMenu(tester, onSelectPassportKind: chosen.add);

    await tester.tap(find.text('Passport'));
    await tester.pumpAndSettle();
    expect(find.text('E-Passport'), findsOneWidget);

    // Close stays in the same slot at every depth, so leaving never requires
    // walking back up the stack first.
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(MorphSheet), findsNothing);
    expect(chosen, isEmpty);
  });

  testWidgets('back is not offered at the root', (WidgetTester tester) async {
    await _openDocumentsMenu(tester);

    // The slot is reserved so the heading does not shift, but at the root it
    // is transparent and takes no input.
    expect(
      tester.widget<IgnorePointer>(
        find.ancestor(
          of: find.byIcon(Icons.arrow_back_rounded),
          matching: find.byType(IgnorePointer),
        ).first,
      ).ignoring,
      isTrue,
    );
  });

  testWidgets('selecting a kind closes the sheet and reports the choice', (
    WidgetTester tester,
  ) async {
    final List<bool> chosen = <bool>[];
    await _openDocumentsMenu(tester, onSelectPassportKind: chosen.add);

    await tester.tap(find.text('Passport'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('E-Passport'));
    await tester.pumpAndSettle();

    expect(chosen, <bool>[true]);
    expect(find.byType(MorphSheet), findsNothing);
  });

  testWidgets('unsupported ID types are disabled and do not fire', (
    WidgetTester tester,
  ) async {
    final List<IdDocumentType> chosen = <IdDocumentType>[];
    await _openDocumentsMenu(tester, onSelectIdType: chosen.add);

    await tester.tap(find.text('ID Cards'));
    await tester.pumpAndSettle();

    expect(find.text('Driving Licence'), findsOneWidget);
    await tester.tap(find.text('Driving Licence'));
    await tester.pumpAndSettle();

    // Still on the ID step, nothing selected.
    expect(chosen, isEmpty);
    expect(find.byType(MorphSheet), findsOneWidget);

    final SquircleTile soonTile = tester.widget<SquircleTile>(
      find.widgetWithText(SquircleTile, 'Driving Licence'),
    );
    expect(soonTile.soon, isTrue);
    expect(soonTile.onTap, isNull);
  });

  testWidgets('sheet fits a small screen without overflowing', (
    WidgetTester tester,
  ) async {
    // 320x568 — the collapse case a modern test device would hide.
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _openDocumentsMenu(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Passport'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('E-Passport'), findsOneWidget);
  });
}
