import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/passport_profile.dart';
import '../../../core/storage/secure_document_store.dart';

final passportListProvider =
    StateNotifierProvider<PassportListController, List<PassportProfile>>((Ref ref) {
  final controller = PassportListController();
  controller.loadPassports(); // async load
  return controller;
});

class PassportListController extends StateNotifier<List<PassportProfile>> {
  PassportListController() : super([]);

  static const _storageKey = 'saved_passports';
  Future<void> _saveQueue = Future<void>.value();

  Future<void> loadPassports() async {
    final savedData = await SecureDocumentStore.readList(_storageKey);
    state = savedData.map(_tryParse).whereType<PassportProfile>().toList();
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
