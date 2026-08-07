import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../../core/dev/dev_flags.dart';
import '../../../../core/wallet/wallet_palette.dart';
import '../../../ids/domain/id_document.dart';
import '../../../passport/domain/passport_profile.dart';

// ── Wash palette (Settings membership card + profile mesh) ───────────────────

Color toWashAccent(Color source, {required bool isDark}) {
  final HSLColor hsl = HSLColor.fromColor(source);
  return hsl
      .withSaturation((hsl.saturation * 0.70).clamp(0.40, 0.85))
      .withLightness(0.68)
      .toColor();
}

/// Soft pastel blooms for the membership surface and profile avatar.
List<Color> walletWashColors({
  required List<PassportProfile> passports,
  required List<IdDocument> idDocs,
  required CardFluidScheme scheme,
}) {
  switch (scheme) {
    case CardFluidScheme.titaniumClassic:
      return const <Color>[
        Color(0xFF8E8E93),
        Color(0xFF636366),
        Color(0xFFAEAEE2),
      ];
    case CardFluidScheme.emerald:
      return const <Color>[
        Color(0xFF2A9D6B),
        Color(0xFF34D399),
        Color(0xFF059669),
      ];
    case CardFluidScheme.vibrantSunset:
      return const <Color>[
        Color(0xFFE07A2F),
        Color(0xFFEC4899),
        Color(0xFF8B5CF6),
      ];
    case CardFluidScheme.neonAurora:
      return const <Color>[
        Color(0xFF38BDF8),
        Color(0xFF818CF8),
        Color(0xFFC084FC),
      ];
    case CardFluidScheme.goldenHour:
      return const <Color>[
        Color(0xFFF59E0B),
        Color(0xFFF43F5E),
        Color(0xFFD97706),
      ];
    case CardFluidScheme.auto:
      final List<Object> items = <Object>[...passports, ...idDocs];
      if (items.isEmpty) {
        return const <Color>[
          Color(0xFFFF7A00),
          Color(0xFFEC4899),
          Color(0xFF00C8FF),
          Color(0xFF10B981),
          Color(0xFF8B5CF6),
        ];
      }

      final List<Color> washes = <Color>[];
      final Set<int> seenHueBuckets = <int>{};

      for (final Object item in items) {
        final Color raw = WalletPalette.forItem(item).primary;
        final Color wash = toWashAccent(raw, isDark: false);
        final int bucket = (HSLColor.fromColor(wash).hue / 28).round();
        if (seenHueBuckets.add(bucket) || washes.length < 2) {
          washes.add(wash);
        }
        if (washes.length >= 5) break;
      }

      if (washes.length < 2 && items.length > 1) {
        for (final Object item in items) {
          washes.add(
            toWashAccent(WalletPalette.forItem(item).secondary, isDark: false),
          );
          if (washes.length >= 3) break;
        }
      }

      return washes;
  }
}

List<Color> membershipBaseColors(List<Color> washes) {
  const Color whiteBase = Color(0xFFFAFAFC);
  const Color silverMid = Color(0xFFF2F3F7);
  const Color titaniumLift = Color(0xFFE8EBF0);
  if (washes.isEmpty) return const <Color>[whiteBase, silverMid, titaniumLift];
  return <Color>[
    Color.lerp(whiteBase, washes.first, 0.12)!,
    Color.lerp(silverMid, washes.length > 1 ? washes[1] : washes.first, 0.10)!,
    Color.lerp(
      titaniumLift,
      washes.length > 2 ? washes[2] : washes.first,
      0.08,
    )!,
  ];
}

/// Stable 32-bit hash of an identity string (FNV-1a).
int meshSeedHash(String seed) {
  int hash = 0x811c9dc5;
  for (final int unit in seed.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// Phase in 0..1 derived from [seed] so the mesh is stable per user.
double meshPhaseForSeed(String seed) {
  if (seed.isEmpty) return 0.18;
  return (meshSeedHash(seed) % 1000) / 1000.0;
}

/// Hue-shifts wallet washes so two users with the same documents still differ.
List<Color> personalizeWashes(List<Color> washes, String seed) {
  if (washes.isEmpty || seed.isEmpty) return washes;
  final double shift = (meshSeedHash(seed) % 72).toDouble(); // 0..71°
  return washes.map((Color c) {
    final HSLColor hsl = HSLColor.fromColor(c);
    return hsl.withHue((hsl.hue + shift) % 360.0).toColor();
  }).toList();
}

/// Vibrant mesh palette for the small profile squircle.
///
/// The membership card deliberately washes colors toward titanium so text
/// stays readable. On a 44px avatar that same treatment collapses to a flat
/// tint. This builds a reference-style multi-hue set (peach → rose → violet →
/// soft gold), still personalized by [seed] and nudged by wallet washes.
List<Color> avatarMeshColors({
  required String seed,
  List<Color> washes = const <Color>[],
}) {
  // Reference-like anchors (soft mesh, not neon neon).
  const List<Color> anchors = <Color>[
    Color(0xFFFFB07A), // warm peach
    Color(0xFFFF7A9A), // rose
    Color(0xFFC084FC), // soft violet
    Color(0xFF818CF8), // periwinkle
    Color(0xFFFFE08A), // soft gold
  ];

  final int hash = meshSeedHash(seed.isEmpty ? 'docket-guest' : seed);
  final double shift = (hash % 360).toDouble();
  final int start = hash % anchors.length;

  final List<Color> palette = <Color>[];
  for (int i = 0; i < anchors.length; i++) {
    final Color base = anchors[(start + i) % anchors.length];
    HSLColor hsl = HSLColor.fromColor(base);
    hsl = hsl.withHue((hsl.hue + shift * 0.35) % 360.0);
    // Keep saturation high enough that blooms stay distinct at 44px.
    hsl = hsl.withSaturation(hsl.saturation.clamp(0.55, 0.88));
    hsl = hsl.withLightness(hsl.lightness.clamp(0.58, 0.78));
    palette.add(hsl.toColor());
  }

  // Fold in up to two wallet washes so the avatar still relates to docs.
  if (washes.isNotEmpty) {
    final Color w0 = toWashAccent(washes.first, isDark: false);
    palette[1] = Color.lerp(palette[1], w0, 0.45)!;
    if (washes.length > 1) {
      final Color w1 = toWashAccent(washes[1], isDark: false);
      palette[3] = Color.lerp(palette[3], w1, 0.40)!;
    }
  }

  return palette;
}

/// Soft multi-blob mesh tuned for the profile squircle (reference-like).
///
/// Large overlapping radials with high alpha so the eye reads several colors
/// at once — not a single flat wash.
class AvatarMeshPainter extends CustomPainter {
  AvatarMeshPainter({
    required this.colors,
    required this.phase,
  });

  final List<Color> colors;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.isEmpty) return;

    final double w = size.width;
    final double h = size.height;
    final double twoPi = 6.28318530718;
    final double angle = phase * twoPi;

    // Soft warm base so voids between blooms stay luminous (reference cream).
    final Paint base = Paint()
      ..shader = LinearGradient(
        begin: Alignment(
          -0.9 + 0.15 * math.sin(angle),
          -1.0,
        ),
        end: Alignment(
          1.0,
          0.9 + 0.12 * math.cos(angle * 0.8),
        ),
        colors: <Color>[
          Color.lerp(colors[0], const Color(0xFFFFF6EC), 0.35)!,
          Color.lerp(
            colors.length > 2 ? colors[2] : colors[0],
            const Color(0xFFF5EEFF),
            0.40,
          )!,
          Color.lerp(
            colors.length > 1 ? colors[1] : colors[0],
            const Color(0xFFFFE8F0),
            0.30,
          )!,
        ],
        stops: const <double>[0.0, 0.48, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, base);

    // Bloom layout: positions are fixed-ish, nudged by phase so each user
    // seed lands on a different arrangement without looking random/noisy.
    final List<_Bloom> blooms = <_Bloom>[
      _Bloom(
        Alignment(
          -0.55 + 0.12 * math.sin(angle),
          -0.60 + 0.10 * math.cos(angle * 0.9),
        ),
        colors[0],
        0.95,
        0.92,
      ),
      _Bloom(
        Alignment(
          0.70 + 0.10 * math.cos(angle * 0.75),
          -0.25 + 0.12 * math.sin(angle * 1.1),
        ),
        colors.length > 2 ? colors[2] : colors[0],
        0.88,
        0.90,
      ),
      _Bloom(
        Alignment(
          0.35 + 0.08 * math.sin(angle * 0.6),
          0.75 + 0.08 * math.cos(angle * 0.7),
        ),
        colors.length > 1 ? colors[1] : colors[0],
        0.82,
        0.88,
      ),
      _Bloom(
        Alignment(
          -0.65 + 0.10 * math.cos(angle * 1.2),
          0.55 + 0.10 * math.sin(angle * 0.85),
        ),
        colors.length > 3 ? colors[3] : colors[0],
        0.78,
        0.75,
      ),
      if (colors.length > 4)
        _Bloom(
          Alignment(
            0.05 + 0.15 * math.sin(angle * 0.5),
            0.05 + 0.12 * math.cos(angle * 0.55),
          ),
          colors[4],
          0.70,
          0.55,
        ),
    ];

    for (final _Bloom b in blooms) {
      final Offset center = Offset(
        w * (b.align.x * 0.5 + 0.5),
        h * (b.align.y * 0.5 + 0.5),
      );
      final double radius = size.shortestSide * b.radiusFactor;
      final Paint paint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            b.color.withValues(alpha: b.alpha),
            b.color.withValues(alpha: b.alpha * 0.55),
            b.color.withValues(alpha: 0.0),
          ],
          stops: const <double>[0.0, 0.42, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    // Gentle diagonal sheen so it doesn't read as flat matte.
    final Paint sheen = Paint()
      ..shader = LinearGradient(
        begin: const Alignment(-1.0, -1.0),
        end: const Alignment(0.6, 0.8),
        colors: <Color>[
          Colors.white.withValues(alpha: 0.28),
          Colors.white.withValues(alpha: 0.0),
          Colors.black.withValues(alpha: 0.04),
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sheen);
  }

  @override
  bool shouldRepaint(covariant AvatarMeshPainter oldDelegate) {
    if (oldDelegate.phase != phase ||
        oldDelegate.colors.length != colors.length) {
      return true;
    }
    for (int i = 0; i < colors.length; i++) {
      if (oldDelegate.colors[i] != colors[i]) return true;
    }
    return false;
  }
}

class _Bloom {
  const _Bloom(this.align, this.color, this.radiusFactor, this.alpha);
  final Alignment align;
  final Color color;
  final double radiusFactor;
  final double alpha;
}

/// Soft radial color washes (membership card + profile avatar).
class MembershipWashPainter extends CustomPainter {
  MembershipWashPainter({
    required this.washes,
    required this.phase,
    required this.isDark,
    required this.empty,
  });

  final List<Color> washes;
  final double phase;
  final bool isDark;
  final bool empty;

  static const List<Alignment> _anchors = <Alignment>[
    Alignment(0.85, -0.40),
    Alignment(-0.80, 0.70),
    Alignment(0.65, 0.85),
    Alignment(-0.45, -0.75),
    Alignment(0.10, 0.15),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final List<Color> layers = washes.take(3).toList();
    if (layers.isEmpty) return;

    final double twoPi = 6.28318530718;
    final double angle = phase * twoPi;

    for (int i = 0; i < layers.length; i++) {
      final Alignment base = _anchors[i % _anchors.length];
      final double speed = 0.55 + i * 0.18;
      final double orbit = 0.12 + i * 0.02;
      final double ax =
          (base.x + orbit * math.sin(angle * speed + i)).clamp(-1.15, 1.15);
      final double ay =
          (base.y + orbit * math.cos(angle * speed * 0.85 + i * 0.7))
              .clamp(-1.15, 1.15);

      final Offset center = Offset(
        size.width * (ax * 0.5 + 0.5),
        size.height * (ay * 0.5 + 0.5),
      );

      final double pulse =
          0.92 + 0.08 * math.sin(angle * (0.9 + i * 0.15) + i);
      final double richness = empty
          ? (isDark ? 0.22 : 0.16)
          : ((isDark ? 0.38 : 0.30) + layers.length * 0.03).clamp(0.20, 0.48);
      final double radius = size.shortestSide *
          lerpDouble(1.50, 0.95, i / layers.length.clamp(1, 5))! *
          pulse;

      final Paint paint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            layers[i].withValues(alpha: richness * 0.65),
            layers[i].withValues(alpha: richness * 0.25),
            layers[i].withValues(alpha: 0),
          ],
          stops: const <double>[0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant MembershipWashPainter oldDelegate) {
    if (oldDelegate.phase != phase ||
        oldDelegate.isDark != isDark ||
        oldDelegate.empty != empty ||
        oldDelegate.washes.length != washes.length) {
      return true;
    }
    for (int i = 0; i < washes.length; i++) {
      if (oldDelegate.washes[i] != washes[i]) return true;
    }
    return false;
  }
}

/// Size-agnostic mesh fill used by the membership card and profile squircle.
class MembershipMeshBackground extends StatelessWidget {
  const MembershipMeshBackground({
    super.key,
    required this.washes,
    required this.phase,
    this.isDark = false,
    this.empty = false,
    this.richAvatar = false,
  });

  final List<Color> washes;
  final double phase;
  final bool isDark;
  final bool empty;

  /// Stronger color on small avatars (less titanium wash-out).
  final bool richAvatar;

  @override
  Widget build(BuildContext context) {
    final List<Color> base = membershipBaseColors(washes);
    final List<Color> gradientColors;
    if (richAvatar && washes.isNotEmpty) {
      final Color w0 = washes.first;
      final Color w1 = washes.length > 1 ? washes[1] : w0;
      final Color w2 = washes.length > 2 ? washes[2] : w1;
      gradientColors = <Color>[
        Color.lerp(base[0], w0, 0.55)!,
        Color.lerp(base[1], w1, 0.50)!,
        Color.lerp(base[2], w2, 0.45)!,
      ];
    } else {
      gradientColors = base;
    }

    final double angle = phase * 6.28318530718;
    final Alignment begin = Alignment(
      -0.95 + 0.18 * math.sin(angle),
      -0.90 + 0.14 * math.cos(angle * 0.85),
    );
    final Alignment end = Alignment(
      0.95 + 0.12 * math.cos(angle * 0.7),
      1.05 + 0.10 * math.sin(angle * 0.9),
    );

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: begin,
              end: end,
              colors: gradientColors,
              stops: const <double>[0.0, 0.5, 1.0],
            ),
          ),
        ),
        CustomPaint(
          painter: MembershipWashPainter(
            washes: washes,
            phase: phase,
            isDark: isDark,
            empty: empty,
          ),
        ),
      ],
    );
  }
}
