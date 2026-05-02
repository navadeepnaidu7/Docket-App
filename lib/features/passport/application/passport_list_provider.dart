import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/passport_profile.dart';

final passportListProvider =
    StateNotifierProvider<PassportListController, List<PassportProfile>>((Ref ref) {
  final controller = PassportListController();
  controller.loadPassports(); // async load
  return controller;
});

class PassportListController extends StateNotifier<List<PassportProfile>> {
  PassportListController() : super([]);

  static const _storageKey = 'saved_passports';

  Future<void> loadPassports() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? savedData = prefs.getStringList(_storageKey);
    
    if (savedData != null && savedData.isNotEmpty) {
      state = savedData.map((str) => PassportProfile.fromJson(str)).toList();
    } else {
      // Load default demo profile if completely empty
      state = [
        const PassportProfile(
          name: 'Maya Johnson',
          passportNumber: 'E12345678',
          nationality: 'USA',
          dateOfBirth: '910412', // YYMMDD for BAC
          expiryDate: '310815', // YYMMDD for BAC
          imagePath: '',
          mrzRaw: 'P<USAMAYA<<JOHNSON<<<<<<<<<<<<<<<<<<<<<<\nE12345678USA9104129F3108157<<<<<<<<<<<<<<04',
        )
      ];
    }
  }

  Future<void> _savePassports(List<PassportProfile> passports) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> encodedList = passports.map((p) => p.toJson()).toList();
    await prefs.setStringList(_storageKey, encodedList);
  }

  void addPassport(PassportProfile profile) {
    final newState = [...state, profile];
    state = newState;
    _savePassports(newState);
  }

  void removePassport(String passportNumber) {
    final newState = state.where((p) => p.passportNumber != passportNumber).toList();
    state = newState;
    _savePassports(newState);
  }

  void updatePassport(int index, PassportProfile profile) {
    final newState = [...state];
    newState[index] = profile;
    state = newState;
    _savePassports(newState);
  }
}
