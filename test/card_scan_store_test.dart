import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:docket/core/storage/card_scan_store.dart';
import 'package:docket/features/cards/domain/payment_card.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

String _join(String a, String b, [String? c, String? d]) {
  final String sep = Platform.pathSeparator;
  if (d != null) return '$a$sep$b$sep$c$sep$d';
  if (c != null) return '$a$sep$b$sep$c';
  return '$a$sep$b';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late _FakeSecureStorage storage;
  late CardScanStore store;
  late File source;

  setUp(() async {
    CardScanStore.resetKeyStateForTest();
    tempDir = await Directory.systemTemp.createTemp('card_scan_store_');
    storage = _FakeSecureStorage();
    store = CardScanStore(baseDir: tempDir, storage: storage);
    source = File(_join(tempDir.path, 'shot.jpg'));
    await source.writeAsBytes(Uint8List.fromList(<int>[9, 8, 7, 6, 5, 4]));
  });

  tearDown(() async {
    CardScanStore.resetKeyStateForTest();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('a saved photo decrypts back to the same bytes', () async {
    final CardScanRef saved = await store.save(
      cardId: 'card-1',
      side: 'front',
      file: source,
    );
    expect(saved.fileName, 'front.enc');
    expect(saved.sizeBytes, 6);
    final Uint8List clear = await store.read(cardId: 'card-1', scan: saved);
    expect(clear, Uint8List.fromList(<int>[9, 8, 7, 6, 5, 4]));
    expect(storage.values.containsKey(cardScanKeyName), isTrue);
  });

  test('a read without a key does not mint one', () async {
    await expectLater(
      store.read(
        cardId: 'missing',
        scan: const CardScanRef(side: 'front', fileName: 'front.enc', sizeBytes: 1),
      ),
      throwsStateError,
    );
    expect(store.keyUnreadable, isFalse);
    expect(storage.values.containsKey(cardScanKeyName), isFalse);
  });

  test('a key of the wrong length blocks every later write', () async {
    storage.values[cardScanKeyName] = base64Encode(Uint8List(16));
    await expectLater(
      store.save(cardId: 'card-1', side: 'front', file: source),
      throwsStateError,
    );
    expect(store.keyUnreadable, isTrue);
    await expectLater(
      store.save(cardId: 'card-2', side: 'back', file: source),
      throwsStateError,
    );
  });

  test('a missing key with photos already on disk blocks a new key', () async {
    final Directory dir = Directory(_join(tempDir.path, 'card_scans', 'old'));
    await dir.create(recursive: true);
    await File(_join(dir.path, 'front.enc')).writeAsBytes(<int>[1, 2, 3]);

    await expectLater(
      store.save(cardId: 'card-1', side: 'front', file: source),
      throwsStateError,
    );
    expect(store.keyUnreadable, isTrue);
    expect(storage.values.containsKey(cardScanKeyName), isFalse);
  });

  test('the sweep keeps live cards and deletes the rest', () async {
    await store.save(cardId: 'keep', side: 'front', file: source);
    await store.save(cardId: 'drop', side: 'back', file: source);
    await store.sweepOrphans(<String>{'keep'});

    expect(
      Directory(_join(tempDir.path, 'card_scans', 'keep')).existsSync(),
      isTrue,
    );
    expect(
      Directory(_join(tempDir.path, 'card_scans', 'drop')).existsSync(),
      isFalse,
    );

    await store.sweepOrphans(<String>{});
    expect(
      Directory(_join(tempDir.path, 'card_scans', 'keep')).existsSync(),
      isFalse,
    );
  });
}
