import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../../core/motion/smooth_curves.dart';
import '../domain/card_surface.dart';
import 'card_material.dart';

/// Raw pointer observation leaves reveal, open, swipe and long-press gestures
/// with their existing recognizers. Only an active full face starts its clock.
class LivingCardMaterial extends StatefulWidget {
  const LivingCardMaterial({
    super.key,
    required this.surface,
    required this.child,
    required this.active,
    this.issuerId,
    this.variant = 0,
    this.pinned = false,
  });

  final CardSurfaceStyle surface;
  final Widget child;
  final bool active;
  final String? issuerId;
  final int variant;
  final bool pinned;

  @override
  State<LivingCardMaterial> createState() => _LivingCardMaterialState();
}

class _LivingCardMaterialState extends State<LivingCardMaterial>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final _time = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 720),
  );
  late final _entrance = AnimationController(
    vsync: this,
    duration: stepSwitchDuration,
  );
  late final _x = AnimationController.unbounded(vsync: this);
  late final _y = AnimationController.unbounded(vsync: this);
  late final _contact = AnimationController(vsync: this);
  late final _pose = Listenable.merge([_x, _y, _contact]);
  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 180,
    damping: 27,
  );
  ScrollPosition? _scroll;
  bool _foreground = true;
  bool _tickerEnabled = true;
  bool _currentRoute = true;
  bool _visible = true;
  bool _reduced = false;
  int? _pointer;

  bool get _canInteract =>
      widget.active &&
      _foreground &&
      _tickerEnabled &&
      _currentRoute &&
      _visible;

  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _currentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    final scroll = Scrollable.maybeOf(context)?.position;
    if (_scroll != scroll) {
      _scroll?.removeListener(_updateVisibility);
      _scroll = scroll;
      _scroll?.addListener(_updateVisibility);
    }
    _syncMotion();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateVisibility());
  }

  @override
  void didUpdateWidget(LivingCardMaterial oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateVisibility());
  }

  void _updateVisibility() {
    if (!mounted || widget.pinned) return;
    final box = context.findRenderObject();
    final viewport = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (box is RenderBox &&
        box.hasSize &&
        box.attached &&
        viewport is RenderBox &&
        viewport.hasSize &&
        viewport.attached) {
      final face = box.localToGlobal(Offset.zero) & box.size;
      final window = viewport.localToGlobal(Offset.zero) & viewport.size;
      final visible = face.overlaps(window);
      if (_visible != visible) {
        _visible = visible;
        _syncMotion();
      }
    }
  }

  void _syncMotion() {
    if (_canInteract && !_reduced) {
      if (!_time.isAnimating) _time.repeat();
      if (_entrance.value < 1 && !_entrance.isAnimating) {
        _entrance.animateTo(1, curve: strongEaseOut);
      }
    } else {
      // Retain the phase, so resuming never jumps ahead by time spent hidden.
      _time.stop();
      _entrance.stop();
    }
    if (!_canInteract || _reduced) {
      _pointer = null;
      _x.value = 0;
      _y.value = 0;
      _contact.value = 0;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  void _springTo(AnimationController controller, double target) {
    controller.animateWith(
      SpringSimulation(_spring, controller.value, target, controller.velocity),
    );
  }

  void _track(Offset local) {
    if (_reduced) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.isEmpty) return;
    _springTo(_x, (local.dx / box.size.width * 2 - 1).clamp(-1.0, 1.0));
    _springTo(_y, (local.dy / box.size.height * 2 - 1).clamp(-1.0, 1.0));
  }

  void _down(PointerDownEvent event) {
    if (!_canInteract || _pointer != null) return;
    _pointer = event.pointer;
    _track(event.localPosition);
    _contact.animateTo(
      1,
      duration: const Duration(milliseconds: 110),
      curve: strongEaseOut,
    );
  }

  void _release(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    if (!_reduced) {
      _springTo(_x, 0);
      _springTo(_y, 0);
    }
    _contact.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: strongEaseOut,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll?.removeListener(_updateVisibility);
    for (final controller in [_time, _entrance, _x, _y, _contact]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _down,
    onPointerMove: (event) {
      if (event.pointer == _pointer) _track(event.localPosition);
    },
    onPointerUp: _release,
    onPointerCancel: _release,
    child: AnimatedBuilder(
      animation: _pose,
      builder: (context, child) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .0015)
          ..translateByDouble(0, _reduced ? 0 : -1.5 * _contact.value, 0, 1)
          ..rotateX(_reduced ? 0 : -_y.value * .052)
          ..rotateY(_reduced ? 0 : _x.value * .052),
        child: child,
      ),
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: CardMaterial(
                      widget.surface,
                      issuerId: widget.issuerId,
                      variant: widget.variant,
                      time: _time,
                      entrance: _entrance,
                      horizontal: _x,
                      vertical: _y,
                      contact: _contact,
                    ),
                  ),
                ),
              ),
              RepaintBoundary(child: widget.child),
            ],
          ),
        ),
      ),
    ),
  );
}
