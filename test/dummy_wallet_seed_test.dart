import 'package:flutter_test/flutter_test.dart';

import 'package:docket/core/dev/dummy_wallet_seed.dart';
import 'package:docket/features/ids/domain/id_document.dart';

void main() {
  test('dummy passports cover regular, e-passport, sparse, and long-name', () {
    final List<String> ids =
        DummyWalletSeed.passports.map((p) => p.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(ids.every(DummyWalletSeed.isDummyId), isTrue);

    expect(
      DummyWalletSeed.passports.where((p) => p.isEPassport),
      isNotEmpty,
    );
    expect(
      DummyWalletSeed.passports.where((p) => !p.isEPassport),
      isNotEmpty,
    );
    expect(
      DummyWalletSeed.passports.where((p) => p.placeOfBirth.isEmpty),
      isNotEmpty,
    );
    expect(
      DummyWalletSeed.passports.any((p) => p.name.split(' ').length >= 3),
      isTrue,
    );
  });

  test('dummy IDs cover full and sparse Aadhaar and PAN', () {
    final List<String> ids = DummyWalletSeed.ids.map((d) => d.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(ids.every(DummyWalletSeed.isDummyId), isTrue);

    expect(
      DummyWalletSeed.ids.where((d) => d.type == IdDocumentType.aadhaar),
      hasLength(greaterThanOrEqualTo(2)),
    );
    expect(
      DummyWalletSeed.ids.where((d) => d.type == IdDocumentType.pan),
      hasLength(greaterThanOrEqualTo(2)),
    );
    expect(
      DummyWalletSeed.ids.where((d) => d.dateOfBirth.isEmpty),
      isNotEmpty,
    );
  });

  test('real records are not classified as dummy', () {
    expect(DummyWalletSeed.isDummyId('17230000000001'), isFalse);
  });
}
