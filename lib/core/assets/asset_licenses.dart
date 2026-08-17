import 'package:flutter/foundation.dart';

/// Registers licence text for bundled third-party *assets*.
///
/// Flutter collects licences for Dart packages automatically, but nothing walks
/// `assets/`. The passport cover artwork is CC BY-SA 4.0, which obliges us to
/// carry attribution with the distributed work — a line in ATTRIBUTIONS.md
/// covers the repo, not the installed APK. Registering here puts the same credit
/// behind Settings -> About -> Licences.
///
/// [LicenseRegistry.addLicense] only stores the collector; the stream is not
/// walked until a licence page is actually built, so this costs nothing at
/// startup.
void registerAssetLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      <String>['Passport cover artwork (assets/wallet/passport/covers)'],
      'Indian passport cover illustrations, bundled unmodified.\n'
      '\n'
      'passport_regular.svg\n'
      '  "Indian Passport.svg" by Swapnil1101\n'
      '  https://commons.wikimedia.org/wiki/File:Indian_Passport.svg\n'
      '\n'
      'passport_epassport.svg\n'
      '  "Indian Passport (e-Passport, 2024).svg" by FireDragonValo\n'
      '  https://commons.wikimedia.org/wiki/File:Indian_Passport_(e-Passport,_2024).svg\n'
      '\n'
      'Both licensed under the Creative Commons Attribution-ShareAlike 4.0 '
      'International licence (CC BY-SA 4.0).\n'
      'https://creativecommons.org/licenses/by-sa/4.0/\n'
      '\n'
      'You are free to share and adapt these works for any purpose, even '
      'commercially, provided you give appropriate credit, indicate if changes '
      'were made, and distribute any adaptation under the same licence. No '
      'changes were made to either file.',
    );
  });
}
