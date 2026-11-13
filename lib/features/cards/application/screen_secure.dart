import 'dart:io';

import 'package:flutter/services.dart';

/// Blocks screenshots while a card number, CVV, or scan photo is on screen.
///
/// Android uses `FLAG_SECURE`. Other platforms have no equivalent flag, so
/// the call is a no-op there. Calls nest: the flag stays up until every
/// reveal has hidden itself.
class ScreenSecure {
  ScreenSecure._();

  static const MethodChannel _channel = MethodChannel(
    'com.docket/screen_secure',
  );
  static int _depth = 0;

  static Future<void> acquire() async {
    _depth += 1;
    if (_depth == 1) await _set(true);
  }

  static Future<void> release() async {
    if (_depth == 0) return;
    _depth -= 1;
    if (_depth == 0) await _set(false);
  }

  static Future<void> _set(bool enabled) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setSecure', <String, bool>{
        'enabled': enabled,
      });
    } catch (_) {}
  }

  static void resetForTest() {
    _depth = 0;
  }
}
