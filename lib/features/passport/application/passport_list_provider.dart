import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/passport_profile.dart';

final passportListProvider =
    StateNotifierProvider<PassportListController, List<PassportProfile>>((Ref ref) {
  return PassportListController();
});

class PassportListController extends StateNotifier<List<PassportProfile>> {
  PassportListController()
      : super([
          const PassportProfile(
            name: 'Maya Johnson',
            passportNumber: 'E12345678',
            nationality: 'USA',
            dateOfBirth: '910412', // YYMMDD for BAC
            expiryDate: '310815', // YYMMDD for BAC
            imagePath: '',
            mrzRaw: 'P<USAMAYA<<JOHNSON<<<<<<<<<<<<<<<<<<<<<<\nE12345678USA9104129F3108157<<<<<<<<<<<<<<04',
          ),
        ]);

  void addPassport(PassportProfile profile) {
    state = [...state, profile];
  }

  void updatePassport(int index, PassportProfile profile) {
    final newState = [...state];
    newState[index] = profile;
    state = newState;
  }

  void removePassport(int index) {
    final newState = [...state];
    newState.removeAt(index);
    state = newState;
  }
}
