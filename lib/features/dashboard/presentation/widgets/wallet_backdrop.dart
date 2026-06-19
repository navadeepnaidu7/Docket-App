import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../ids/domain/id_document.dart';
import '../../../passport/domain/passport_profile.dart';

class WalletBackdrop extends StatefulWidget {
  const WalletBackdrop({
    super.key,
    this.tabIndex = 0,
    required this.items,
    required this.pageNotifier,
  });

  final int tabIndex;
  final List<Object> items;
  final ValueNotifier<double> pageNotifier;

  @override
  State<WalletBackdrop> createState() => _WalletBackdropState();
}

class _WalletBackdropState extends State<WalletBackdrop>
    with TickerProviderStateMixin {
  late AnimationController _ctrl;
  late AnimationController _colorCtrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
    _colorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      value: widget.tabIndex.toDouble(),
    );
  }

  @override
  void didUpdateWidget(WalletBackdrop old) {
    super.didUpdateWidget(old);
    if (old.tabIndex != widget.tabIndex) {
      widget.tabIndex == 1
          ? _colorCtrl.animateTo(1.0, curve: Curves.easeOutCubic)
          : _colorCtrl.animateTo(0.0, curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge([_ctrl, _colorCtrl, widget.pageNotifier]),
            builder: (context, _) {
              final bool isDark = Theme.of(context).brightness == Brightness.dark;
              return CustomPaint(
                painter: AppleCardGradientPainter(
                  isDark: isDark,
                  progress: _ctrl.value,
                  colorT: _colorCtrl.value,
                  items: widget.items,
                  page: widget.pageNotifier.value,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class AppleCardGradientPainter extends CustomPainter {
  AppleCardGradientPainter({
    required this.isDark,
    required this.progress,
    required this.colorT,
    required this.items,
    required this.page,
  });
  
  final bool isDark;
  final double progress;
  final double colorT; // 0 = Docs (cool), 1 = Tickets (warm)
  final List<Object> items;
  final double page;

  Color _getThemeColor(Object? item) {
    if (item is PassportProfile) return const Color(0xFF007AFF); // Apple Blue
    if (item is IdDocument) {
      if (item.type == IdDocumentType.pan) return const Color(0xFFE8A020); // Orange
      return const Color(0xFF34C759); // Green
    }
    return const Color(0xFF8E8E93); // Gray default
  }

  Color _getDocsColor() {
    if (items.isEmpty) return const Color(0xFF007AFF); // Default to Blue
    final int idx1 = page.floor().clamp(0, items.length - 1);
    final int idx2 = page.ceil().clamp(0, items.length - 1);
    final double t = page - page.floor();
    final Color c1 = _getThemeColor(items[idx1]);
    final Color c2 = _getThemeColor(items[idx2]);
    return Color.lerp(c1, c2, t) ?? c1;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Base background
    final Color baseDocBg = isDark ? const Color(0xFF080E1A) : const Color(0xFFF2F2F7); // Apple standard light/dark gray
    final Color baseTicketBg = isDark ? const Color(0xFF140D0B) : const Color(0xFFFFF8E8);
    final Paint base = Paint()
      ..color = Color.lerp(baseDocBg, baseTicketBg, colorT)!;
    canvas.drawRect(Offset.zero & size, base);

    final Color docsColor = _getDocsColor();
    final Color ticketsColor = const Color(0xFFFF3B30); // Ticket Red
    final Color activeColor = Color.lerp(docsColor, ticketsColor, colorT)!;

    void drawOrb(Color c, double cx, double cy, double radius) {
      final Paint paint = Paint()
        ..color = c
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.8);
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }

    // Convert activeColor to HSL for generating matching analogous/triadic colors
    final HSLColor hslActive = HSLColor.fromColor(activeColor);

    // Orb 1 - Primary
    final double t1 = progress * 2 * math.pi;
    drawOrb(
      activeColor.withValues(alpha: isDark ? 0.16 : 0.24),
      w * 0.5 + math.cos(t1) * w * 0.12,
      h * 0.45 + math.sin(t1) * h * 0.06,
      w * 0.6,
    );

    // Orb 2 - Analogous (Hue + 40)
    final double t2 = progress * 2 * math.pi + (math.pi * 0.66);
    final Color c2 = hslActive.withHue((hslActive.hue + 40) % 360).toColor();
    drawOrb(
      c2.withValues(alpha: isDark ? 0.12 : 0.18),
      w * 0.45 + math.cos(t2) * w * 0.15,
      h * 0.52 + math.sin(t2) * h * 0.08,
      w * 0.65,
    );

    // Orb 3 - Analogous (Hue - 40)
    final double t3 = progress * 2 * math.pi + (math.pi * 1.33);
    final Color c3 = hslActive.withHue((hslActive.hue - 40 + 360) % 360).toColor();
    drawOrb(
      c3.withValues(alpha: isDark ? 0.16 : 0.24),
      w * 0.55 + math.cos(t3) * w * 0.1,
      h * 0.4 + math.sin(t3) * h * 0.05,
      w * 0.6,
    );
  }

  @override
  bool shouldRepaint(covariant AppleCardGradientPainter old) =>
      old.progress != progress ||
      old.colorT != colorT ||
      old.page != page ||
      old.items.length != items.length ||
      old.isDark != isDark;
}
