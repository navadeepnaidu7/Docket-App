import 'package:flutter/material.dart';

import '../../features/ids/domain/id_document.dart';
import '../../features/ids/domain/id_document_catalog.dart';
import '../../features/passport/domain/passport_profile.dart';
import 'wallet_items.dart';

/// Color system for wallet backdrop gradients per item type.
class WalletPalette {
  const WalletPalette({
    required this.primary,
    required this.secondary,
    required this.ambient,
    required this.baseTint,
  });

  final Color primary;
  final Color secondary;
  final Color ambient;
  final Color baseTint;

  static const WalletPalette passport = WalletPalette(
    primary: Color(0xFF007AFF),
    secondary: Color(0xFF5AC8FA),
    ambient: Color(0xFF0A84FF),
    baseTint: Color(0xFFE8F1FF),
  );

  static const WalletPalette empty = WalletPalette(
    primary: Color(0xFF007AFF),
    secondary: Color(0xFF64D2FF),
    ambient: Color(0xFF5E5CE6),
    baseTint: Color(0xFFE8ECFF),
  );

  static const WalletPalette tickets = WalletPalette(
    primary: Color(0xFFFF3B30),
    secondary: Color(0xFFFF9500),
    ambient: Color(0xFFFF6482),
    baseTint: Color(0xFFFFF0EB),
  );

  static WalletPalette forItem(Object? item) {
    return switch (item) {
      PassportProfile() => passport,
      IdDocument doc => forIdType(doc.type),
      _ => empty,
    };
  }

  static WalletPalette forIdType(IdDocumentType type) {
    final descriptor = IdDocumentCatalog.descriptorFor(type);
    final Color primary = descriptor.accentColor;
    final HSLColor hsl = HSLColor.fromColor(primary);
    return WalletPalette(
      primary: primary,
      secondary: hsl.withHue((hsl.hue + 32) % 360).withLightness(
        (hsl.lightness + 0.08).clamp(0.0, 1.0),
      ).toColor(),
      ambient: hsl.withHue((hsl.hue - 28 + 360) % 360).withSaturation(
        (hsl.saturation * 0.75).clamp(0.0, 1.0),
      ).toColor(),
      // Light pastel for light mode; backdrop darkens this when isDark.
      baseTint: hsl.withLightness(0.92).withSaturation(0.35).toColor(),
    );
  }

  /// Dark-mode ambient tint: lower luminance so it won't wash out navy bg.
  Color ambientTint({required bool isDark}) {
    if (!isDark) return baseTint;
    final HSLColor hsl = HSLColor.fromColor(baseTint);
    return hsl
        .withLightness((hsl.lightness * 0.22).clamp(0.08, 0.28))
        .withSaturation((hsl.saturation * 0.85).clamp(0.0, 1.0))
        .toColor();
  }

  /// Blends palettes across scroll position and tab selection.
  static WalletPalette blended({
    required List<Object> items,
    required double page,
    required double ticketsMix,
  }) {
    if (ticketsMix >= 0.999) return tickets;
    if (items.isEmpty) {
      return _lerpPalettes(empty, tickets, ticketsMix);
    }

    final int maxIndex = items.length - 1;
    final int idx1 = page.floor().clamp(0, maxIndex);
    final int idx2 = page.ceil().clamp(0, maxIndex);
    final double t = page - page.floor();
    final WalletPalette docsPalette =
        _lerpPalettes(forItem(items[idx1]), forItem(items[idx2]), t);
    return _lerpPalettes(docsPalette, tickets, ticketsMix);
  }

  static String focusSignature(List<Object> items, double page) {
    if (items.isEmpty) return 'empty';
    final int idx = page.round().clamp(0, items.length - 1);
    final Object item = items[idx];
    return '${walletItemId(item)}:${item.runtimeType}';
  }

  static WalletPalette _lerpPalettes(
    WalletPalette a,
    WalletPalette b,
    double t,
  ) {
    return WalletPalette(
      primary: Color.lerp(a.primary, b.primary, t)!,
      secondary: Color.lerp(a.secondary, b.secondary, t)!,
      ambient: Color.lerp(a.ambient, b.ambient, t)!,
      baseTint: Color.lerp(a.baseTint, b.baseTint, t)!,
    );
  }
}