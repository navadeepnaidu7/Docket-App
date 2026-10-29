import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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
      <String>['Archive category photographs'],
      'Category-cover photography from Pexels.\n'
      'Trains: GOWTHAM AGM — Running Indian Train.\n'
      'https://www.pexels.com/photo/running-indian-train-20309650/\n'
      'Movies: Linda Gschwentner — Number in a Red Seat.\n'
      'https://www.pexels.com/photo/number-in-a-red-seat-11718584/\n'
      'Buses: 虎 曼 — Photo of a Coach on a Road in Perspective.\n'
      'https://www.pexels.com/photo/photo-of-a-coach-on-a-road-in-perspective-16962781/\n\n'
      'Pexels License: https://www.pexels.com/license/\n'
      'Bundled as the downloaded CDN-sized JPEGs. The interface crops the '
      'covers and adds a slight dark-mode veil; stored pixels are unchanged. '
      'The photographers and depicted brands do not endorse Docket.',
    );
    yield const LicenseEntryWithLineBreaks(
      <String>['Summary source app artwork'],
      'Unmodified app artwork identifying the source of passes.\n'
      'BookMyShow — Bigtree Entertainment Pvt. Ltd.\n'
      'https://apps.apple.com/in/app/id405894842\n'
      'District — Zomato / Eternal Limited.\n'
      'https://play.google.com/store/apps/details?id=com.application.zomato.district\n'
      'IRCTC Rail Connect — Indian Railway Catering and Tourism Corporation.\n'
      'https://play.google.com/store/apps/details?id=cris.org.in.prs.ima\n'
      'redBus — redBus / Pilani Soft Labs.\n'
      'https://play.google.com/store/apps/details?id=in.redbus.android\n\n'
      'Artwork and trademarks remain the property of their respective owners. '
      'Their use identifies pass sources and does not imply endorsement.',
    );
    yield const LicenseEntryWithLineBreaks(
      <String>['Animated Noto Emoji (waving hand)'],
      'Waving hand animation by Google, from Animated Noto Emoji.\n'
      'https://googlefonts.github.io/noto-emoji-files/\n'
      'https://fonts.gstatic.com/s/e/notoemoji/latest/1f44b/lottie.json\n'
      'Creative Commons Attribution 4.0 International (CC BY 4.0).\n'
      'https://creativecommons.org/licenses/by/4.0/\n'
      'Modified with a short settling tail: the hand eases to rest and '
      'its motion lines fade out. Playback holds the final resting pose.',
    );
    for (final family in <String>[
      'Inter',
      'RobotoMono',
      'NotoSansDevanagari',
      'Geist',
      'InstrumentSerif',
    ]) {
      yield LicenseEntryWithLineBreaks(<String>[
        'Google Fonts ($family)',
      ], await rootBundle.loadString('assets/fonts/$family-OFL.txt'));
    }
    yield const LicenseEntryWithLineBreaks(
      <String>['Weather data (Open-Meteo)'],
      'Weather data by Open-Meteo (https://open-meteo.com/).\n'
      'Creative Commons Attribution 4.0 International (CC BY 4.0).\n'
      'https://creativecommons.org/licenses/by/4.0/\n\n'
      'Docket rounds temperatures and illustrates weather conditions. '
      'Weather illustrations are original Docket artwork.',
    );
    yield const LicenseEntryWithLineBreaks(
      <String>[
        'Pass category icons (assets/passes/icons)',
        'Interface icons (assets/icons)',
      ],
      'Line icons from Lucide (https://lucide.dev), stroke-width reduced '
      'from 2 to 1.5; geometry unmodified.\n'
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
