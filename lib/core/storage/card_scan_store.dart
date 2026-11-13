import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/cards/domain/payment_card.dart';
import 'secure_document_store.dart';

const String cardScanKeyName = 'card_scan_key_v1';

class _EncryptParams {
  const _EncryptParams({required this.cleartext, required this.keyBytes});

  final Uint8List cleartext;
  final Uint8List keyBytes;
}

class _DecryptParams {
  const _DecryptParams({required this.encryptedData, required this.keyBytes});

  final Uint8List encryptedData;
  final Uint8List keyBytes;
}

String _joinPath(String a, String b, [String? c]) {
  final String sep = Platform.pathSeparator;
  if (c != null) return '$a$sep$b$sep$c';
  return '$a$sep$b';
}

String _basename(String fullPath) {
  final String normalized = fullPath.replaceAll('\\', '/');
  final List<String> parts = normalized.split('/');
  return parts.lastWhere((String part) => part.isNotEmpty, orElse: () => '');
}

Future<Uint8List> _encryptCardScan(_EncryptParams params) async {
  final AesGcm algorithm = AesGcm.with256bits();
  final SecretBox box = await algorithm.encrypt(
    params.cleartext,
    secretKey: SecretKey(params.keyBytes),
  );
  final BytesBuilder builder = BytesBuilder(copy: false);
  builder.add(box.nonce);
  builder.add(box.cipherText);
  builder.add(box.mac.bytes);
  return builder.toBytes();
}

Future<Uint8List> _decryptCardScan(_DecryptParams params) async {
  final Uint8List raw = params.encryptedData;
  if (raw.length < 28) {
    throw const FormatException('Card scan file is too short to decrypt.');
  }
  final SecretBox box = SecretBox(
    raw.sublist(12, raw.length - 16),
    nonce: raw.sublist(0, 12),
    mac: Mac(raw.sublist(raw.length - 16)),
  );
  final List<int> clear = await AesGcm.with256bits().decrypt(
    box,
    secretKey: SecretKey(params.keyBytes),
  );
  return Uint8List.fromList(clear);
}

/// Encrypted front and back photos for payment cards.
///
/// Files live in `<app documents>/card_scans/<cardId>/<side>.enc`. The key is
/// `card_scan_key_v1`. A key that cannot be read, cannot be decoded, is the
/// wrong length, or is missing while files already exist is marked unreadable
/// and every later write is refused. A new key is never minted over photos
/// encrypted with the old one.
class CardScanStore {
  CardScanStore({Directory? baseDir, FlutterSecureStorage? storage})
    : _baseDirOverride = baseDir,
      _storage =
          storage ?? const FlutterSecureStorage(aOptions: kDocketAndroidOptions);

  final Directory? _baseDirOverride;
  final FlutterSecureStorage _storage;

  static bool _keyUnreadable = false;
  static Uint8List? _cachedKeyBytes;
  static Future<void> _saveQueue = Future<void>.value();

  bool get keyUnreadable => _keyUnreadable;

  static void resetKeyStateForTest() {
    _keyUnreadable = false;
    _cachedKeyBytes = null;
    _saveQueue = Future<void>.value();
  }

  Future<Directory> _root() async {
    final Directory base =
        _baseDirOverride ?? await getApplicationDocumentsDirectory();
    final Directory dir = Directory(_joinPath(base.path, 'card_scans'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<bool> _hasExistingFiles() async {
    try {
      final Directory root = await _root();
      await for (final FileSystemEntity entity
          in root.list(recursive: true, followLinks: false)) {
        if (entity is File) return true;
      }
    } catch (_) {
      return true;
    }
    return false;
  }

  Future<Uint8List> _getOrCreateKey() async {
    if (_keyUnreadable) {
      throw StateError(
        'Refusing card scan write: $cardScanKeyName could not be read previously.',
      );
    }
    final Uint8List? cached = _cachedKeyBytes;
    if (cached != null) return cached;

    final String? stored;
    try {
      stored = await _storage.read(key: cardScanKeyName);
    } catch (_) {
      _keyUnreadable = true;
      throw StateError(
        'Refusing card scan write: failed to read $cardScanKeyName.',
      );
    }

    if (stored != null && stored.isNotEmpty) {
      final Uint8List decoded;
      try {
        decoded = base64Decode(stored);
      } catch (_) {
        _keyUnreadable = true;
        throw StateError(
          'Refusing card scan write: stored $cardScanKeyName is corrupted.',
        );
      }
      if (decoded.length != 32) {
        _keyUnreadable = true;
        throw StateError(
          'Refusing card scan write: stored $cardScanKeyName is not a 256-bit key.',
        );
      }
      _cachedKeyBytes = decoded;
      return decoded;
    }

    if (await _hasExistingFiles()) {
      _keyUnreadable = true;
      throw StateError(
        'Refusing card scan write: $cardScanKeyName is absent but encrypted scans exist.',
      );
    }

    final Uint8List keyBytes = Uint8List(32);
    final Random random = Random.secure();
    for (var i = 0; i < 32; i++) {
      keyBytes[i] = random.nextInt(256);
    }
    try {
      await _storage.write(key: cardScanKeyName, value: base64Encode(keyBytes));
    } catch (_) {
      _keyUnreadable = true;
      throw StateError(
        'Refusing card scan write: failed to write $cardScanKeyName.',
      );
    }
    _cachedKeyBytes = keyBytes;
    return keyBytes;
  }

  Future<Uint8List> _requireKey() async {
    if (_keyUnreadable) {
      throw StateError(
        'Refusing card scan read: $cardScanKeyName could not be read previously.',
      );
    }
    final Uint8List? cached = _cachedKeyBytes;
    if (cached != null) return cached;
    final String? stored;
    try {
      stored = await _storage.read(key: cardScanKeyName);
    } catch (_) {
      _keyUnreadable = true;
      throw StateError(
        'Refusing card scan read: failed to read $cardScanKeyName.',
      );
    }
    if (stored == null || stored.isEmpty) {
      throw StateError(
        'Refusing card scan read: $cardScanKeyName is not available.',
      );
    }
    final Uint8List decoded;
    try {
      decoded = base64Decode(stored);
    } catch (_) {
      _keyUnreadable = true;
      throw StateError(
        'Refusing card scan read: stored $cardScanKeyName is corrupted.',
      );
    }
    if (decoded.length != 32) {
      _keyUnreadable = true;
      throw StateError(
        'Refusing card scan read: stored $cardScanKeyName is not a 256-bit key.',
      );
    }
    _cachedKeyBytes = decoded;
    return decoded;
  }

  /// Copies [file] into the card's folder. The source is left in place.
  Future<CardScanRef> save({
    required String cardId,
    required String side,
    required File file,
  }) {
    final Completer<CardScanRef> done = Completer<CardScanRef>();
    _saveQueue = _saveQueue.then((_) async {
      try {
        final Uint8List keyBytes = await _getOrCreateKey();
        final Uint8List raw = await file.readAsBytes();
        final Uint8List encrypted = await compute(
          _encryptCardScan,
          _EncryptParams(cleartext: raw, keyBytes: keyBytes),
        );
        final Directory dir = Directory(_joinPath((await _root()).path, cardId));
        if (!await dir.exists()) await dir.create(recursive: true);
        final String fileName = '$side.enc';
        await File(
          _joinPath(dir.path, fileName),
        ).writeAsBytes(encrypted, flush: true);
        done.complete(
          CardScanRef(side: side, fileName: fileName, sizeBytes: raw.length),
        );
      } catch (error, stack) {
        done.completeError(error, stack);
      }
    });
    return done.future;
  }

  Future<Uint8List> read({
    required String cardId,
    required CardScanRef scan,
  }) async {
    final Uint8List keyBytes = await _requireKey();
    final File file = File(
      _joinPath((await _root()).path, cardId, scan.fileName),
    );
    if (!await file.exists()) {
      throw FileSystemException('Card scan file is missing.', file.path);
    }
    return compute(
      _decryptCardScan,
      _DecryptParams(encryptedData: await file.readAsBytes(), keyBytes: keyBytes),
    );
  }

  Future<void> deleteAllFor(String cardId) {
    final Completer<void> done = Completer<void>();
    _saveQueue = _saveQueue.then((_) async {
      try {
        final Directory dir = Directory(_joinPath((await _root()).path, cardId));
        if (await dir.exists()) await dir.delete(recursive: true);
        done.complete();
      } catch (error, stack) {
        done.completeError(error, stack);
      }
    });
    return done.future;
  }

  /// Deletes folders no live or trashed card owns.
  ///
  /// The caller decides whether it is safe to call this. An empty [liveIds]
  /// set deletes every scan on disk.
  Future<void> sweepOrphans(Set<String> liveIds) {
    final Completer<void> done = Completer<void>();
    _saveQueue = _saveQueue.then((_) async {
      try {
        final Directory root = await _root();
        final List<FileSystemEntity> entities = await root.list().toList();
        for (final FileSystemEntity entity in entities) {
          if (entity is! Directory) continue;
          if (!liveIds.contains(_basename(entity.path))) {
            await entity.delete(recursive: true);
          }
        }
        done.complete();
      } catch (error, stack) {
        done.completeError(error, stack);
      }
    });
    return done.future;
  }
}
