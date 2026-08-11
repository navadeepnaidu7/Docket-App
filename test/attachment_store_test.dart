import 'dart:io';
import 'dart:typed_data';

import 'package:docket/core/storage/attachment_store.dart';
import 'package:docket/features/ids/domain/id_attachment.dart';
import 'package:docket/features/ids/domain/id_document.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _storage = {};
  bool shouldThrowOnRead = false;

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
    if (shouldThrowOnRead) {
      throw Exception('KeyStore storage read failure');
    }
    return _storage[key];
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
      _storage.remove(key);
    } else {
      _storage[key] = value;
    }
  }
}

String _join(String p1, String p2, [String? p3, String? p4]) {
  final sep = Platform.pathSeparator;
  if (p4 != null) return '$p1$sep$p2$sep$p3$sep$p4';
  if (p3 != null) return '$p1$sep$p2$sep$p3';
  return '$p1$sep$p2';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FakeSecureStorage fakeStorage;
  late AttachmentStore store;

  setUp(() async {
    AttachmentStore.resetKeyStateForTest();
    tempDir = await Directory.systemTemp.createTemp('att_store_test_');
    fakeStorage = FakeSecureStorage();
    store = AttachmentStore(baseDir: tempDir, storage: fakeStorage);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AttachmentStore', () {
    test('save and resolveBytes round-trip returns original bytes', () async {
      final docId = 'doc_test_1';
      final sourceFile = File(_join(tempDir.path, 'source_image.jpg'));
      final originalData = Uint8List.fromList(
        List.generate(1024, (i) => (i * 7) % 256),
      );
      await sourceFile.writeAsBytes(originalData);

      final attachment = await store.save(
        docId: docId,
        file: sourceFile,
        kind: IdAttachmentKind.image,
      );

      expect(attachment.fileName, endsWith('.enc'));
      expect(attachment.kind, equals(IdAttachmentKind.image));
      expect(attachment.sizeBytes, equals(1024));

      final resolvedBytes = await store.resolveBytes(docId, attachment);
      expect(resolvedBytes, equals(originalData));
    });

    test('delete removes attachment file from disk', () async {
      final docId = 'doc_test_2';
      final sourceFile = File(_join(tempDir.path, 'doc.pdf'));
      await sourceFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4, 5]));

      final attachment = await store.save(
        docId: docId,
        file: sourceFile,
        kind: IdAttachmentKind.pdf,
      );

      final encFile = File(
        _join(tempDir.path, 'id_attachments', docId, attachment.fileName),
      );
      expect(await encFile.exists(), isTrue);

      await store.delete(docId, attachment);
      expect(await encFile.exists(), isFalse);
    });

    test('deleteAllFor clears the document folder', () async {
      final docId = 'doc_test_3';
      final sourceFile = File(_join(tempDir.path, 'doc.jpg'));
      await sourceFile.writeAsBytes(Uint8List.fromList([10, 20, 30]));

      await store.save(
        docId: docId,
        file: sourceFile,
        kind: IdAttachmentKind.image,
      );

      final docFolder = Directory(_join(tempDir.path, 'id_attachments', docId));
      expect(await docFolder.exists(), isTrue);

      await store.deleteAllFor(docId);
      expect(await docFolder.exists(), isFalse);
    });

    test('sweepOrphans deletes unreferenced file and keeps referenced file', () async {
      final docId1 = 'doc_live';
      final docId2 = 'doc_orphaned';

      final sourceFile = File(_join(tempDir.path, 'sample.jpg'));
      await sourceFile.writeAsBytes(Uint8List.fromList([1, 1, 1, 1]));

      final refAttachment = await store.save(
        docId: docId1,
        file: sourceFile,
        kind: IdAttachmentKind.image,
      );

      final unrefAttachment = await store.save(
        docId: docId1,
        file: sourceFile,
        kind: IdAttachmentKind.image,
      );

      await store.save(
        docId: docId2,
        file: sourceFile,
        kind: IdAttachmentKind.image,
      );

      final refFile = File(
        _join(tempDir.path, 'id_attachments', docId1, refAttachment.fileName),
      );
      final unrefFile = File(
        _join(tempDir.path, 'id_attachments', docId1, unrefAttachment.fileName),
      );
      final orphanFolder = Directory(_join(tempDir.path, 'id_attachments', docId2));

      expect(await refFile.exists(), isTrue);
      expect(await unrefFile.exists(), isTrue);
      expect(await orphanFolder.exists(), isTrue);

      final liveDoc = IdDocument(
        id: docId1,
        type: IdDocumentType.pan,
        holderName: 'Alice',
        documentNumber: 'ABCD1234',
        attachments: [refAttachment],
      );

      await store.sweepOrphans([liveDoc]);

      expect(await refFile.exists(), isTrue);
      expect(await unrefFile.exists(), isFalse);
      expect(await orphanFolder.exists(), isFalse);
    });

    test('interlock: throwing during key read marks key unreadable and refuses save', () async {
      AttachmentStore.resetKeyStateForTest();
      fakeStorage.shouldThrowOnRead = true;

      final sourceFile = File(_join(tempDir.path, 'test.jpg'));
      await sourceFile.writeAsBytes(Uint8List.fromList([1, 2, 3]));

      try {
        final result = await store.save(
          docId: 'doc_fail',
          file: sourceFile,
          kind: IdAttachmentKind.image,
        );
        fail('Expected save to throw StateError, but it succeeded with attachment id ${result.id}');
      } on StateError {
        // Expected StateError
      }

      fakeStorage.shouldThrowOnRead = false;

      try {
        final result = await store.save(
          docId: 'doc_fail',
          file: sourceFile,
          kind: IdAttachmentKind.image,
        );
        fail('Expected save to throw StateError on second call, but it succeeded with attachment id ${result.id}');
      } on StateError {
        // Expected StateError
      }
    });

    test(
      'interlock: a stored key of the wrong length is refused, not replaced',
      () async {
        AttachmentStore.resetKeyStateForTest();

        // 16 bytes where 32 are required. Before the guard, this fell through
        // to the "key missing" branch and wrote a fresh key over the top,
        // which would leave every attachment already on disk undecryptable.
        const String shortKey = 'AAAAAAAAAAAAAAAAAAAAAA==';
        await fakeStorage.write(key: 'attachment_key_v1', value: shortKey);

        final sourceFile = File(_join(tempDir.path, 'short_key.jpg'));
        await sourceFile.writeAsBytes(Uint8List.fromList([9, 8, 7]));

        await expectLater(
          store.save(
            docId: 'doc_short_key',
            file: sourceFile,
            kind: IdAttachmentKind.image,
          ),
          throwsA(isA<StateError>()),
        );

        // The stored key must survive untouched: overwriting it is the
        // destructive outcome this guard exists to prevent.
        expect(
          await fakeStorage.read(key: 'attachment_key_v1'),
          shortKey,
        );
      },
    );

    test(
      'interlock: an absent key beside existing ciphertext is refused',
      () async {
        AttachmentStore.resetKeyStateForTest();

        // No key in storage, but encrypted files are already on disk. That is
        // not a first run -- it is a restore, a cleared keystore, or a read
        // that returned null instead of throwing. Minting a key here would
        // leave the planted file undecryptable forever.
        final Directory docDir = Directory(
          _join(tempDir.path, 'id_attachments', 'doc_existing'),
        );
        await docDir.create(recursive: true);
        final File planted = File(_join(docDir.path, 'planted.enc'));
        await planted.writeAsBytes(Uint8List.fromList(List<int>.filled(64, 7)));

        final sourceFile = File(_join(tempDir.path, 'new.jpg'));
        await sourceFile.writeAsBytes(Uint8List.fromList([1, 2, 3]));

        await expectLater(
          store.save(
            docId: 'doc_existing',
            file: sourceFile,
            kind: IdAttachmentKind.image,
          ),
          throwsA(isA<StateError>()),
        );

        expect(await planted.exists(), isTrue);
        expect(await fakeStorage.read(key: 'attachment_key_v1'), isNull);
      },
    );

    test('resolveBytes never mints a key', () async {
      AttachmentStore.resetKeyStateForTest();

      // A read path that creates a key would let merely previewing a broken
      // attachment destroy every other one on the device.
      final attachment = IdAttachment(
        id: 'missing',
        kind: IdAttachmentKind.image,
        fileName: 'missing.enc',
        sizeBytes: 10,
      );

      await expectLater(
        store.resolveBytes('doc_none', attachment),
        throwsA(isA<StateError>()),
      );
      expect(await fakeStorage.read(key: 'attachment_key_v1'), isNull);
    });
  });
}
