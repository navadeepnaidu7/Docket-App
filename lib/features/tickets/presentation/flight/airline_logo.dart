import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/airline_logo_cache.dart';
import '../../domain/airline_brands.dart';

export '../../data/airline_logo_cache.dart' show AirlineLogos;

/// An airline's logo drawn in one colour, sized so marks of different shapes
/// look the same size: a long wordmark runs wide and short, a square
/// emblem stands taller and narrower, and both cover about the same area.
///
/// Shows [fallback] until the logo has loaded, or for good when there is
/// none. The logo's bottom edge sits where the fallback's box ends, so it
/// can share a baseline row with text.
class AirlineLogo extends StatefulWidget {
  const AirlineLogo({
    super.key,
    required this.code,
    required this.color,
    required this.fallback,
    this.semanticsLabel,
    this.area = 2000,
    this.minHeight = 16,
    this.maxHeight = 30,
    this.maxWidth = 168,
  });

  final String code;
  final Color color;
  final Widget fallback;
  final String? semanticsLabel;

  /// Target area of the logo's box in logical pixels.
  final double area;
  final double minHeight;
  final double maxHeight;
  final double maxWidth;

  /// The box a logo of [aspect] is drawn in.
  static Size fit(
    double aspect, {
    double area = 2000,
    double minHeight = 16,
    double maxHeight = 30,
    double maxWidth = 168,
    double scale = 1,
  }) {
    // The scale lifts the cap too: it exists for emblems whose lettering
    // is too fine to read at the normal ceiling.
    double h = (math.sqrt(area / aspect) * scale).clamp(
      minHeight,
      maxHeight * scale,
    );
    if (h * aspect > maxWidth) h = maxWidth / aspect;
    return Size(h * aspect, h);
  }

  @override
  State<AirlineLogo> createState() => _AirlineLogoState();
}

class _AirlineLogoState extends State<AirlineLogo> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(AirlineLogo old) {
    super.didUpdateWidget(old);
    if (old.code != widget.code) _resolve();
  }

  void _resolve() {
    final String code = widget.code;
    _bytes = AirlineLogos.peek(code);
    if (_bytes != null) return;
    AirlineLogos.load(code).then((Uint8List? bytes) {
      if (!mounted || widget.code != code || bytes == null) return;
      setState(() => _bytes = bytes);
    });
  }

  @override
  Widget build(BuildContext context) {
    final Uint8List? bytes = _bytes;
    final double? aspect = bytes == null ? null : AirlineLogos.aspectOf(bytes);
    final Widget child;
    if (bytes == null || aspect == null) {
      child = KeyedSubtree(
        key: const ValueKey<String>('fallback'),
        child: widget.fallback,
      );
    } else {
      final Size box = AirlineLogo.fit(
        aspect,
        area: widget.area,
        minHeight: widget.minHeight,
        maxHeight: widget.maxHeight,
        maxWidth: widget.maxWidth,
        scale: AirlineBrand.of(widget.code)?.logoScale ?? 1,
      );
      child = _BaselineAtBottom(
        key: ValueKey<String>('logo-${widget.code}'),
        child: SvgPicture.memory(
          bytes,
          width: box.width,
          height: box.height,
          colorFilter: ColorFilter.mode(widget.color, BlendMode.srcIn),
          semanticsLabel: widget.semanticsLabel,
        ),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
        alignment: Alignment.bottomLeft,
        children: <Widget>[...previous, ?current],
      ),
      child: child,
    );
  }
}

/// Reports its bottom edge as the text baseline, so a logo stands on the
/// same line as the type next to it.
class _BaselineAtBottom extends SingleChildRenderObjectWidget {
  const _BaselineAtBottom({super.key, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBaselineAtBottom();
}

class _RenderBaselineAtBottom extends RenderProxyBox {
  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => size.height;

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) => getDryLayout(constraints).height;
}
