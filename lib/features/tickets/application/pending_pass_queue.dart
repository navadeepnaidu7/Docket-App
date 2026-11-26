import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/storage/secure_document_store.dart';
import '../data/network_failure.dart';
import '../domain/pass_ingest.dart';
import 'pass_ingest_service.dart';
import 'pass_list_provider.dart';

/// A pass the user added while the server was unreachable.
@immutable
class PendingPass {
  const PendingPass({
    required this.id,
    required this.category,
    required this.createdAt,
    this.pnr,
    this.filePath,
    this.error,
  });

  factory PendingPass.fromJson(Map<String, dynamic> json) => PendingPass(
    id: json['id'] as String,
    category: PassInputCategory.values.byName(json['category'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    pnr: json['pnr'] as String?,
    filePath: json['filePath'] as String?,
    error: json['error'] as String?,
  );

  final String id;
  final PassInputCategory category;
  final DateTime createdAt;
  final String? pnr;

  /// App-private copy, deleted once uploaded or dismissed.
  final String? filePath;

  /// Set when the server refused it; the item then waits for a dismissal.
  final String? error;

  bool get failed => error != null;

  PendingPass withError(String message) => PendingPass(
    id: id,
    category: category,
    createdAt: createdAt,
    pnr: pnr,
    filePath: filePath,
    error: message,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'category': category.name,
    'createdAt': createdAt.toIso8601String(),
    'pnr': pnr,
    'filePath': filePath,
    'error': error,
  };
}

final pendingPassQueueProvider =
    NotifierProvider<PendingPassQueue, List<PendingPass>>(PendingPassQueue.new);

/// Uploads queued additions in order once the server is reachable again.
/// See docs/features/offline-passes.md.
class PendingPassQueue extends Notifier<List<PendingPass>> {
  static const String _prefix = 'docket.passes.pending.v1.';
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: kDocketAndroidOptions,
  );
  static const Duration _retryEvery = Duration(seconds: 30);

  String? _scope;
  Timer? _retry;
  bool _draining = false;
  bool _restored = false;

  /// True while an upload is in flight.
  bool get draining => _draining;

  @override
  List<PendingPass> build() {
    _scope = ref.watch(passOfflineScopeProvider);
    _restored = false;
    final AppLifecycleListener lifecycle = AppLifecycleListener(
      onResume: () {
        if (ref.read(passSyncStatusProvider).offline) {
          // A successful sync drains the queue through the listener below.
          unawaited(ref.read(passListProvider.notifier).refresh());
        } else {
          unawaited(drain());
        }
      },
    );
    ref.onDispose(() {
      lifecycle.dispose();
      _retry?.cancel();
    });
    ref.listen<PassSyncStatus>(passSyncStatusProvider, (previous, next) {
      if (!next.offline && next.lastSyncedAt != previous?.lastSyncedAt) {
        unawaited(drain());
      }
    });
    final String? scope = _scope;
    if (scope != null) unawaited(_restore(scope));
    return const <PendingPass>[];
  }

  Future<void> _restore(String scope) async {
    try {
      final String? raw = await _storage.read(key: '$_prefix$scope');
      if (scope != _scope) return;
      if (raw != null && raw.isNotEmpty) {
        state = <PendingPass>[
          for (final Object? item in jsonDecode(raw) as List)
            PendingPass.fromJson(Map<String, dynamic>.from(item as Map)),
          ...state,
        ];
      }
    } catch (_) {
      // An unreadable index is left alone; new additions still queue.
    }
    _restored = true;
    unawaited(drain());
  }

  /// False when this wallet has nowhere to queue (mock or signed out).
  bool get canQueue => _scope != null;

  Future<bool> enqueuePnr(String pnr) => _enqueue(
    PendingPass(
      id: _newId(),
      category: PassInputCategory.train,
      createdAt: DateTime.now(),
      pnr: pnr,
    ),
  );

  Future<bool> enqueueFile({
    required String path,
    required PassInputCategory category,
  }) async {
    if (!canQueue) return false;
    final String id = _newId();
    final Directory dir = await _filesDir();
    final String name = path.split(RegExp(r'[\\/]')).last;
    final String copy = '${dir.path}${Platform.pathSeparator}${id}_$name';
    await File(path).copy(copy);
    return _enqueue(
      PendingPass(
        id: id,
        category: category,
        createdAt: DateTime.now(),
        filePath: copy,
      ),
    );
  }

  Future<bool> _enqueue(PendingPass item) async {
    if (!canQueue) return false;
    state = <PendingPass>[...state, item];
    await _persist();
    _scheduleRetry();
    return true;
  }

  /// Removes a refused item and its file.
  Future<void> dismiss(String id) async {
    final PendingPass? item = state.where((p) => p.id == id).firstOrNull;
    if (item == null) return;
    state = state.where((p) => p.id != id).toList(growable: false);
    await _deleteFile(item);
    await _persist();
  }

  /// Uploads waiting items one at a time, oldest first.
  Future<void> drain() async {
    if (_draining || !_restored || _scope == null) return;
    _draining = true;
    // Rebuild listeners so the tab can show progress.
    state = List<PendingPass>.of(state);
    try {
      final PassIngestService service = ref.read(passIngestServiceProvider);
      for (final PendingPass item in List<PendingPass>.of(state)) {
        if (item.failed) continue;
        try {
          if (item.pnr != null) {
            await service.submitPnr(item.pnr!);
          } else if (item.filePath != null) {
            await service.submitFile(
              file: File(item.filePath!),
              category: item.category,
            );
          }
          state = state.where((p) => p.id != item.id).toList(growable: false);
          await _deleteFile(item);
        } catch (error) {
          if (isNetworkFailure(error)) {
            _scheduleRetry();
            break;
          }
          state = <PendingPass>[
            for (final PendingPass p in state)
              p.id == item.id
                  ? p.withError(
                      error is PassIngestException
                          ? error.message
                          : 'Could not add that pass.',
                    )
                  : p,
          ];
        }
        await _persist();
      }
    } finally {
      _draining = false;
      state = List<PendingPass>.of(state);
    }
  }

  /// Deletes every account's queue and files. Used on sign-out.
  Future<void> clearAll() async {
    _retry?.cancel();
    state = const <PendingPass>[];
    try {
      final Map<String, String> all = await _storage.readAll();
      for (final String key in all.keys) {
        if (key.startsWith(_prefix)) await _storage.delete(key: key);
      }
      final Directory dir = await _filesDir();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  void _scheduleRetry() {
    _retry?.cancel();
    if (!state.any((p) => !p.failed)) return;
    _retry = Timer(_retryEvery, () => unawaited(drain()));
  }

  Future<void> _persist() async {
    final String? scope = _scope;
    if (scope == null) return;
    try {
      if (state.isEmpty) {
        await _storage.delete(key: '$_prefix$scope');
      } else {
        await _storage.write(
          key: '$_prefix$scope',
          value: jsonEncode(<Map<String, dynamic>>[
            for (final PendingPass p in state) p.toJson(),
          ]),
        );
      }
    } catch (_) {}
  }

  Future<void> _deleteFile(PendingPass item) async {
    final String? path = item.filePath;
    if (path == null) return;
    try {
      await File(path).delete();
    } catch (_) {}
  }

  static Future<Directory> _filesDir() async {
    final Directory base = await getApplicationSupportDirectory();
    final Directory dir = Directory(
      '${base.path}${Platform.pathSeparator}pending_passes',
    );
    await dir.create(recursive: true);
    return dir;
  }

  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(1 << 20)}';
}
