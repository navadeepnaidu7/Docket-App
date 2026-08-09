import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Semantic haptic feedback — one pulse per user action.
class HapticService {
  HapticService._();

  static bool enabled = true;

  static Future<void> _fire(Future<void> Function() action) async {
    if (!enabled) return;
    try {
      await action();
    } on PlatformException catch (_) {
      // Haptics are decorative. Nearly every call site fires and forgets, so a
      // device that cannot vibrate would otherwise raise unhandled async
      // errors from all over the app. Swallow it here, once, rather than
      // making 80-odd callers each guard the same non-event.
    } on MissingPluginException catch (_) {
      // Same reasoning for hosts with no platform channel, such as tests.
    }
  }

  /// Button press — use on touch down.
  static Future<void> tap() => _fire(() => HapticFeedback.lightImpact());

  /// Tabs, filters, toggles, segmented controls.
  static Future<void> select() => _fire(() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await HapticFeedback.selectionClick();
    } else {
      await HapticFeedback.lightImpact();
    }
  });

  /// Sheet opens and light navigational confirms.
  static Future<void> confirm() => _fire(() => HapticFeedback.lightImpact());

  /// Shutter, meaningful taps without being destructive.
  static Future<void> impact() => _fire(() => HapticFeedback.mediumImpact());

  /// Card flip — crisp double pulse.
  static Future<void> flip() => _fire(() async {
    await HapticFeedback.lightImpact();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.lightImpact();
  });

  /// Save, verify, scan success.
  static Future<void> success() => _fire(() async {
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.lightImpact();
  });

  /// Delete dialogs and destructive confirms.
  static Future<void> destructive() => _fire(() => HapticFeedback.heavyImpact());

  /// Failures — scan error, NFC read error.
  static Future<void> error() => _fire(() => HapticFeedback.mediumImpact());

  /// Long-press triggers (delete mode, etc.).
  static Future<void> longPress() => _fire(() => HapticFeedback.heavyImpact());

  /// List reorder drop.
  static Future<void> reorder() => _fire(() => HapticFeedback.lightImpact());
}