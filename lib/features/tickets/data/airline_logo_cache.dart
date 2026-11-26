import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../../core/dev/dev_config.dart';
import '../domain/airline_brands.dart';

/// Airline logos, fetched from the backend once and kept on the device.
///
/// The app ships no airline artwork: a few dozen logos would add most of a
/// megabyte for carriers a given user never flies. The server serves each
/// as a small SVG at `/img/airline/{code}.svg`; the first pass for an airline
/// downloads it, and after that it comes from disk, refreshed in the
/// background when the server's cache lifetime runs out. Until then, and
/// offline on first sight, the face prints the airline's name.
abstract final class AirlineLogos {
  /// Replaces the network in tests and previews.
  static Future<Uint8List?> Function(String code)? debugLoader;

  /// Forgets every logo held in memory, so a test's [debugLoader] is asked
  /// afresh rather than an earlier test's answer being reused.
  @visibleForTesting
  static void debugReset() {
    _settled.clear();
    _pending.clear();
    _failedAt.clear();
  }

  static final CacheManager _disk = CacheManager(
    Config(
      'airlineLogos',
      stalePeriod: const Duration(days: 90),
      maxNrOfCacheObjects: 120,
    ),
  );

  /// Settled lookups. A null value means the server has no logo for the
  /// code; a network failure is not recorded here, so it is retried.
  static final Map<String, Uint8List?> _settled = <String, Uint8List?>{};
  static final Map<String, Future<Uint8List?>> _pending =
      <String, Future<Uint8List?>>{};
  static final Map<String, DateTime> _failedAt = <String, DateTime>{};

  /// Logos are public artwork, so they always come from the deployed
  /// backend, whichever server the Developer settings point passes at.
  static String url(String code) =>
      '${DevConfig.defaultApiBaseUrl}/img/airline/$code.svg';

  /// The logo if it is already in memory, for a first frame without a flash.
  static Uint8List? peek(String code) => _settled[_key(code)];

  static Future<Uint8List?> load(String code) {
    final String key = _key(code);
    if (_settled.containsKey(key)) {
      return SynchronousFuture<Uint8List?>(_settled[key]);
    }
    final DateTime? failed = _failedAt[key];
    if (failed != null &&
        DateTime.now().difference(failed) < const Duration(minutes: 1)) {
      return SynchronousFuture<Uint8List?>(null);
    }
    return _pending[key] ??= _fetch(key)
        .then((Uint8List? bytes) {
          _settled[key] = bytes;
          return bytes;
        })
        .catchError((Object _) {
          _failedAt[key] = DateTime.now();
          return null;
        })
        // A block body on purpose: `=> _pending.remove(key)` would return
        // this very future, and whenComplete would wait on it forever.
        .whenComplete(() {
          _pending.remove(key);
        });
  }

  /// Reads the logos already on disk into memory, so the wallet's first
  /// frame draws them instead of the name, and starts downloading the rest
  /// without waiting for them.
  static Future<void> warm(Iterable<String> codes) async {
    final List<Future<void>> reads = <Future<void>>[];
    for (final String code in codes.map(_key).toSet()) {
      if (_settled.containsKey(code) || AirlineBrand.of(code) == null) {
        continue;
      }
      if (debugLoader != null || _inTest) {
        unawaited(load(code));
        continue;
      }
      reads.add(
        _disk.getFileFromCache(url(code)).then((FileInfo? hit) async {
          if (hit == null) {
            unawaited(load(code));
            return;
          }
          final Uint8List bytes = await hit.file.readAsBytes();
          if (_isSvg(bytes)) _settled[code] = bytes;
          // A stale copy still draws; load() refreshes it in the background.
          if (hit.validTill.isBefore(DateTime.now())) unawaited(_refresh(code));
        }, onError: (Object _) => unawaited(load(code))),
      );
    }
    await Future.wait(reads);
  }

  static Future<void> _refresh(String code) async {
    try {
      final File file = await _disk.downloadFile(url(code)).then((f) => f.file);
      final Uint8List bytes = await file.readAsBytes();
      if (_isSvg(bytes)) _settled[code] = bytes;
    } catch (_) {
      // Keep the stale copy.
    }
  }

  static bool get _inTest =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  static String _key(String code) => code.trim().toUpperCase();

  static Future<Uint8List?> _fetch(String code) async {
    // Only airlines in the table have a logo on the server; asking for any
    // other code is a guaranteed 404.
    if (AirlineBrand.of(code) == null) return null;
    final loader = debugLoader;
    if (loader != null) return loader(code);
    // Widget tests have neither a network nor a cache directory.
    if (_inTest) return null;
    try {
      // Returns the disk copy when there is one, even a stale one, and
      // refreshes it in the background.
      final File file = await _disk.getSingleFile(url(code));
      final Uint8List bytes = await file.readAsBytes();
      return _isSvg(bytes) ? bytes : null;
    } on HttpExceptionWithStatus catch (e) {
      if (e.statusCode == HttpStatus.notFound) return null;
      rethrow;
    }
  }

  static bool _isSvg(Uint8List bytes) {
    final int n = math.min(bytes.length, 512);
    return String.fromCharCodes(bytes.sublist(0, n)).contains('<svg');
  }

  /// Width over height from the logo's viewBox, or null if it has none.
  static double? aspectOf(Uint8List bytes) {
    final int n = math.min(bytes.length, 1024);
    final Match? m = RegExp(
      r'viewBox="\s*[-\d.]+[\s,]+[-\d.]+[\s,]+([\d.]+)[\s,]+([\d.]+)',
    ).firstMatch(String.fromCharCodes(bytes.sublist(0, n)));
    if (m == null) return null;
    final double w = double.tryParse(m.group(1)!) ?? 0;
    final double h = double.tryParse(m.group(2)!) ?? 0;
    return w > 0 && h > 0 ? w / h : null;
  }
}
