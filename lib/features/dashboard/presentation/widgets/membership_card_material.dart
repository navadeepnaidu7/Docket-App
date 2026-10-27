import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Touch moves the light across the existing card face. The card remains the
/// same object, including its text, colours, and embedded sign-in action.
class MembershipCardMaterial extends StatefulWidget {
  const MembershipCardMaterial({
    super.key,
    required this.child,
    this.radius = 22,
  });

  final Widget child;
  final double radius;

  @override
  State<MembershipCardMaterial> createState() => _MembershipCardMaterialState();
}

class _MembershipCardMaterialState extends State<MembershipCardMaterial>
    with TickerProviderStateMixin {
  late final _x = AnimationController.unbounded(vsync: this);
  late final _y = AnimationController.unbounded(vsync: this);
  late final _contact = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
    reverseDuration: const Duration(milliseconds: 280),
  );
  bool _reduced = false;
  int? _pointer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _x.value = 0;
      _y.value = 0;
      _contact.value = _pointer == null ? 0 : 1;
    }
  }

  void _follow(PointerEvent event) {
    if (_reduced || event.pointer != _pointer) return;
    final size = (context.findRenderObject()! as RenderBox).size;
    _x.value = (event.localPosition.dx / size.width - 0.5).clamp(-0.5, 0.5);
    _y.value = (event.localPosition.dy / size.height - 0.5).clamp(-0.5, 0.5);
  }

  void _press(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _follow(event);
    if (_reduced) {
      _contact.value = 1;
    } else {
      _contact.forward();
    }
  }

  void _release(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    if (_reduced) {
      _contact.value = 0;
      return;
    }
    _contact.reverse();
    const spring = SpringDescription(mass: 1, stiffness: 180, damping: 27);
    _x.animateWith(SpringSimulation(spring, _x.value, 0, _x.velocity));
    _y.animateWith(SpringSimulation(spring, _y.value, 0, _y.velocity));
  }

  @override
  void dispose() {
    _x.dispose();
    _y.dispose();
    _contact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _press,
    onPointerMove: _follow,
    onPointerUp: _release,
    onPointerCancel: _release,
    child: AnimatedBuilder(
      animation: Listenable.merge([_x, _y, _contact]),
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _SatinGrain(radius: widget.radius)),
              ),
            ),
          ],
        ),
      ),
      builder: (context, child) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..translateByDouble(0, _reduced ? 0 : -1.5 * _contact.value, 0, 1)
          ..rotateX(-_y.value * 0.06)
          ..rotateY(_x.value * 0.06),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.025 + _contact.value * 0.055
                      : 0.008 + _contact.value * 0.035,
                ),
                blurRadius: 18 + _contact.value * 8,
                spreadRadius: -3,
                offset: Offset(-_x.value * 10, 5 + _y.value * 8),
              ),
            ],
          ),
          child: CustomPaint(
            foregroundPainter: _CardLight(
              light: Offset(_x.value, _y.value),
              radius: widget.radius,
              contact: _contact.value,
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}

class _CardLight extends CustomPainter {
  const _CardLight({
    required this.light,
    required this.radius,
    required this.contact,
  });

  final Offset light;
  final double radius;
  final double contact;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final face = RRect.fromRectAndRadius(bounds, Radius.circular(radius));
    canvas.save();
    canvas.clipRRect(face);
    final strength = contact * 0.8;
    // A broad corner reflection stays quiet at rest; there is no idle ticker.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(-0.85 + light.dx * 0.6, -1 + light.dy * 0.6),
          radius: 1.65,
          colors: [
            Colors.white.withValues(alpha: 0.15 + contact * 0.08),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(bounds),
    );
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(-1.1 + light.dx, -0.9 + light.dy),
          end: Alignment(1.1 + light.dx, 0.9 + light.dy),
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.03),
            const Color(0xFFFFF5E7).withValues(alpha: 0.14 + strength * 0.15),
            const Color(0xFFE6EEFF).withValues(alpha: 0.07 + strength * 0.08),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0, 0.18, 0.4, 0.64, 1],
        ).createShader(bounds),
    );
    canvas.drawRRect(
      face.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..shader = LinearGradient(
          begin: Alignment(-0.8 + light.dx, -1),
          end: Alignment(0.8 + light.dx, 1),
          colors: [
            Colors.white.withValues(alpha: 0.6),
            Colors.white.withValues(alpha: 0.03),
            Colors.black.withValues(alpha: 0.09 + contact * 0.02),
          ],
        ).createShader(bounds),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CardLight old) =>
      light != old.light || radius != old.radius || contact != old.contact;
}

/// Kept in the static child so grain is not regenerated during touch motion.
class _SatinGrain extends CustomPainter {
  const _SatinGrain({required this.radius});
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
    );
    final random = math.Random(41);
    final grain = Paint()..color = Colors.black.withValues(alpha: 0.025);
    for (var i = 0; i < 950; i++) {
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        0.28,
        grain,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SatinGrain old) => radius != old.radius;
}
