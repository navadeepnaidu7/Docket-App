import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/passport_profile.dart';

final passportDraftProvider =
    StateNotifierProvider<PassportDraftController, PassportProfile>((Ref ref) {
      return PassportDraftController();
    });

class PassportDraftController extends StateNotifier<PassportProfile> {
  PassportDraftController() : super(PassportProfile.empty());

  void updateName(String value) => state = state.copyWith(name: value);

  void updatePassportNumber(String value) =>
      state = state.copyWith(passportNumber: value);

  void updateNationality(String value) =>
      state = state.copyWith(nationality: value);

  void updateDateOfBirth(String value) =>
      state = state.copyWith(dateOfBirth: value);

  void updateExpiryDate(String value) =>
      state = state.copyWith(expiryDate: value);

  void updateImagePath(String value) =>
      state = state.copyWith(imagePath: value);

  void updateMrzRaw(String value) => state = state.copyWith(mrzRaw: value);

  void updateIsEPassport(bool value) =>
      state = state.copyWith(isEPassport: value);

  void replaceWith(PassportProfile profile) => state = profile;

  void reset() => state = PassportProfile.empty();
}
