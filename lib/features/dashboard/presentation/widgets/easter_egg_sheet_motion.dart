import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'easter_egg_constants.dart';

class EasterEggSheetMotion {
  const EasterEggSheetMotion({
    required this.progress,
    required this.sheetOffsetY,
    required this.drawerTop,
    required this.topRadius,
    required this.sheetScale,
    required this.shadowOpacity,
    required this.pullPillOpacity,
    required this.pillBarOffsetY,
    required this.pillBarOpacity,
  });

  final double progress;
  final double sheetOffsetY;
  final double drawerTop;
  final double topRadius;
  final double sheetScale;
  final double shadowOpacity;
  final double pullPillOpacity;
  final double pillBarOffsetY;
  final double pillBarOpacity;

  static EasterEggSheetMotion lerpFromOffset(double offsetY) {
    final double panelHeight = kEasterEggPanelHeight;
    final double t = (offsetY / panelHeight).clamp(0.0, 1.0);
    final double eased = Curves.easeOutCubic.transform(t);

    return EasterEggSheetMotion(
      progress: t,
      sheetOffsetY: offsetY,
      // The drawer is anchored to the window. The main surface reveals it by
      // moving down, so the two surfaces never drift apart during a drag.
      drawerTop: 0,
      topRadius: lerpDouble(0, 28, eased)!,
      sheetScale: lerpDouble(1.0, 0.992, eased)!,
      shadowOpacity: lerpDouble(0, 0.20, eased)!,
      pullPillOpacity: lerpDouble(0, 0.42, eased)!,
      pillBarOffsetY: lerpDouble(0, 8, eased)!,
      pillBarOpacity: lerpDouble(1, 0.88, eased)!,
    );
  }

  static bool shouldSnapOpen({
    required double offsetY,
    required double velocityY,
  }) {
    final double threshold = kEasterEggPanelHeight * kEasterEggSnapThreshold;
    if (velocityY > kEasterEggVelocityOpen) return true;
    if (velocityY < kEasterEggVelocityClose) return false;
    return offsetY > threshold;
  }
}
