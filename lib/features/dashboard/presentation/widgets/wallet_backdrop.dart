import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/wallet/wallet_backdrop_tilt.dart';
import '../../../../core/wallet/wallet_palette.dart';

class WalletBackdrop extends StatefulWidget {
  const WalletBackdrop({
    super.key,
    this.tabIndex = 0,
    required this.items,
    required this.pageNotifier,
    this.tiltNotifier,
  });

  final int tabIndex;
  final List<Object> items;
  final ValueNotifier<double> pageNotifier;
  final WalletBackdropTilt? tiltNotifier;

  @override
  State<WalletBackdrop> createState() => _WalletBackdropState();
}

/// Reports a slow [AnimationController] at a fixed low rate instead of every
/// frame.
///
/// The backdrop's two ambient drifts run over 14s and 30s. At a 390px width the
/// nearer orb covers about 20px per second, so a 60fps tick advances it a third
/// of a pixel — across a blur hundreds of pixels wide. Every one of those
/// ticks rebuilt the backdrop (re-running [WalletPalette.blended] and
/// allocating a focus signature) and repainted a full-screen canvas of six
/// overlapping viewport-scale translucent orbs plus a radial vignette, 60 or
/// 120 times a second, for motion nobody can see at that resolution.
///
/// Quantising to [_hz] steps per second leaves at most ~1.6px of travel between
/// steps at the fastest point of the sweep, which that blur cannot show, and
/// cuts the full-screen rebuild-and-repaint rate by 3x on a 60Hz panel and 6x
/// on a 120Hz one.
///
/// Only the *ambient* clocks are quantised. The page position, the card tilt
/// and the tab tint stay on the raw signal, because those follow a finger and
/// have to land on the frame the finger is on.
class _QuantizedClock extends ChangeNotifier {
  _QuantizedClock(this._source, Duration period)
    : _steps = math.max(1, (period.inMilliseconds * _hz) ~/ 1000) {
    _value = _quantize(_source.value);
    _source.addListener(_onSourceTick);
  }

  static const int _hz = 20;

  final Animation<double> _source;
  final int _steps;
  late double _value;

  /// The source value, floored to the nearest step.
  double get value => _value;

  double _quantize(double raw) => (raw * _steps).floor() / _steps;

  void _onSourceTick() {
    final double next = _quantize(_source.value);
    if (next == _value) return;
    _value = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _source.removeListener(_onSourceTick);
    super.dispose();
  }
}

class _WalletBackdropState extends State<WalletBackdrop>
    with TickerProviderStateMixin {
  late AnimationController _ambientCtrl;
  late AnimationController _deepCtrl;
  late AnimationController _colorCtrl;
  late _QuantizedClock _ambientClock;
  late _QuantizedClock _deepClock;

  /// True once the deferred start has fired, so a later reduced-motion toggle
  /// knows whether the drift is meant to be running.
  bool _driftWanted = false;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
    _deepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    );
    _colorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      value: widget.tabIndex.toDouble().clamp(0.0, 1.0),
    );
    _ambientClock = _QuantizedClock(_ambientCtrl, _ambientCtrl.duration!);
    _deepClock = _QuantizedClock(_deepCtrl, _deepCtrl.duration!);
    // Defer looping ambient motion so the first frames stay free for layout.
    // Controllers respect TickerMode — dashboard mutes them while Settings is open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future<void>.delayed(const Duration(milliseconds: 480), () {
        if (!mounted) return;
        _driftWanted = true;
        _startDrift();
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion freezes the wash rather than slowing it. Both clocks stay
    // at 0, which is the composition the first frame already paints — the
    // tickers only start 480ms in — so the still image is not a new look.
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced == _reducedMotion) return;
    _reducedMotion = reduced;
    if (reduced) {
      _ambientCtrl.stop();
      _deepCtrl.stop();
      _ambientCtrl.value = 0;
      _deepCtrl.value = 0;
    } else {
      _startDrift();
    }
  }

  void _startDrift() {
    if (!_driftWanted || _reducedMotion) return;
    if (!_ambientCtrl.isAnimating) _ambientCtrl.repeat();
    if (!_deepCtrl.isAnimating) _deepCtrl.repeat();
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
    _ambientClock.dispose();
    _deepClock.dispose();
    _ambientCtrl.dispose();
    _deepCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listenables = <Listenable>[
      // The quantised clocks, not the controllers they wrap.
      _ambientClock,
      _deepClock,
      _colorCtrl,
      widget.pageNotifier,
    ];
    if (widget.tiltNotifier != null) {
      listenables.add(widget.tiltNotifier!);
    }

    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge(listenables),
            builder: (context, _) {
              final bool isDark =
                  Theme.of(context).brightness == Brightness.dark;
              final double ticketsMix = _colorCtrl.value;
              final WalletPalette palette = WalletPalette.blended(
                items: widget.items,
                page: widget.pageNotifier.value,
                ticketsMix: ticketsMix,
              );

              return CustomPaint(
                painter: AppleCardGradientPainter(
                  isDark: isDark,
                  ambientProgress: _ambientClock.value,
                  deepProgress: _deepClock.value,
                  ticketsMix: ticketsMix,
                  palette: palette,
                  items: widget.items,
                  page: widget.pageNotifier.value,
                  tilt: widget.tiltNotifier?.value ?? Offset.zero,
                  isDragging: widget.tiltNotifier?.dragging ?? false,
                  focusSignature: WalletPalette.focusSignature(
                    widget.items,
                    widget.pageNotifier.value,
                  ),
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
    required this.ambientProgress,
    required this.deepProgress,
    required this.ticketsMix,
    required this.palette,
    required this.items,
    required this.page,
    required this.tilt,
    required this.isDragging,
    required this.focusSignature,
  });

  final bool isDark;
  final double ambientProgress;
  final double deepProgress;
  final double ticketsMix;
  final WalletPalette palette;
  final List<Object> items;
  final double page;
  final Offset tilt;
  final bool isDragging;
  final String focusSignature;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Color baseDocBg =
        isDark ? const Color(0xFF080E1A) : const Color(0xFFF2F2F7);
    final Color baseTicketBg =
        isDark ? const Color(0xFF140D0B) : const Color(0xFFFFF8E8);
    final Color neutralBase = Color.lerp(baseDocBg, baseTicketBg, ticketsMix)!;
    final double tintStrength = isDark ? 0.22 : 0.10;
    final Paint basePaint = Paint()
      ..color = Color.lerp(
        neutralBase,
        palette.ambientTint(isDark: isDark),
        tintStrength,
      )!;
    canvas.drawRect(Offset.zero & size, basePaint);

    void drawOrb(
      Color color,
      double cx,
      double cy,
      double radius, {
      double blurFactor = 0.8,
    }) {
      final Paint paint = Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * blurFactor);
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }

    final double scrollT = items.isEmpty
        ? 0
        : (page / math.max(1, items.length - 1)).clamp(0.0, 1.0);
    final double focusY = _lerp(h * 0.38, h * 0.54, scrollT);
    final double parallaxX = _lerp(-w * 0.04, w * 0.04, scrollT);
    final double breathe = 1 + 0.06 * math.sin(ambientProgress * math.pi * 2);

    final HSLColor hslPrimary = HSLColor.fromColor(palette.primary);
    final Color analogousPlus =
        hslPrimary.withHue((hslPrimary.hue + 40) % 360).toColor();
    final Color analogousMinus =
        hslPrimary.withHue((hslPrimary.hue - 40 + 360) % 360).toColor();

    // Deep slow layer — depth without clutter.
    final double deepT = deepProgress * math.pi * 2;
    drawOrb(
      palette.ambient.withValues(alpha: isDark ? 0.07 : 0.10),
      w * 0.62 + math.cos(deepT) * w * 0.18,
      h * 0.62 + math.sin(deepT) * h * 0.10,
      w * 0.72,
      blurFactor: 1.0,
    );

    // Ambient drifting orbs (calm but visible).
    final double t1 = ambientProgress * math.pi * 2;
    drawOrb(
      palette.primary.withValues(alpha: isDark ? 0.10 : 0.14),
      w * 0.5 + math.cos(t1) * w * 0.18 + parallaxX,
      focusY + math.sin(t1) * h * 0.09,
      w * 0.58 * breathe,
    );

    final double t2 = ambientProgress * math.pi * 2 + math.pi * 0.66;
    drawOrb(
      palette.secondary.withValues(alpha: isDark ? 0.08 : 0.12),
      w * 0.42 + math.cos(t2) * w * 0.20 - parallaxX * 0.5,
      focusY + h * 0.08 + math.sin(t2) * h * 0.11,
      w * 0.62 * breathe,
    );

    final double t3 = ambientProgress * math.pi * 2 + math.pi * 1.33;
    drawOrb(
      analogousMinus.withValues(alpha: isDark ? 0.09 : 0.13),
      w * 0.58 + math.cos(t3) * w * 0.14 + parallaxX * 0.7,
      focusY - h * 0.06 + math.sin(t3) * h * 0.07,
      w * 0.56 * breathe,
    );

    // Focus orb — scroll-weighted primary glow.
    final double focusStrength = _focusIntensity();
    drawOrb(
      palette.primary.withValues(
        alpha: (isDark ? 0.14 : 0.20) * focusStrength,
      ),
      w * 0.5 + parallaxX,
      focusY,
      w * 0.48 * (0.92 + focusStrength * 0.12),
      blurFactor: 0.72,
    );

    drawOrb(
      analogousPlus.withValues(
        alpha: (isDark ? 0.08 : 0.12) * focusStrength,
      ),
      w * 0.72 + parallaxX * 0.4,
      focusY + h * 0.05,
      w * 0.38,
      blurFactor: 0.7,
    );

    // Tilt-reactive specular bloom.
    if (isDragging && tilt.distance > 0.01) {
      drawOrb(
        palette.secondary.withValues(alpha: isDark ? 0.12 : 0.16),
        w * (0.5 + tilt.dx * 0.22),
        h * (0.46 + tilt.dy * 0.18),
        w * 0.22,
        blurFactor: 0.55,
      );
    }

    // Soft vignette for depth.
    final Rect vignetteRect = Offset.zero & size;
    final Paint vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.05,
        colors: [
          Colors.transparent,
          (isDark ? Colors.black : Colors.black.withValues(alpha: 0.08))
              .withValues(alpha: isDark ? 0.35 : 0.08),
        ],
        stops: const [0.55, 1.0],
      ).createShader(vignetteRect);
    canvas.drawRect(vignetteRect, vignette);
  }

  double _focusIntensity() {
    if (items.isEmpty) return 1;
    final int nearest = page.round().clamp(0, items.length - 1);
    final double distance = (page - nearest).abs();
    return (1 - distance * 0.65).clamp(0.45, 1.0);
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(covariant AppleCardGradientPainter old) =>
      old.ambientProgress != ambientProgress ||
      old.deepProgress != deepProgress ||
      old.ticketsMix != ticketsMix ||
      old.page != page ||
      old.isDark != isDark ||
      old.tilt != tilt ||
      old.isDragging != isDragging ||
      old.focusSignature != focusSignature ||
      old.palette.primary != palette.primary;
}