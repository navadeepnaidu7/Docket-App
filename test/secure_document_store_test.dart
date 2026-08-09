import 'package:docket/core/storage/secure_document_store.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
