import 'package:docket/core/storage/secure_document_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The test host has no secure-storage plugin, so every read throws
/// MissingPluginException. That is the same shape as a keystore that will not
/// open on a device, which makes it a usable stand-in for the failure this
/// guard exists to survive.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String key = 'saved_passports_test';

  test('a failed read marks the key unreadable', () async {
    expect(SecureDocumentStore.isUnreadable(key), isFalse);

    await expectLater(SecureDocumentStore.readList(key), throwsA(anything));

    expect(SecureDocumentStore.isUnreadable(key), isTrue);
  });

  test('writes are refused while the key is unreadable', () async {
    await expectLater(SecureDocumentStore.readList(key), throwsA(anything));

    // Without this guard, a read that failed would surface as an empty list and
    // the first save of the session would replace real passports with nothing.
    await expectLater(
      SecureDocumentStore.writeList(key, <String>['{"id":"new"}']),
      throwsStateError,
    );
  });

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  for (final raw in ['{bad', '{}', 'null', '["valid", 42]']) {
    test('malformed list $raw preserves originals and blocks writes', () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var writes = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'read') return raw;
        writes++;
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await expectLater(
        SecureDocumentStore.readList('corrupt'),
        throwsFormatException,
      );
      expect(SecureDocumentStore.isUnreadable('corrupt'), isTrue);
      await expectLater(
        SecureDocumentStore.writeList('corrupt', []),
        throwsStateError,
      );
      expect(writes, 0);
    });
  }

  test(
    'a successful retry unlocks the key; valid empty lists remain valid',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async => '[]');
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      expect(await SecureDocumentStore.readList('corrupt'), isEmpty);
      expect(SecureDocumentStore.isUnreadable('corrupt'), isFalse);
    },
  );

  test('legacy preferences remain intact when migration write fails', () async {
    SharedPreferences.setMockInitialValues({
      'legacy': <String>['old'],
    });
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'read') return null;
      throw PlatformException(code: 'write-failed');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await expectLater(
      SecureDocumentStore.readList('legacy'),
      throwsA(isA<PlatformException>()),
    );
    expect((await SharedPreferences.getInstance()).getStringList('legacy'), [
      'old',
    ]);
    expect(SecureDocumentStore.isUnreadable('legacy'), isTrue);
  });
}
