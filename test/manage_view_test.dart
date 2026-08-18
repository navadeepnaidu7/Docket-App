import 'package:docket/core/wallet/wallet_items.dart';
import 'package:docket/core/wallet/wallet_palette.dart';
import 'package:docket/features/dashboard/application/wallet_loading_provider.dart';
import 'package:docket/features/dashboard/application/wallet_order_provider.dart';
import 'package:docket/features/dashboard/presentation/widgets/ids_tab.dart';
import 'package:docket/features/dashboard/presentation/widgets/manage_cards_view.dart';
import 'package:docket/features/dashboard/presentation/widgets/wallet_row_tile.dart';
import 'package:docket/features/ids/domain/id_document.dart';
import 'package:docket/features/passport/domain/passport_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

PassportProfile _passport({String id = 'p1', String name = 'Asha Rao'}) {
  return PassportProfile(
    id: id,
    name: name,
    passportNumber: 'Z3456789',
    nationality: 'IND',
    dateOfBirth: '1994-03-12',
    expiryDate: '2032-09-04',
    imagePath: '',
    mrzRaw: '',
  );
}

IdDocument _id({
  String id = 'i1',
  String holder = 'Asha Rao',
  IdDocumentType type = IdDocumentType.pan,
}) {
  return IdDocument(
    id: id,
    type: type,
    holderName: holder,
    documentNumber: 'ABCDE1234F',
  );
}

/// Pumps [IdsTab] with a loaded wallet and returns after the reveal handoff.
///
/// The loading overrides are load-bearing: `passportLoadingProvider` and
/// `idLoadingProvider` both default to true, so without them IdsTab renders a
/// spinner, never builds the PageView, and every reveal assertion passes for
/// the wrong reason.
Future<void> _pumpIdsTab(
  WidgetTester tester, {
  required List<Object> items,
  required ValueNotifier<String?> reveal,
  required ValueNotifier<double> page,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        passportLoadingProvider.overrideWith((Ref ref) => false),
        idLoadingProvider.overrideWith((Ref ref) => false),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: IdsTab(
            items: items,
            allItems: items,
            onDeletePassport: (_) {},
            onDeleteId: (_) {},
            pageNotifier: page,
            revealItemId: reveal,
          ),
        ),
      ),
    ),
  );
  // Not pumpAndSettle: the wallet carousel runs a continuous animation, so it
  // never reaches a quiescent frame. One pump to build, one to run the
  // post-frame jump.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _pumpManage(
  WidgetTester tester, {
  required List<Object> items,
  ValueChanged<Object>? onReveal,
  ValueChanged<Object>? onRemove,
  VoidCallback? onOpenTrash,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: ManageCardsView(
            items: items,
            onRevealItem: onReveal ?? (_) {},
            onRemoveItem: onRemove ?? (_) {},
            onOpenTrash: onOpenTrash ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Manage list', () {
    testWidgets('renders one row per document, typed by its title', (
      WidgetTester tester,
    ) async {
      await _pumpManage(
        tester,
        items: <Object>[_passport(), _id()],
      );

      expect(find.byType(WalletRowTile), findsNWidgets(2));
      // The document type is the title. No possessive, and no chip beside it
      // repeating the same word.
      expect(find.text('Passport'), findsOneWidget);
      expect(find.text('PAN Card'), findsOneWidget);
      expect(find.text("Asha's Passport"), findsNothing);
      expect(find.text("Asha's ID"), findsNothing);
      // The number sits on the same line, right-aligned.
      expect(find.text('Z3456789'), findsOneWidget);
      expect(find.text('ABCDE1234F'), findsOneWidget);
      // One mini card per row, in that document's own palette.
      expect(find.byType(WalletMiniCard), findsNWidgets(2));
    });

    testWidgets('caption counts documents and does not repeat the nav title', (
      WidgetTester tester,
    ) async {
      await _pumpManage(tester, items: <Object>[_passport(), _id()]);

      expect(find.text('2 documents · drag to reorder'), findsOneWidget);
      // The old view drew its own "Wallet order" heading directly under the
      // shared header's "Manage" title. Two titles, one gap apart.
      expect(find.text('Wallet order'), findsNothing);
    });

    testWidgets('tapping a row reveals that document, not its neighbour', (
      WidgetTester tester,
    ) async {
      Object? revealed;
      final IdDocument target = _id(
        id: 'i9',
        holder: 'Bela Nair',
        type: IdDocumentType.aadhaar,
      );

      await _pumpManage(
        tester,
        items: <Object>[_passport(), target],
        onReveal: (Object item) => revealed = item,
      );

      await tester.tap(find.text('Aadhaar Card'));
      await tester.pumpAndSettle();

      expect(revealed, same(target));
    });

    testWidgets('swipe to remove asks first and can be cancelled', (
      WidgetTester tester,
    ) async {
      Object? removed;
      await _pumpManage(
        tester,
        items: <Object>[_passport(), _id()],
        onRemove: (Object item) => removed = item,
      );

      await tester.drag(find.text('Passport'), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(find.text('Remove from wallet?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(removed, isNull);
      expect(find.byType(WalletRowTile), findsNWidgets(2));
    });

    testWidgets('confirming the swipe reports the removed document', (
      WidgetTester tester,
    ) async {
      Object? removed;
      final PassportProfile target = _passport();

      await _pumpManage(
        tester,
        items: <Object>[target, _id()],
        onRemove: (Object item) => removed = item,
      );

      await tester.drag(find.text('Passport'), const Offset(-400, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(removed, same(target));
    });

    testWidgets('empty wallet shows the empty state, not an empty card', (
      WidgetTester tester,
    ) async {
      await _pumpManage(tester, items: <Object>[]);

      expect(find.text('No cards in wallet'), findsOneWidget);
      expect(find.byType(WalletRowTile), findsNothing);
    });

    testWidgets('trash footer routes to the trash view', (
      WidgetTester tester,
    ) async {
      int opened = 0;
      await _pumpManage(
        tester,
        items: <Object>[_passport()],
        onOpenTrash: () => opened++,
      );

      await tester.tap(find.text('Trash'));
      await tester.pumpAndSettle();

      expect(opened, 1);
    });
  });

  group('Reorder persistence', () {
    testWidgets('dragging a row writes the new order to walletOrderProvider', (
      WidgetTester tester,
    ) async {
      final List<Object> items = <Object>[
        _passport(id: 'p1'),
        _id(id: 'i1'),
        _id(id: 'i2', type: IdDocumentType.aadhaar),
      ];
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: ManageCardsView(
                items: items,
                onRevealItem: (_) {},
                onRemoveItem: (_) {},
                onOpenTrash: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Drag the first row's handle down past the second row. Incremental
      // moves, not one jump: SliverReorderableList only re-evaluates the drop
      // target as the pointer crosses each row.
      final Finder handle = find.byType(ReorderableDragStartListener).first;
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(handle),
      );
      await tester.pump(const Duration(milliseconds: 200));
      for (int i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(0, 12));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      // p1 must no longer be first. The exact landing index depends on row
      // height, so assert the invariant rather than a hardcoded permutation.
      final List<String> saved = container.read(walletOrderProvider);
      expect(saved, hasLength(3));
      expect(saved.toSet(), <String>{'p1', 'i1', 'i2'});
      expect(saved.first, isNot('p1'));
    });
  });

  group('Reveal handoff', () {
    testWidgets('IdsTab pages to the requested card and clears the request', (
      WidgetTester tester,
    ) async {
      final List<Object> items = <Object>[
        _passport(id: 'p1'),
        _id(id: 'i1'),
        _id(id: 'i2', type: IdDocumentType.aadhaar),
      ];
      final ValueNotifier<String?> reveal = ValueNotifier<String?>('i2');
      final ValueNotifier<double> page = ValueNotifier<double>(0);
      addTearDown(reveal.dispose);
      addTearDown(page.dispose);

      // The request is set before IdsTab mounts — which is what happens for
      // real, because Manage is on screen when the row is tapped.
      await _pumpIdsTab(tester, items: items, reveal: reveal, page: page);

      expect(page.value, 2, reason: 'should page to i2, index 2');
      expect(reveal.value, isNull, reason: 'request must be consumed');
    });

    testWidgets('a request for a card that is not visible is dropped', (
      WidgetTester tester,
    ) async {
      final List<Object> items = <Object>[_passport(id: 'p1'), _id(id: 'i1')];
      final ValueNotifier<String?> reveal = ValueNotifier<String?>('gone');
      final ValueNotifier<double> page = ValueNotifier<double>(0);
      addTearDown(reveal.dispose);
      addTearDown(page.dispose);

      await _pumpIdsTab(tester, items: items, reveal: reveal, page: page);

      // Dropped, not landed on an arbitrary neighbour.
      expect(page.value, 0);
      expect(reveal.value, isNull);
    });
  });

  group('Shared row metadata', () {
    test('the type is the title, and the number is the value', () {
      expect(WalletRowMeta.of(_passport()).title, 'Passport');
      expect(WalletRowMeta.of(_passport()).value, 'Z3456789');
      expect(WalletRowMeta.of(_id()).title, 'PAN Card');
      expect(
        WalletRowMeta.of(_id(type: IdDocumentType.aadhaar)).title,
        'Aadhaar Card',
      );
    });

    test('a document with no number says so rather than rendering blank', () {
      final IdDocument blank = IdDocument(
        id: 'x',
        type: IdDocumentType.pan,
        holderName: 'Asha',
        documentNumber: '',
      );
      expect(WalletRowMeta.of(blank).value, 'No number');
      expect(WalletRowMeta.of(blank).hasValue, isFalse);
    });

    test('each row carries its own card palette, not one shared accent', () {
      final WalletPalette pass = WalletRowMeta.of(_passport()).palette;
      final WalletPalette pan = WalletRowMeta.of(_id()).palette;
      final WalletPalette aadhaar =
          WalletRowMeta.of(_id(type: IdDocumentType.aadhaar)).palette;

      expect(pass.primary, isNot(pan.primary));
      expect(pan.primary, isNot(aadhaar.primary));
    });

    test('wallet item ids stay stable across both row surfaces', () {
      expect(walletItemId(_passport(id: 'p7')), 'p7');
      expect(walletItemId(_id(id: 'i7')), 'i7');
    });
  });
}
