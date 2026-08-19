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
      <String>['Pass category icons (assets/passes/icons)'],
      'Line icons from Lucide (https://lucide.dev), bundled unmodified.\n'
      '\n'
      'Copyright (c) for portions of Lucide are held by Cole Bemis 2013-2022 '
      'as part of Feather (MIT). All other copyright (c) for Lucide are held '
      'by Lucide Contributors 2022.\n'
      '\n'
      'ISC License\n'
      '\n'
      'Permission to use, copy, modify, and/or distribute this software for '
      'any purpose with or without fee is hereby granted, provided that the '
      'above copyright notice and this permission notice appear in all '
      'copies.\n'
      '\n'
      'THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL '
      'WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED '
      'WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE '
      'AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL '
      'DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR '
      'PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER '
      'TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR '
      'PERFORMANCE OF THIS SOFTWARE.',
    );
    yield const LicenseEntryWithLineBreaks(
      <String>['Journey globe geometry (assets/journey)'],
      'Derived from Natural Earth (https://www.naturalearthdata.com/), which '
      'is in the public domain and requires neither permission nor '
      'attribution. Credited voluntarily.\n'
      '\n'
      'Heavily modified: land polygons were used only to decide which points '
      'of a sphere fall on land and were then discarded, so what ships is a '
      'point field rather than a coastline. India state boundary lines were '
      'filtered from the global set, simplified, and quantised to 16-bit.\n'
      '\n'
      'Place coordinates in places_v1.json are separately sourced and '
      'hand-curated for this app; they are not Natural Earth data.',
    );
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
