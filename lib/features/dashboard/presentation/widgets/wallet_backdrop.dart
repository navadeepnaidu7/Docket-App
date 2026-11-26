import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/wallet/wallet_backdrop_tilt.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/motion/smooth_curves.dart';
import '../../../../core/wallet/wallet_palette.dart';

class WalletBackdrop extends StatefulWidget {
  const WalletBackdrop({
    super.key,
    this.tabIndex = 0,
    this.tabAnimation,
    required this.items,
    required this.pageNotifier,
    this.tiltNotifier,
  });

  final int tabIndex;
  final Animation<double>? tabAnimation;
  final List<Object> items;
  final ValueNotifier<double> pageNotifier;
  final WalletBackdropTilt? tiltNotifier;

  @override
  State<WalletBackdrop> createState() => _WalletBackdropState();
}

/// A slow looping drift that advances at a fixed low rate, on a timer.
///
/// The backdrop's two ambient drifts run over 14s and 30s. At a 390px width the
/// nearer orb covers about 20px per second, so stepping it [_hz] times a second
/// leaves at most ~1.6px of travel between steps at the fastest point of the
/// sweep, across a blur hundreds of pixels wide that cannot show it.
///
/// This must not be an [AnimationController]. A running controller asks for a
/// frame on every vsync, and every frame is composited and rasterised in full
/// even when nothing repainted: the framework always submits a scene. With two
/// controllers looping forever, the wallet never went idle. On a 120Hz panel it
/// sent ~100 full frames a second at ~10ms of raster each, over the 8.3ms
/// budget, so the GPU had no headroom left for a tab switch or a swipe. A timer
/// asks for a frame only when the value actually moves.
///
/// Only the *ambient* clocks are slowed. The page position, the card tilt and
/// the tab tint stay on the raw signal, because those follow a finger and have
/// to land on the frame the finger is on.
class _DriftClock extends ChangeNotifier {
  _DriftClock(this.period)
    : _steps = math.max(1, (period.inMilliseconds * _hz) ~/ 1000);

  static const int _hz = 20;

  final Duration period;

  /// Ticks per loop; the drift advances one step per tick.
  final int _steps;
  int _step = 0;
  Timer? _timer;

  /// Progress through the loop, 0 to 1, in whole steps.
  double get value => _step / _steps;

  void start() {
    _timer ??= Timer.periodic(
      const Duration(milliseconds: 1000 ~/ _hz),
      (_) => _tick(),
    );
  }

  /// Pauses where it is; [start] resumes from the same point.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Stops and returns to the start of the loop.
  void reset() {
    stop();
    if (_step != 0) {
      _step = 0;
      notifyListeners();
    }
  }

  void _tick() {
    _step = (_step + 1) % _steps;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

class _WalletBackdropState extends State<WalletBackdrop>
    with TickerProviderStateMixin {
  late AnimationController _colorCtrl;
  final _DriftClock _ambientClock = _DriftClock(const Duration(seconds: 14));
  final _DriftClock _deepClock = _DriftClock(const Duration(seconds: 30));

  /// Mirrors [TickerMode], which the dashboard uses to mute the backdrop while
  /// Settings or the weather drawer covers it. Timers do not see it on their
  /// own, so the drift listens and pauses itself.
  ValueListenable<TickerModeData>? _tickerMode;

  /// True once the deferred start has fired, so a later reduced-motion toggle
  /// knows whether the drift is meant to be running.
  bool _driftWanted = false;
  bool _reducedMotion = false;
  Timer? _driftTimer;

  @override
  void initState() {
    super.initState();
    _colorCtrl = AnimationController(
      vsync: this,
      duration: stepSwitchDuration,
      value: widget.tabIndex.toDouble().clamp(0.0, 1.0),
    );
    // Defer looping ambient motion so the first frames stay free for layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _driftTimer = Timer(const Duration(milliseconds: 480), () {
        if (!mounted) return;
        _driftWanted = true;
        _syncDrift();
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ValueListenable<TickerModeData> tickerMode =
        TickerMode.getValuesNotifier(context);
    if (!identical(tickerMode, _tickerMode)) {
      _tickerMode?.removeListener(_syncDrift);
      _tickerMode = tickerMode..addListener(_syncDrift);
    }
    // Reduced motion freezes the wash rather than slowing it. Both clocks stay
    // at 0, which is the composition the first frame already paints — the
    // tickers only start 480ms in — so the still image is not a new look.
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced == _reducedMotion) return;
    _reducedMotion = reduced;
    if (reduced) {
      _ambientClock.reset();
      _deepClock.reset();
    } else {
      _syncDrift();
    }
  }

  /// Runs the drift when it is wanted, motion is allowed and the backdrop is
  /// not muted; pauses it otherwise.
  void _syncDrift() {
    final bool run =
        _driftWanted && !_reducedMotion && (_tickerMode?.value.enabled ?? true);
    if (run) {
      _ambientClock.start();
      _deepClock.start();
    } else {
      _ambientClock.stop();
      _deepClock.stop();
    }
  }

  @override
  void didUpdateWidget(WalletBackdrop old) {
    super.didUpdateWidget(old);
    if (widget.tabAnimation == null && old.tabIndex != widget.tabIndex) {
      widget.tabIndex == 1
          ? _colorCtrl.animateTo(1.0, curve: strongEaseOut)
          : _colorCtrl.animateTo(0.0, curve: strongEaseOut);
    }
  }

  @override
  void dispose() {
    _driftTimer?.cancel();
    _tickerMode?.removeListener(_syncDrift);
    _ambientClock.dispose();
    _deepClock.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listenables = <Listenable>[
      _ambientClock,
      _deepClock,
      widget.tabAnimation ?? _colorCtrl,
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
              final double ticketsMix =
                  (widget.tabAnimation?.value ?? _colorCtrl.value).clamp(
                    0.0,
                    1.0,
                  );
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

  /// The scene is drawn at this fraction of logical resolution and scaled up.
  ///
  /// It is six orbs blurred across hundreds of pixels plus a radial vignette,
  /// with no edge sharper than the blur, so a half-resolution image scaled up
  /// is indistinguishable from the full one. At full resolution the blurs were
  /// the single largest raster cost in the app: on a 120Hz phone the wallet
  /// rasterised in ~10ms a frame with them and ~4ms without, against an 8.3ms
  /// budget, which is what made tab switches and swipes stutter.
  static const double _sceneScale = 0.5;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final int iw = math.max(1, (size.width * _sceneScale).ceil());
    final int ih = math.max(1, (size.height * _sceneScale).ceil());
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas scene = Canvas(recorder)..scale(_sceneScale);
    _paintScene(scene, size);
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = picture.toImageSync(iw, ih);
    picture.dispose();
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, iw.toDouble(), ih.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
    // The recorded frame holds its own reference.
    image.dispose();
  }

  void _paintScene(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Both tabs share the neutral page colour. Colour belongs to the card; the
    // backdrop only echoes it as a halo, so switching tabs shifts the glow
    // rather than repainting the whole screen navy or maroon.
    final Color neutralBase = AppTheme.background(
      isDark ? Brightness.dark : Brightness.light,
    );
    final double tintStrength = isDark ? 0.08 : 0.05;
    final Paint basePaint = Paint()
      ..color = Color.lerp(
        neutralBase,
        palette.ambientTint(isDark: isDark),
        tintStrength,
      )!;
    canvas.drawRect(Offset.zero & size, basePaint);

    // Global strength of the halo. Tuned so the focused card is clearly the
    // most saturated thing on screen.
    final double halo = isDark ? 0.62 : 0.5;

    void drawOrb(
      Color color,
      double cx,
      double cy,
      double radius, {
      double blurFactor = 0.8,
    }) {
      final Paint paint = Paint()
        ..color = color.withValues(alpha: color.a * halo)
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
    final Color analogousPlus = hslPrimary
        .withHue((hslPrimary.hue + 40) % 360)
        .toColor();
    final Color analogousMinus = hslPrimary
        .withHue((hslPrimary.hue - 40 + 360) % 360)
        .toColor();

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
      palette.primary.withValues(alpha: (isDark ? 0.14 : 0.20) * focusStrength),
      w * 0.5 + parallaxX,
      focusY,
      w * 0.48 * (0.92 + focusStrength * 0.12),
      blurFactor: 0.72,
    );

    drawOrb(
      analogousPlus.withValues(alpha: (isDark ? 0.08 : 0.12) * focusStrength),
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
          Colors.black.withValues(alpha: isDark ? 0.28 : 0.0),
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
