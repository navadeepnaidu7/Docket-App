import 'dart:async';
import 'dart:convert';
import 'package:docket/core/wallet/wallet_startup.dart';
import 'package:docket/features/passport/application/passport_list_provider.dart';
import 'package:docket/features/passport/domain/passport_profile.dart';
import 'package:docket/features/dashboard/application/wallet_order_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:docket/features/ids/domain/id_document.dart';
import 'package:docket/features/cards/domain/payment_card.dart';

const storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, null),
  );

  test(
    'launch waits for documents, saved order and artwork, without duplicate reads',
    () async {
      final documents = Completer<String?>();
      final artwork = Completer<void>();
      final reads = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(storage, (call) async {
            final key = (call.arguments as Map)['key'] as String;
            if (call.method != 'read') return null;
            reads.add(key);
            if (key == 'saved_passports') return documents.future;
            if (key == 'wallet_items_order') {
              return jsonEncode(['second', 'first']);
            }
            return null;
          });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      List<Object>? warmed;
      bool ready = false;
      final boot = prepareWalletStartup(
        container,
        warm: (items) async {
          warmed = items;
          await artwork.future;
        },
      ).then((_) => ready = true);
      await Future<void>.delayed(Duration.zero);
      expect(ready, isFalse);
      expect(warmed, isNull);
      documents.complete(
        jsonEncode([
          PassportProfile.empty().copyWith(id: 'first').toJson(),
          PassportProfile.empty().copyWith(id: 'second').toJson(),
        ]),
      );
      await Future<void>.delayed(Duration.zero);
      expect(warmed!.cast<PassportProfile>().map((p) => p.id), [
        'second',
        'first',
      ]);
      expect(ready, isFalse);
      artwork.complete();
      await boot;
      expect(ready, isTrue);
      await container.read(passportListProvider.notifier).loaded;
      await container.read(walletOrderProvider.notifier).loadOrder();
      for (final key in [
        'saved_passports',
        'saved_id_documents',
        'saved_payment_cards',
        'wallet_items_order',
      ]) {
        expect(reads.where((value) => value == key), hasLength(1));
      }
    },
  );

  testWidgets('bundled first-face assets finish before any wallet is mounted', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.runAsync(
      () => warmInitialWalletAssets([
        PassportProfile.empty(),
        IdDocument.empty(IdDocumentType.aadhaar),
        PaymentCard(
          number: '4111111111111111',
          bankName: 'HDFC Bank',
          issuerId: 'hdfc',
        ),
      ]).timeout(const Duration(seconds: 5)),
    );
    expect(tester.takeException(), isNull);
  });

  test('asset failure still allows a loaded wallet to open', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, (_) async => null);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await prepareWalletStartup(
      container,
      warm: (_) async => throw StateError('asset missing'),
    );
    expect(container.read(walletOrderProvider.notifier).isLoaded, isTrue);
  });
}
