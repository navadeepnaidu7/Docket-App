import 'package:docket/core/wallet/wallet_items.dart';
import 'package:docket/features/passport/domain/passport_profile.dart';
import 'package:flutter_test/flutter_test.dart';

PassportProfile _passport(String id) =>
    PassportProfile.empty().copyWith(id: id);

void main() {
  test('large wallet keeps unlisted items after every persisted item', () {
    final passports = List.generate(12000, (i) => _passport('p$i'));
    final order = passports.reversed.map((p) => p.id).toList();
    final unknown = [_passport('unknown-a'), _passport('unknown-b')];
    final watch = Stopwatch()..start();
    final result = sortWalletItems(
      passports: [...unknown, ...passports],
      idDocs: [],
      order: order,
    );
    expect(result.map(walletItemId), [...order, 'unknown-a', 'unknown-b']);
    // A generous ceiling catches the former repeated linear scans without
    // depending on sub-millisecond benchmark timing on a particular machine.
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
  });

  test('duplicate order entries do not duplicate or drop documents', () {
    final a = _passport('a');
    final anotherA = _passport('a');
    final b = _passport('b');
    expect(
      sortWalletItems(
        passports: [b, a, anotherA],
        idDocs: [],
        order: ['missing', 'a', 'a'],
      ),
      [a, anotherA, b],
    );
  });

  test(
    'reconciliation deduplicates, removes stale ids and preserves order',
    () {
      expect(
        reconcileWalletOrder(
          order: ['b', 'gone', 'b', 'a'],
          activeIds: ['a', 'c', 'b', 'c'],
        ),
        ['b', 'a', 'c'],
      );
      expect(reconcileWalletOrder(order: ['gone'], activeIds: []), isEmpty);
    },
  );

  test('reconciliation handles 50000 items and is idempotent', () {
    final ids = List.generate(50000, (i) => '$i');
    final order = [...ids.reversed, 'stale'];
    final watch = Stopwatch()..start();
    final reconciled = reconcileWalletOrder(order: order, activeIds: ids);
    expect(reconciled, ids.reversed);
    expect(reconcileWalletOrder(order: reconciled, activeIds: ids), reconciled);
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
  });
}
