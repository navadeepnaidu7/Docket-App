import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/passport_profile.dart';
import '../../../core/storage/secure_document_store.dart';

import '../../dashboard/application/wallet_loading_provider.dart';

final passportListProvider =
    StateNotifierProvider<PassportListController, List<PassportProfile>>((
      Ref ref,
    ) {
      final controller = PassportListController(ref);
      controller.loadPassports(); // async load
      return controller;
    });

class PassportListController extends StateNotifier<List<PassportProfile>> {
  PassportListController(this.ref) : super([]);
  final Ref ref;

  static const _storageKey = 'saved_passports';
  Future<void> _saveQueue = Future<void>.value();

  Future<void> loadPassports() async {
    final List<String> savedData;
    try {
      savedData = await SecureDocumentStore.readList(_storageKey);
    } catch (_) {
      // The records exist but would not decrypt. Clear the spinner so the shell
      // is usable; the store now refuses writes for this key, so an add made in
      // this session cannot overwrite what is still on disk.
      ref.read(passportLoadingProvider.notifier).state = false;
      return;
    }

    bool migrated = false;
    final List<PassportProfile> loaded = <PassportProfile>[];
    for (final String source in savedData) {
      final PassportProfile? profile = _tryParse(source);
      if (profile == null) continue;
      if (_sourceNeedsMigration(source)) migrated = true;
      loaded.add(profile);
    }

    state = loaded;
    ref.read(passportLoadingProvider.notifier).state = false;

    // Records written before the imagePath/photoBase64 split are rewritten once
    // so the heuristic never has to run again. This goes through _queueSave
    // rather than _savePassports directly, or it could clobber a write already
    // in flight from an add that landed while we were loading.
    if (migrated) _queueSave(loaded);
  }

  bool _sourceNeedsMigration(String source) {
    try {
      final decoded = jsonDecode(source);
      return decoded is Map<String, dynamic> &&
          PassportProfile.mapNeedsMigration(decoded);
    } catch (_) {
      return false;
    }
  }

  Future<void> _savePassports(List<PassportProfile> passports) async {
    final List<String> encodedList = passports.map((p) => p.toJson()).toList();
    await SecureDocumentStore.writeList(_storageKey, encodedList);
  }

  void _queueSave(List<PassportProfile> passports) {
    _saveQueue = _saveQueue.then((_) => _savePassports(passports));
  }

  void addPassport(PassportProfile profile) {
    // Add to the front so it appears immediately on the dashboard fluidly
    final newState = [profile, ...state];
    state = newState;
    _queueSave(newState);
  }

  /// Removes a passport by its unique [id] — NOT by passport number,
  /// so multiple cards with the same number are never accidentally bulk-deleted.
  void removePassport(String id) {
    final newState = state.where((p) => p.id != id).toList();
    state = newState;
    _queueSave(newState);
  }

  void updatePassport(int index, PassportProfile profile) {
    if (index < 0 || index >= state.length) return;
    final newState = [...state];
    newState[index] = profile;
    state = newState;
    _queueSave(newState);
  }

  PassportProfile? _tryParse(String source) {
    try {
      return PassportProfile.fromJson(source);
    } catch (_) {
      return null;
    }
  }
}
