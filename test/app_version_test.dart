import 'dart:io';

import 'package:docket/features/dashboard/presentation/settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// `kAppVersion` is a hand-maintained copy of the pubspec version — the app has
/// no `package_info_plus` dependency, so nothing reads the real one at runtime.
/// A "keep in sync" comment is not a mechanism; this is.
void main() {
  late String pubspecVersion;

  setUpAll(() {
    final RegExp versionLine = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true);
    final Match? match =
        versionLine.firstMatch(File('pubspec.yaml').readAsStringSync());
    expect(match, isNotNull, reason: 'pubspec.yaml has no version: line');
    pubspecVersion = match!.group(1)!;
  });

  test('the Settings version label matches pubspec.yaml', () {
    // pubspec carries `<version>+<build>`; the label shows only the version.
    final String declared = pubspecVersion.split('+').first;
    expect(
      kAppVersion,
      declared,
      reason: 'kAppVersion ($kAppVersion) has drifted from pubspec.yaml '
          '($declared). Update lib/features/dashboard/presentation/'
          'settings_screen.dart.',
    );
  });

  test('the pubspec version carries a build number', () {
    // Without `+<build>` the Android Gradle plugin has no versionCode to use.
    expect(
      pubspecVersion,
      contains('+'),
      reason: 'version: needs a +<build> suffix for versionCode',
    );
    expect(int.tryParse(pubspecVersion.split('+').last), isNotNull);
  });
}
