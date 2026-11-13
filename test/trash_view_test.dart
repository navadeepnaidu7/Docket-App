import 'package:docket/features/dashboard/application/trash_provider.dart';
import 'package:docket/features/dashboard/presentation/widgets/trash_tray_preview.dart';
import 'package:docket/features/dashboard/presentation/widgets/trash_view.dart';
import 'package:docket/features/dashboard/presentation/widgets/wallet_row_tile.dart';
import 'package:docket/features/ids/domain/id_document.dart';
import 'package:docket/features/passport/domain/passport_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

PassportProfile _passport() => PassportProfile(
  id: 'p1',
  name: 'Asha Rao',
  passportNumber: 'Z3456789',
  nationality: 'IND',
  dateOfBirth: '1994-03-12',
  expiryDate: '2032-09-04',
  imagePath: '',
  mrzRaw: '',
);

IdDocument _pan() => IdDocument(
  id: 'i1',
  type: IdDocumentType.pan,
  holderName: 'Asha Rao',
  documentNumber: 'ABCDE1234F',
);

/// Trash held in memory. Deletion only records and drops the item, so the
/// real [TrashController.emptyTrash] loop runs against it unchanged.
class _FakeTrash extends TrashController {
  _FakeTrash(super.ref, TrashState initial) {
    state = initial;
    loaded = Future<void>.value();
  }

  final List<Object> deleted = <Object>[];

  @override
  Future<void> permanentlyDeleteItem(Object item) async {
    deleted.add(item);
    state = TrashState(
      passports: state.passports.where((p) => !identical(p, item)).toList(),
      idDocs: state.idDocs.where((d) => !identical(d, item)).toList(),
    );
  }
}

Future<_FakeTrash> _pump(
  WidgetTester tester, {
  required TrashState initial,
  VoidCallback? onGoHome,
}) async {
  late _FakeTrash fake;
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        trashProvider.overrideWith(
          (Ref ref) => fake = _FakeTrash(ref, initial),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(body: TrashView(onGoHome: onGoHome)),
      ),
    ),
  );
  // Not pumpAndSettle: the empty-state artwork loops forever.
  await tester.pump(const Duration(seconds: 1));
  return fake;
}

void main() {
  testWidgets('empty Trash shows its own artwork and a way Home', (
    WidgetTester tester,
  ) async {
    int home = 0;
    await _pump(
      tester,
      initial: const TrashState(passports: [], idDocs: []),
      onGoHome: () => home++,
    );

    expect(find.byType(TrashTrayPreview), findsOneWidget);
    expect(
      find.textContaining('Trash is empty.', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(find.text('Go to Home'));
    await tester.pump();
    expect(home, 1);
  });

  testWidgets('trashed documents render as removed rows under a headline', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      initial: TrashState(passports: [_passport()], idDocs: [_pan()]),
    );

    expect(
      find.textContaining('2 in Trash.', findRichText: true),
      findsOneWidget,
    );
    final List<WalletRowTile> rows = tester
        .widgetList<WalletRowTile>(find.byType(WalletRowTile))
        .toList();
    expect(rows, hasLength(2));
    expect(rows.every((WalletRowTile r) => r.removed), isTrue);
    expect(find.byTooltip('Restore'), findsNWidgets(2));
    expect(find.byTooltip('Delete for good'), findsNWidgets(2));
  });

  testWidgets('Empty Trash asks first, then deletes every item', (
    WidgetTester tester,
  ) async {
    final _FakeTrash fake = await _pump(
      tester,
      initial: TrashState(passports: [_passport()], idDocs: [_pan()]),
    );

    // The control is a swipe. Its accessible action opens the same review
    // that a completed slide opens, without depending on the thumb's pixels.
    await _reviewEmptyTrash(tester);
    expect(find.textContaining('permanently?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(fake.deleted, isEmpty);

    await _reviewEmptyTrash(tester);
    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(fake.deleted, hasLength(2));
    expect(find.byType(TrashTrayPreview), findsOneWidget);
  });
}

Future<void> _reviewEmptyTrash(WidgetTester tester) async {
  final Finder slide = find.byKey(const ValueKey<String>('slide'));
  final Rect rect = tester.getRect(slide);
  // The thumb sits at the leading edge. A drag past the end opens the review.
  final TestGesture gesture = await tester.startGesture(
    Offset(rect.left + 34, rect.center.dy),
  );
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.moveBy(Offset(rect.width - 48, 0));
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.up();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}
