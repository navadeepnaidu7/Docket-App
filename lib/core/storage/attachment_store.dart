import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/ids/domain/id_attachment.dart';
import '../../features/ids/domain/id_document.dart';
import 'secure_document_store.dart';

class _EncryptParams {
  const _EncryptParams({
    required this.cleartext,
    required this.keyBytes,
  });

  final Uint8List cleartext;
  final Uint8List keyBytes;
}

class _DecryptParams {
  const _DecryptParams({
    required this.encryptedData,
    required this.keyBytes,
  });

  final Uint8List encryptedData;
  final Uint8List keyBytes;
}

String _joinPath(String p1, String p2, [String? p3]) {
  final sep = Platform.pathSeparator;
  if (p3 != null) {
    return '$p1$sep$p2$sep$p3';
  }
  return '$p1$sep$p2';
}

String _basenamePath(String fullPath) {
  final normalized = fullPath.replaceAll('\\', '/');
  final parts = normalized.split('/');
  return parts.lastWhere((p) => p.isNotEmpty, orElse: () => '');
}

/// Runs AES-GCM 256-bit encryption off the main UI isolate via compute.
///
/// Encrypted payload format on disk:
/// [12-byte nonce] + [ciphertext] + [16-byte GCM tag].
Future<Uint8List> _encryptPayloadOffIsolate(_EncryptParams params) async {
  final algorithm = Cryptography.instance.aesGcm();
  final secretKey = SecretKey(params.keyBytes);
  final nonce = algorithm.newNonce();

  final secretBox = await algorithm.encrypt(
    params.cleartext,
    secretKey: secretKey,
    nonce: nonce,
  );

  final builder = BytesBuilder(copy: false);
  builder.add(secretBox.nonce);
  builder.add(secretBox.cipherText);
  builder.add(secretBox.mac.bytes);
  return builder.toBytes();
}

/// Runs AES-GCM 256-bit decryption off the main UI isolate via compute.
///
/// Expects layout: [12-byte nonce] + [ciphertext] + [16-byte GCM tag].
Future<Uint8List> _decryptPayloadOffIsolate(_DecryptParams params) async {
  final raw = params.encryptedData;
  if (raw.length < 28) {
    throw const FormatException(
      'Attachment file is corrupted or too short for encrypted payload.',
    );
  }

  final nonce = raw.sublist(0, 12);
  final ciphertext = raw.sublist(12, raw.length - 16);
  final macBytes = raw.sublist(raw.length - 16);

  final algorithm = Cryptography.instance.aesGcm();
  final secretBox = SecretBox(
    ciphertext,
    nonce: nonce,
    mac: Mac(macBytes),
  );

  final decrypted = await algorithm.decrypt(
    secretBox,
    secretKey: SecretKey(params.keyBytes),
  );

  return Uint8List.fromList(decrypted);
}

/// Encrypted file store for ID document attachments.
///
/// Attachment files live in `<app documents dir>/id_attachments/<docId>/<attachmentId>.enc`.
/// Each file is encrypted at rest using AES-GCM (256-bit key) with an isolated
/// key stored in [FlutterSecureStorage] under `attachment_key_v1`.
///
/// To prevent corrupting existing encrypted attachment files, key reads enforce
/// an unreadable interlock: if loading `attachment_key_v1` throws, the key is marked
/// unreadable and all future write or key generation operations are refused.
class AttachmentStore {
  AttachmentStore({
    Directory? baseDir,
    FlutterSecureStorage? storage,
  })  : _baseDirOverride = baseDir,
        _storage = storage ??
            const FlutterSecureStorage(aOptions: kDocketAndroidOptions);

  final Directory? _baseDirOverride;
  final FlutterSecureStorage _storage;

  static bool _keyUnreadable = false;
  static Uint8List? _cachedKeyBytes;

  /// Future chain that serialises writes and deletes so concurrent mutations
  /// cannot interleave.
  ///
  /// Static on purpose. A queue only orders the work that shares it, so a
  /// per-instance chain would quietly degrade to a no-op the moment a caller
  /// constructed an AttachmentStore per call rather than holding one shared
  /// instance -- and the resulting interleave would be invisible until two
  /// writes to the same document raced in the field.
  static Future<void> _saveQueue = Future<void>.value();

  /// LRU cache of decrypted attachment bytes (cap 4 entries).
  ///
  /// Keyed by `<docId>/<attachmentId>` rather than the attachment id alone, so
  /// [deleteAllFor] can drop exactly one document's entries instead of flushing
  /// every other document's decrypted bytes with them.
  final LinkedHashMap<String, Uint8List> _lruCache =
      LinkedHashMap<String, Uint8List>();

  static String _cacheKey(String docId, String attachmentId) =>
      '$docId/$attachmentId';

  /// Resets test-only key state.
  static void resetKeyStateForTest() {
    _keyUnreadable = false;
    _cachedKeyBytes = null;
  }

  /// Clears the in-memory decrypted bytes LRU cache.
  void clearCache() {
    _lruCache.clear();
  }

  void _touchCache(String id, Uint8List bytes) {
    _lruCache.remove(id);
    _lruCache[id] = bytes;
    if (_lruCache.length > 4) {
      _lruCache.remove(_lruCache.keys.first);
    }
  }

  Uint8List? _getFromCache(String id) {
    if (_lruCache.containsKey(id)) {
      final bytes = _lruCache.remove(id);
      if (bytes != null) {
        _lruCache[id] = bytes;
        return bytes;
      }
    }
    return null;
  }

  Future<Directory> _getAppDocDir() async {
    final baseDir = _baseDirOverride;
    if (baseDir != null) {
      return baseDir;
    }
    return getApplicationDocumentsDirectory();
  }

  Future<Directory> _getAttachmentsBaseDir() async {
    final appDocDir = await _getAppDocDir();
    final dir = Directory(_joinPath(appDocDir.path, 'id_attachments'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _dirFor(String docId) async {
    final base = await _getAttachmentsBaseDir();
    final docDir = Directory(_joinPath(base.path, docId));
    if (!await docDir.exists()) {
      await docDir.create(recursive: true);
    }
    return docDir;
  }

  /// Lazily fetches or creates the 256-bit encryption key.
  ///
  /// If reading `attachment_key_v1` throws, [_keyUnreadable] is armed to prevent
  /// generating a replacement key over existing files encrypted with the old key.
  Future<Uint8List> _getOrCreateKey() async {
    if (_keyUnreadable) {
      throw StateError(
        'Refusing attachment store operation: attachment_key_v1 could not be read previously.',
      );
    }
    if (_cachedKeyBytes != null) {
      return _cachedKeyBytes!;
    }

    final String? base64Key;
    try {
      base64Key = await _storage.read(key: 'attachment_key_v1');
    } catch (_) {
      _keyUnreadable = true;
      throw StateError(
        'Refusing attachment store operation: failed to read attachment_key_v1 from secure storage.',
      );
    }

    if (base64Key != null && base64Key.isNotEmpty) {
      final Uint8List decoded;
      try {
        decoded = base64Decode(base64Key);
      } catch (_) {
        _keyUnreadable = true;
        throw StateError(
          'Refusing attachment store operation: stored attachment_key_v1 is corrupted.',
        );
      }

      // A key that is present but the wrong length has to arm the interlock as
      // well. Falling through to generation would write a fresh key over the
      // stored one and leave every existing attachment permanently
      // undecryptable -- the same shape of silent destruction that
      // `resetOnError: false` guards against in SecureDocumentStore. There is
      // no recovery from it, so refusing is the only safe direction.
      if (decoded.length != 32) {
        _keyUnreadable = true;
        throw StateError(
          'Refusing attachment store operation: stored attachment_key_v1 is '
          'not a 256-bit key.',
        );
      }

      _cachedKeyBytes = decoded;
      return decoded;
    }

    // A read that returns null is the fourth way this can go wrong, and until
    // now it was the unguarded one: the throw, the bad decode and the wrong
    // length all arm the interlock, but a plain missing entry looked like a
    // first run. It is not, if ciphertext is already on disk -- a restored
    // backup, a plugin-level clear, or a keystore entry that resolves to null
    // instead of throwing all land here. Minting a key then would leave every
    // existing attachment undecryptable with no way back.
    if (await _hasExistingAttachmentFiles()) {
      _keyUnreadable = true;
      throw StateError(
        'Refusing attachment store operation: attachment_key_v1 is absent but '
        'encrypted attachment files exist.',
      );
    }

    // Key missing and no ciphertext to orphan: a genuine first run.
    final keyBytes = Uint8List(32);
    final random = Random.secure();
    for (int i = 0; i < 32; i++) {
      keyBytes[i] = random.nextInt(256);
    }

    try {
      await _storage.write(
        key: 'attachment_key_v1',
        value: base64Encode(keyBytes),
      );
    } catch (_) {
      _keyUnreadable = true;
      throw StateError(
        'Refusing attachment store operation: failed to write attachment_key_v1 to secure storage.',
      );
    }

    _cachedKeyBytes = keyBytes;
    return keyBytes;
  }

  /// True when at least one encrypted attachment file is already on disk.
  ///
  /// Cheap enough to run only on the key-generation path, which happens once
  /// per install.
  Future<bool> _hasExistingAttachmentFiles() async {
    try {
      final Directory base = await _getAttachmentsBaseDir();
      await for (final FileSystemEntity entity
          in base.list(recursive: true, followLinks: false)) {
        if (entity is File) return true;
      }
    } catch (_) {
      // If the directory cannot be inspected, assume the worst and treat it as
      // populated. Refusing is always recoverable; orphaning is not.
      return true;
    }
    return false;
  }

  /// Loads the key without ever creating one.
  ///
  /// Read paths must use this. Going through [_getOrCreateKey] would let a
  /// pure read mint and persist a key as a side effect, which is how a preview
  /// of a broken attachment could quietly destroy every other one.
  Future<Uint8List> _requireKey() async {
    if (_keyUnreadable) {
      throw StateError(
        'Refusing attachment store read: attachment_key_v1 could not be read '
        'previously.',
      );
    }

    final Uint8List? cached = _cachedKeyBytes;
    if (cached != null) return cached;

    final String? stored;
    try {
      stored = await _storage.read(key: 'attachment_key_v1');
    } catch (_) {
      _keyUnreadable = true;
      throw StateError(
        'Refusing attachment store read: failed to read attachment_key_v1 '
        'from secure storage.',
      );
    }

    if (stored == null || stored.isEmpty) {
      throw StateError(
        'Refusing attachment store read: attachment_key_v1 is not available.',
      );
    }

    final Uint8List decoded;
    try {
      decoded = base64Decode(stored);
    } catch (_) {
      _keyUnreadable = true;
      throw StateError(
        'Refusing attachment store read: stored attachment_key_v1 is corrupted.',
      );
    }

    if (decoded.length != 32) {
      _keyUnreadable = true;
      throw StateError(
        'Refusing attachment store read: stored attachment_key_v1 is not a '
        '256-bit key.',
      );
    }

    _cachedKeyBytes = decoded;
    return decoded;
  }

  /// Encrypts and saves [file] into app storage under [docId].
  ///
  /// [file] is copied (never moved) because file picker / camera temp files
  /// reside in OS-reapable directories. Writes are serialized through [_saveQueue].
  ///
  /// [source] records provenance on the resulting record: 'picker' for a
  /// user-chosen file, 'scan' when the ID scanner hands over the original it
  /// just captured.
  Future<IdAttachment> save({
    required String docId,
    required File file,
    required IdAttachmentKind kind,
    String source = 'picker',
  }) {
    final completer = Completer<IdAttachment>();
    _saveQueue = _saveQueue.then((_) async {
      try {
        final result = await _performSave(
          docId: docId,
          file: file,
          kind: kind,
          source: source,
        );
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<IdAttachment> _performSave({
    required String docId,
    required File file,
    required IdAttachmentKind kind,
    required String source,
  }) async {
    final keyBytes = await _getOrCreateKey();
    final Uint8List rawBytes = await file.readAsBytes();

    if (kind == IdAttachmentKind.image) {
      // TODO(phase-1): downscale image on write (long edge 2048px, JPEG q85)
      // when an image processing dependency is added in a future phase.
    }

    final attachment = IdAttachment(
      kind: kind,
      fileName: '',
      sizeBytes: rawBytes.length,
      addedAt: DateTime.now(),
      source: source,
    );

    final relativeFileName = '${attachment.id}.enc';
    final finalAttachment = attachment.copyWith(fileName: relativeFileName);

    final encryptedBytes = await compute(
      _encryptPayloadOffIsolate,
      _EncryptParams(cleartext: rawBytes, keyBytes: keyBytes),
    );

    final docDir = await _dirFor(docId);
    final targetFile = File(_joinPath(docDir.path, relativeFileName));
    await targetFile.writeAsBytes(encryptedBytes, flush: true);

    return finalAttachment;
  }

  /// Reads and decrypts attachment bytes into memory.
  ///
  /// Results are cached in [_lruCache]. Decrypt failures surface as errors
  /// and NEVER cause disk files to be deleted.
  Future<Uint8List> resolveBytes(String docId, IdAttachment a) async {
    final cacheKey = _cacheKey(docId, a.id);
    final cached = _getFromCache(cacheKey);
    if (cached != null) {
      return cached;
    }

    final keyBytes = await _requireKey();
    final docDir = await _dirFor(docId);
    final file = File(_joinPath(docDir.path, a.fileName));

    if (!await file.exists()) {
      throw FileSystemException(
        'Attachment file not found on disk.',
        file.path,
      );
    }

    final encryptedBytes = await file.readAsBytes();
    final decrypted = await compute(
      _decryptPayloadOffIsolate,
      _DecryptParams(encryptedData: encryptedBytes, keyBytes: keyBytes),
    );

    _touchCache(cacheKey, decrypted);
    return decrypted;
  }

  /// Deletes a single attachment file from disk.
  Future<void> delete(String docId, IdAttachment a) {
    final completer = Completer<void>();
    _saveQueue = _saveQueue.then((_) async {
      try {
        _lruCache.remove(_cacheKey(docId, a.id));
        final docDir = await _dirFor(docId);
        final file = File(_joinPath(docDir.path, a.fileName));
        if (await file.exists()) {
          await file.delete();
        }
        completer.complete();
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  /// Deletes all attachment files for a specific document ID.
  Future<void> deleteAllFor(String docId) {
    final completer = Completer<void>();
    _saveQueue = _saveQueue.then((_) async {
      try {
        final String prefix = '$docId/';
        _lruCache.removeWhere((String key, _) => key.startsWith(prefix));
        final docDir = await _dirFor(docId);
        if (await docDir.exists()) {
          await docDir.delete(recursive: true);
        }
        completer.complete();
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  /// Sweeps attachment directories and removes files/folders not referenced by [live].
  Future<void> sweepOrphans(Iterable<IdDocument> live) {
    final completer = Completer<void>();
    _saveQueue = _saveQueue.then((_) async {
      try {
        // _getAttachmentsBaseDir creates the directory, so it always exists
        // from here on -- no existence check is meaningful.
        final baseDir = await _getAttachmentsBaseDir();

        // Referenced names are compared per document folder by basename, not
        // by reconstructed absolute path. Two spellings of the same path
        // (separator style, a trailing separator, a resolved symlink) compare
        // unequal as strings, and the failure direction here is deleting a
        // file a live record still points at.
        final Map<String, Set<String>> referencedByDoc = <String, Set<String>>{};
        for (final doc in live) {
          referencedByDoc[doc.id] = doc.attachments
              .map((IdAttachment att) => att.fileName)
              .toSet();
        }

        final entities = await baseDir.list().toList();
        for (final entity in entities) {
          if (entity is! Directory) continue;

          final folderName = _basenamePath(entity.path);
          final Set<String>? referenced = referencedByDoc[folderName];
          if (referenced == null) {
            await entity.delete(recursive: true);
            continue;
          }

          for (final subEntity in await entity.list().toList()) {
            if (subEntity is! File) continue;
            if (!referenced.contains(_basenamePath(subEntity.path))) {
              await subEntity.delete();
            }
          }
        }
        completer.complete();
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }
}
