import 'dart:async';
import 'dart:convert';

import 'package:docket/core/storage/secure_document_store.dart';
import 'package:docket/features/dashboard/application/wallet_order_provider.dart';
import 'package:docket/features/ids/application/id_list_provider.dart';
import 'package:docket/features/ids/domain/id_document.dart';
import 'package:docket/features/passport/application/passport_list_provider.dart';
import 'package:docket/features/passport/domain/passport_profile.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => messenger.setMockMethodCallHandler(_storage, null));

  test(
    'adds during slow startup retain both old and new documents and order',
    () async {
      final pending = Completer<void>();
      final values = <String, String>{
        'saved_passports': jsonEncode([
          PassportProfile.empty().copyWith(id: 'old-p').toJson(),
        ]),
        'saved_id_documents': jsonEncode([
          IdDocument.empty(IdDocumentType.pan).copyWith(id: 'old-id').toJson(),
        ]),
        'wallet_items_order': jsonEncode(['old-id', 'old-p']),
      };
      var writes = 0;
      messenger.setMockMethodCallHandler(_storage, (call) async {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final key = args['key'] as String;
        if (call.method == 'read') {
          await pending.future;
          return values[key];
        }
        if (call.method == 'write') {
          writes++;
          values[key] = args['value'] as String;
        }
        return null;
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final passports = container.read(passportListProvider.notifier);
      final ids = container.read(idListProvider.notifier);
      final order = container.read(walletOrderProvider.notifier);
      passports.addPassport(PassportProfile.empty().copyWith(id: 'new-p'));
      ids.addDocument(
        IdDocument.empty(IdDocumentType.pan).copyWith(id: 'new-id'),
      );
      order.updateOrderOnItemAdded('new-p');
      order.updateOrderOnItemAdded('new-id');
      await Future<void>.delayed(Duration.zero);
      expect(writes, 0);
      pending.complete();
      await Future.wait([passports.loaded, ids.loaded, order.loadOrder()]);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(container.read(passportListProvider).map((p) => p.id), [
        'new-p',
        'old-p',
      ]);
      expect(container.read(idListProvider).map((d) => d.id), [
        'new-id',
        'old-id',
      ]);
      expect(container.read(walletOrderProvider), [
        'new-id',
        'new-p',
        'old-id',
        'old-p',
      ]);
      expect(jsonDecode(values['saved_passports']!), hasLength(2));
      expect(jsonDecode(values['saved_id_documents']!), hasLength(2));
      expect(jsonDecode(values['wallet_items_order']!), [
        'new-id',
        'new-p',
        'old-id',
        'old-p',
      ]);
    },
  );

  test(
    'a corrupt record blocks migration rewrite and later partial saves',
    () async {
      final legacy = PassportProfile.empty().copyWith(id: 'legacy').toMap()
        ..remove('v');
      final original = jsonEncode([jsonEncode(legacy), '{broken']);
      var writes = 0;
      messenger.setMockMethodCallHandler(_storage, (call) async {
        if (call.method == 'read') return original;
        if (call.method == 'write') writes++;
        return null;
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(passportListProvider.notifier);
      await controller.loaded;
      expect(container.read(passportListProvider).single.id, 'legacy');
      expect(SecureDocumentStore.isUnreadable('saved_passports'), isTrue);
      controller.addPassport(PassportProfile.empty());
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(writes, 0);
    },
  );

  test('failed save does not poison the next save in a burst', () async {
    var attempts = 0;
    String? persisted;
    messenger.setMockMethodCallHandler(_storage, (call) async {
      if (call.method == 'read') return null;
      if (call.method == 'write') {
        if (++attempts == 1) throw PlatformException(code: 'temporary');
        persisted = (call.arguments as Map)['value'] as String;
      }
      return null;
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(passportListProvider.notifier);
    await controller.loaded;
    for (var index = 0; index < 100; index++) {
      controller.addPassport(PassportProfile.empty().copyWith(id: '$index'));
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(attempts, 100);
    expect(jsonDecode(persisted!), hasLength(100));
  });
}
