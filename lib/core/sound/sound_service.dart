import 'package:flutter/services.dart';

/// Thin wrapper that plays platform UI sounds alongside haptics.
/// Uses only Flutter's built-in APIs — no extra packages.
class SoundService {
  SoundService._();

  /// Soft click — for button taps, option selections.
  static Future<void> tap() async {
    await SystemSound.play(SystemSoundType.click);
  }

  /// Double-pulse — for card flip (snap feel).
  static Future<void> flip() async {
    await HapticFeedback.lightImpact();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.lightImpact();
  }

  /// Heavy thud — for long-press delete trigger.
  static Future<void> longPress() async {
    await SystemSound.play(SystemSoundType.click);
    await HapticFeedback.heavyImpact();
  }

  /// Success — for save confirmation (medium + click).
  static Future<void> success() async {
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await SystemSound.play(SystemSoundType.click);
  }
}
