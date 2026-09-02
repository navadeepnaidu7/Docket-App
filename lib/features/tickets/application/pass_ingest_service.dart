import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dev/dev_flags.dart';
import '../../../core/dev/dev_flags_provider.dart';
import '../data/api_session_store.dart';
import '../data/docket_api_client.dart';
import '../domain/pass_catalog.dart';
import '../domain/pass_ingest.dart';
import '../domain/pnr_format.dart';
import 'pass_list_provider.dart';

final apiSessionStoreProvider = Provider<ApiSessionStore>((Ref ref) {
  return ApiSessionStore();
});

final docketApiProvider = Provider<DocketApi?>((Ref ref) {
  final DevFlags flags = ref.watch(devFlagsProvider);
  final String base = flags.apiBaseUrl.trim();
  if (base.isEmpty) return null;
  return DocketApiClient(
    baseUrl: base,
    session: ref.watch(apiSessionStoreProvider),
    devIdToken: flags.devAuthIdToken.trim().isNotEmpty
        ? flags.devAuthIdToken.trim()
        : '',
  );
});

final passIngestServiceProvider = Provider<PassIngestService>((Ref ref) {
  return PassIngestService(ref);
});

class PassIngestService {
  PassIngestService(this._ref);

  final Ref _ref;

  static const Duration _ingestTimeout = Duration(seconds: 60);

  DocketApi _requireApi() {
    final DevFlags flags = _ref.read(devFlagsProvider);
    if (flags.isMockPassesActive) {
      throw const PassIngestException(
        PassIngestCode.needsRemote,
        'Turn off mock passes and set an API URL under Settings → Developer to add a real ticket.',
      );
    }
    final DocketApi? api = _ref.read(docketApiProvider);
    if (api == null) {
      throw const PassIngestException(
        PassIngestCode.needsRemote,
        'Set an API URL under Settings → Developer first.',
      );
    }
    return api;
  }

  Future<WalletPassItem> submitPnr(String raw) async {
    final String pnr = PnrFormat.normalize(raw);
    if (!PnrFormat.isValid(pnr)) {
      throw const PassIngestException(
        PassIngestCode.invalidPnr,
        'A PNR is exactly 10 digits.',
      );
    }
    final DocketApi api = _requireApi();
    try {
      final String id = await api.createFromPnr(pnr).timeout(_ingestTimeout);
      return _resolve(api, id);
    } on TimeoutException {
      throw const PassIngestException(
        PassIngestCode.failed,
        'The request timed out. Check your connection and try again.',
      );
    }
  }

  Future<WalletPassItem> submitFile({
    required File file,
    required PassInputCategory category,
  }) async {
    final String path = file.path;
    final String? mime = PassUpload.mimeForPath(path);
    if (mime == null) {
      throw const PassIngestException(
        PassIngestCode.unsupportedFile,
        'Use a JPG, PNG, WebP, or PDF.',
      );
    }
    final int length = await file.length();
    if (length > kExtractMaxUploadBytes) {
      throw const PassIngestException(
        PassIngestCode.fileTooLarge,
        'That file is larger than the 12 MB upload limit.',
      );
    }
    final Uint8List bytes = await file.readAsBytes();
    final String filename = path.split(RegExp(r'[\\/]')).last;
    final DocketApi api = _requireApi();
    try {
      final String id = await api.extractFile(
        bytes: bytes,
        filename: filename.isEmpty ? 'ticket' : filename,
        mimeType: mime,
        categoryHint: category.hint,
      ).timeout(_ingestTimeout);
      return _resolve(api, id);
    } on TimeoutException {
      throw const PassIngestException(
        PassIngestCode.failed,
        'The request timed out. Check your connection and try again.',
      );
    }
  }

  Future<WalletPassItem> _resolve(DocketApi api, String id) async {
    final WalletPassItem? item = await api.fetchPassById(id);
    await _ref.read(passListProvider.notifier).refresh();
    if (item == null) {
      throw const PassIngestException(
        PassIngestCode.unreadable,
        'Saved, but this pass kind is not on the wallet yet.',
      );
    }
    _backfillPoster(api, item);
    return item;
  }

  /// Re-reads a freshly added movie pass until its poster arrives.
  ///
  /// `POST /tickets/extract` returns as soon as the ticket is stored and enqueues the TMDB
  /// lookup for the worker to run, so a movie pass is almost always saved *before* its art
  /// exists. Nothing else would ever re-read it: there is no pull-to-refresh on the passes
  /// tab, so without this the pass keeps its gradient fallback until the app is restarted.
  ///
  /// Fire-and-forget on purpose — the add flow must not wait on artwork, and the pass is
  /// already saved and on screen by the time this runs.
  void _backfillPoster(DocketApi api, WalletPassItem item) {
    if (item is! MoviePassItem || item.pass.resolvedPosterUrl != null) return;

    unawaited(() async {
      for (final Duration wait in _posterBackfillDelays) {
        await Future<void>.delayed(wait);
        try {
          final WalletPassItem? fresh = await api.fetchPassById(item.id);
          if (fresh is MoviePassItem && fresh.pass.resolvedPosterUrl != null) {
            await _ref.read(passListProvider.notifier).refresh();
            return;
          }
        } catch (_) {
          // The pass itself is saved; a failed poll is not worth a second error dialog.
          // This also catches reads against a torn-down ProviderScope on app exit.
          return;
        }
      }
    }());
  }

  /// Bounded, and front-loaded because the worker usually resolves within a second or two —
  /// the later probes only exist for a cold or backed-up queue.
  ///
  /// It gives up rather than retrying forever because **no poster is a legitimate final
  /// answer**: TMDB may not carry the film, or the match may have scored below the server's
  /// threshold, which deliberately emits nothing rather than another film's artwork.
  static const List<Duration> _posterBackfillDelays = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
  ];
}
