import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/pass_catalog.dart';
import '../domain/pass_ingest.dart';
import '../domain/pnr_format.dart';
import 'pass_ingest_service.dart';

const Duration kPassIngestMinimumVisibleDuration = Duration(milliseconds: 700);

sealed class PassIngestRequest {
  const PassIngestRequest();

  PassInputCategory get category;
}

final class PnrPassIngestRequest extends PassIngestRequest {
  const PnrPassIngestRequest(this.pnr);

  final String pnr;

  @override
  PassInputCategory get category => PassInputCategory.train;
}

final class FilePassIngestRequest extends PassIngestRequest {
  const FilePassIngestRequest({required this.path, required this.category});

  /// Retain the path, not the file bytes, while an inline retry is available.
  final String path;

  @override
  final PassInputCategory category;
}

sealed class PassIngestUiState {
  const PassIngestUiState();

  bool get isRunning => this is PassIngestRunning;
  bool get isIdle => this is PassIngestIdle;
}

final class PassIngestIdle extends PassIngestUiState {
  const PassIngestIdle();
}

final class PassIngestRunning extends PassIngestUiState {
  const PassIngestRunning({required this.request, required this.phase});

  final PassIngestRequest request;
  final PassIngestPhase phase;

  PassIngestRunning copyWith({PassIngestPhase? phase}) =>
      PassIngestRunning(request: request, phase: phase ?? this.phase);
}

final class PassIngestSucceeded extends PassIngestUiState {
  const PassIngestSucceeded({required this.request, required this.item});

  final PassIngestRequest request;
  final WalletPassItem item;
}

final class PassIngestFailed extends PassIngestUiState {
  const PassIngestFailed({required this.request, required this.error});

  final PassIngestRequest request;
  final PassIngestException error;
}

final passIngestControllerProvider =
    NotifierProvider<PassIngestController, PassIngestUiState>(
      PassIngestController.new,
    );

class PassIngestController extends Notifier<PassIngestUiState> {
  @override
  PassIngestUiState build() => const PassIngestIdle();

  bool startPnr(String raw) {
    final String pnr = PnrFormat.normalize(raw);
    if (!PnrFormat.isValid(pnr) || !state.isIdle) return false;
    _start(PnrPassIngestRequest(pnr));
    return true;
  }

  bool startFile({required String path, required PassInputCategory category}) {
    if (path.trim().isEmpty || !state.isIdle) return false;
    _start(FilePassIngestRequest(path: path, category: category));
    return true;
  }

  void retry() {
    final PassIngestUiState current = state;
    if (current is! PassIngestFailed) return;
    _start(current.request);
  }

  void dismiss() {
    if (state is PassIngestRunning) return;
    state = const PassIngestIdle();
  }

  void finishSuccess() {
    if (state is PassIngestSucceeded) state = const PassIngestIdle();
  }

  void _start(PassIngestRequest request) {
    final PassIngestPhase initial = request is FilePassIngestRequest
        ? PassIngestPhase.readingSource
        : PassIngestPhase.submitting;
    state = PassIngestRunning(request: request, phase: initial);
    unawaited(_run(request));
  }

  Future<void> _run(PassIngestRequest request) async {
    final Stopwatch visibleFor = Stopwatch()..start();
    try {
      final PassIngestService service = ref.read(passIngestServiceProvider);
      void onPhase(PassIngestPhase phase) {
        final PassIngestUiState current = state;
        if (current is PassIngestRunning &&
            identical(current.request, request)) {
          state = current.copyWith(phase: phase);
        }
      }

      final WalletPassItem item = switch (request) {
        PnrPassIngestRequest(:final pnr) => await service.submitPnr(
          pnr,
          onPhase: onPhase,
        ),
        FilePassIngestRequest(:final path, :final category) =>
          await service.submitFile(
            file: File(path),
            category: category,
            onPhase: onPhase,
          ),
      };

      final Duration remaining =
          kPassIngestMinimumVisibleDuration - visibleFor.elapsed;
      if (remaining > Duration.zero) await Future<void>.delayed(remaining);
      state = PassIngestSucceeded(request: request, item: item);
    } on PassIngestException catch (error) {
      state = PassIngestFailed(request: request, error: error);
    } catch (_) {
      state = PassIngestFailed(
        request: request,
        error: const PassIngestException(
          PassIngestCode.failed,
          'Could not add that pass.',
        ),
      );
    }
  }
}
