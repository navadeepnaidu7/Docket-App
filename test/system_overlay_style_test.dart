import 'package:docket/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('system overlay leaves the nav bar transparent', () {
    final SystemUiOverlayStyle light = AppTheme.systemOverlayStyleFor(
      brightness: Brightness.light,
    );
    expect(light.statusBarColor, Colors.transparent);
    expect(light.systemNavigationBarColor, Colors.transparent);
    expect(light.systemNavigationBarDividerColor, Colors.transparent);
    expect(light.systemNavigationBarContrastEnforced, isFalse);
    expect(light.systemStatusBarContrastEnforced, isFalse);
    expect(light.statusBarIconBrightness, Brightness.dark);
    expect(light.systemNavigationBarIconBrightness, Brightness.dark);

    final SystemUiOverlayStyle dark = AppTheme.systemOverlayStyleFor(
      brightness: Brightness.dark,
    );
    expect(dark.systemNavigationBarColor, Colors.transparent);
    expect(dark.statusBarIconBrightness, Brightness.light);
    expect(dark.systemNavigationBarIconBrightness, Brightness.light);
  });

  test('AppBar theme does not paint a separate system nav color', () {
    expect(
      AppTheme
          .lightTheme
          .appBarTheme
          .systemOverlayStyle
          ?.systemNavigationBarColor,
      Colors.transparent,
    );
    expect(
      AppTheme
          .darkTheme
          .appBarTheme
          .systemOverlayStyle
          ?.systemNavigationBarColor,
      Colors.transparent,
    );
    expect(
      AppTheme
          .lightTheme
          .appBarTheme
          .systemOverlayStyle
          ?.systemNavigationBarContrastEnforced,
      isFalse,
    );
  });
}
