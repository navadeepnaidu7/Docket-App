import 'package:docket/features/dashboard/domain/wallet_search.dart';
import 'package:docket/features/dashboard/presentation/wallet_search_screen.dart';
import 'package:docket/features/ids/domain/id_document.dart';
import 'package:docket/features/tickets/domain/pass_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final document = IdDocument(
  id: 'id-1',
  type: IdDocumentType.aadhaar,
  holderName: 'Asha Rao',
  documentNumber: '1234 5678 9012',
);
final train = TrainPassItem.fromJson({
  'id': 'train-1',
  'trainName': 'Coastal Express',
  'fromName': 'Chennai',
  'toName': 'Bengaluru',
  'pnr': '9876543210',
  'status': 'active',
  'passengers': [
    {'name': 'Arun Rao'},
  ],
});
final movie = MoviePassItem.fromJson({
  'id': 'movie-1',
  'movieTitle': 'Interstellar',
  'cinemaName': 'PVR Orion',
  'bookingId': 'BMS-2468',
  'status': 'expired',
});
final entries = [
  WalletSearchEntry.document(document),
  WalletSearchEntry.pass(train),
  WalletSearchEntry.pass(movie),
];

void main() {
  test('matches human fields, formatted identifiers and all query terms', () {
    for (final query in ['asha aadhaar', '123456789012', '1234 5678']) {
      expect(
        searchWallet(entries, query, WalletSearchScope.all).single.item,
        same(document),
      );
    }
    for (final query in ['CHENNAI bengaluru', 'arun', '9876543210']) {
      expect(
        searchWallet(entries, query, WalletSearchScope.all).single.item,
        same(train),
      );
    }
    expect(
      searchWallet(entries, 'bms2468', WalletSearchScope.all).single.item,
      same(movie),
    );
    expect(
      searchWallet(entries, 'chennai interstellar', WalletSearchScope.all),
      isEmpty,
    );
  });
  test('scopes separate current passes, documents and archive', () {
    expect(
      searchWallet(entries, '', WalletSearchScope.documents).single.item,
      same(document),
    );
    expect(
      searchWallet(entries, '', WalletSearchScope.passes).single.item,
      same(train),
    );
    expect(
      searchWallet(entries, '', WalletSearchScope.archive).single.item,
      same(movie),
    );
    expect(
      searchWallet(entries, 'interstellar', WalletSearchScope.passes),
      isEmpty,
    );
  });
  testWidgets('search, clear, scope and open are actionable', (tester) async {
    WalletSearchEntry? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: WalletSearchView(
          entries: entries,
          onOpen: (entry) => opened = entry,
          onAdd: () {},
          onRetry: () {},
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'interstellar');
    await tester.pump();
    await tester.tap(find.text('Interstellar'));
    expect(opened!.item, same(movie));
    await tester.tap(find.text('Documents'));
    await tester.pumpAndSettle();
    expect(find.text('No matching items'), findsOneWidget);
    await tester.tap(find.text('Show all items'));
    await tester.pumpAndSettle();
    expect(find.text('Aadhaar Card'), findsOneWidget);
  });
  testWidgets('long content stays usable at 320px, 2x text, with a keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
              viewInsets: EdgeInsets.only(bottom: 240),
            ),
            child: WalletSearchView(
              entries: entries,
              onOpen: (_) {},
              onAdd: () {},
              onRetry: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), 'nothing');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('pass loading failure does not hide available documents', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: WalletSearchView(
          entries: [WalletSearchEntry.document(document)],
          passesError: true,
          onOpen: (_) {},
          onAdd: () {},
          onRetry: () => retries++,
        ),
      ),
    );
    expect(find.text('Aadhaar Card'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });
}
