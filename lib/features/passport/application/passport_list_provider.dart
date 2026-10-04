import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/document_record_decoder.dart';
import '../domain/passport_profile.dart';
import '../../../core/storage/secure_document_store.dart';

import '../../dashboard/application/wallet_loading_provider.dart';

final passportListProvider =
    StateNotifierProvider<PassportListController, List<PassportProfile>>((
      Ref ref,
    ) {
      final controller = PassportListController(ref);
      controller.loaded = controller.loadPassports();
      return controller;
    });

class PassportListController extends StateNotifier<List<PassportProfile>> {
  PassportListController(this.ref) : super([]);
  final Ref ref;

  static const _storageKey = 'saved_passports';
  Future<void> _saveQueue = Future<void>.value();
  late final Future<void> loaded;
  Future<void>? _loadFuture;
  bool _initialLoadComplete = false;

  Future<void> loadPassports() => _loadFuture ??= _loadPassports().whenComplete(
    () => _initialLoadComplete = true,
  );

  bool _deferDuringLoad(void Function() operation) {
    if (_loadFuture == null || _initialLoadComplete) return false;
    _loadFuture!.then((_) {
      if (mounted) operation();
    });
    return true;
  }

  Future<void> _loadPassports() async {
    final List<String> savedData;
    try {
      savedData = await SecureDocumentStore.readList(_storageKey);
    } catch (_) {
      // The records exist but would not decrypt. Clear the spinner so the shell
      // is usable; the store now refuses writes for this key, so an add made in
      // this session cannot overwrite what is still on disk.
      if (mounted) ref.read(passportLoadingProvider.notifier).state = false;
      return;
    }
    if (!mounted) return;
    final decoded = await decodeStoredRecords(savedData, decodePassportRecords);
    if (!mounted) return;
    if (decoded.hasInvalidRecords) {
      SecureDocumentStore.markUnreadable(_storageKey);
    }
    state = decoded.records;
    ref.read(passportLoadingProvider.notifier).state = false;

    // Records written before the imagePath/photoBase64 split are rewritten once
    // so the heuristic never has to run again. This goes through _queueSave
    // rather than _savePassports directly, or it could clobber a write already
    // in flight from an add that landed while we were loading.
    if (decoded.needsMigration && !decoded.hasInvalidRecords) _queueSave(state);
  }

  Future<void> _savePassports(List<PassportProfile> passports) async {
    final List<String> encodedList = passports.map((p) => p.toJson()).toList();
    await SecureDocumentStore.writeList(_storageKey, encodedList);
  }

  void _queueSave(List<PassportProfile> passports) {
    _saveQueue = _saveQueue
        .then((_) => _savePassports(passports))
        .catchError((_) {});
  }

  void addPassport(PassportProfile profile) {
    if (_deferDuringLoad(() => addPassport(profile))) return;
    // Add to the front so it appears immediately on the dashboard fluidly
    final newState = [profile, ...state];
    state = newState;
    _queueSave(newState);
  }

  /// Removes a passport by its unique [id] — NOT by passport number,
  /// so multiple cards with the same number are never accidentally bulk-deleted.
  void removePassport(String id) {
    if (_deferDuringLoad(() => removePassport(id))) return;
    final newState = state.where((p) => p.id != id).toList();
    state = newState;
    _queueSave(newState);
  }

  void updatePassport(int index, PassportProfile profile) {
    if (_deferDuringLoad(() => updatePassport(index, profile))) return;
    if (index < 0 || index >= state.length) return;
    final newState = [...state];
    newState[index] = profile;
    state = newState;
    _queueSave(newState);
  }
}
