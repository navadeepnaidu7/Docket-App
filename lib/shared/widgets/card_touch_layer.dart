import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/wallet/wallet_backdrop_tilt.dart';

/// Pointer-based touch layer for wallet cards.
///
/// Tilt is driven through a [Listener] so vertical swipes reach the parent
/// [PageView] instead of being captured by a pan recognizer.
class CardTouchLayer extends StatefulWidget {
  const CardTouchLayer({
    super.key,
    required this.child,
    required this.tiltX,
    required this.tiltY,
    required this.onTap,
    this.onLongPress,
    this.onDragStateChanged,
    this.backdropTilt,
    this.tapSlop = 18,
  });

  final Widget child;
  final ValueNotifier<double> tiltX;
  final ValueNotifier<double> tiltY;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onDragStateChanged;
  final WalletBackdropTilt? backdropTilt;
  final double tapSlop;

  @override
  State<CardTouchLayer> createState() => _CardTouchLayerState();
}

class _CardTouchLayerState extends State<CardTouchLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settle;
  Offset _releaseTilt = Offset.zero;
  Offset _grabTilt = Offset.zero;
  int? _pointer;
  bool _reducedMotion = false;
  Offset? _downPosition;
  double _verticalTravel = 0;
  double _horizontalTravel = 0;
  bool _scrollMode = false;
  bool _dragging = false;
  bool _tiltEngaged = false;
  Timer? _longPressTimer;
  bool _longPressTriggered = false;

  @override
  void initState() {
    super.initState();
    _settle =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 180),
        )..addListener(() {
          final double remaining =
              1 - Curves.easeOutCubic.transform(_settle.value);
          widget.tiltX.value = _releaseTilt.dx * remaining;
          widget.tiltY.value = _releaseTilt.dy * remaining;
          _syncBackdropTilt(dragging: false);
        });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion) _resetTilt();
  }

  void _setDragging(bool value) {
    if (_dragging == value) return;
    _dragging = value;
    widget.onDragStateChanged?.call(value);
  }

  void _syncBackdropTilt({required bool dragging}) {
    widget.backdropTilt?.update(
      tiltX: widget.tiltX.value,
      tiltY: widget.tiltY.value,
      isDragging: dragging,
    );
  }

  void _resetTilt() {
    if (!_tiltEngaged && widget.tiltX.value == 0 && widget.tiltY.value == 0) {
      widget.backdropTilt?.reset();
      return;
    }
    _tiltEngaged = false;
    _settle.stop();
    if (_reducedMotion) {
      widget.tiltX.value = 0;
      widget.tiltY.value = 0;
      widget.backdropTilt?.reset();
      return;
    }
    _releaseTilt = Offset(widget.tiltX.value, widget.tiltY.value);
    _syncBackdropTilt(dragging: false);
    _settle.forward(from: 0);
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _settle.stop();
    _grabTilt = Offset(widget.tiltX.value, widget.tiltY.value);
    _downPosition = event.localPosition;
    _verticalTravel = 0;
    _horizontalTravel = 0;
    _scrollMode = false;
    _longPressTriggered = false;
    _tiltEngaged = false;
    _setDragging(false);
    _longPressTimer?.cancel();
    if (widget.onLongPress == null) return;
    _longPressTimer = Timer(const Duration(milliseconds: 500), () {
      if (_scrollMode || _dragging) return;
      _longPressTriggered = true;
      widget.onLongPress!();
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    _verticalTravel += event.delta.dy.abs();
    _horizontalTravel += event.delta.dx.abs();

    // Only steal the gesture for PageView scrolling once movement clearly
    // exceeds a tap — small vertical jitter on flip taps must not block flip.
    if (!_scrollMode &&
        _verticalTravel > widget.tapSlop &&
        _verticalTravel > _horizontalTravel * 1.15) {
      _scrollMode = true;
      _longPressTimer?.cancel();
      _resetTilt();
      _setDragging(false);
      return;
    }
    if (_scrollMode) return;

    if (_verticalTravel > 2 || _horizontalTravel > 2) {
      _longPressTimer?.cancel();
    }

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final bool pastTapIntent =
        _verticalTravel > widget.tapSlop || _horizontalTravel > widget.tapSlop;
    _setDragging(pastTapIntent);

    // Stay perfectly flat while the gesture could still be a flip tap.
    if (!pastTapIntent || _reducedMotion) return;

    final Size size = box.size;
    if (size.isEmpty) return;
    final Offset travel = event.localPosition - _downPosition!;
    _tiltEngaged = true;
    widget.tiltX.value = (_grabTilt.dx + travel.dy / size.height).clamp(
      -0.5,
      0.5,
    );
    widget.tiltY.value = (_grabTilt.dy - travel.dx / size.width).clamp(
      -0.5,
      0.5,
    );
    _syncBackdropTilt(dragging: true);
  }

  void _onPointerEnd(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _longPressTimer?.cancel();

    if (!_scrollMode &&
        !_longPressTriggered &&
        _downPosition != null &&
        event is PointerUpEvent) {
      final double distance = (event.localPosition - _downPosition!).distance;
      final bool isTap =
          distance < widget.tapSlop &&
          _verticalTravel < widget.tapSlop &&
          _horizontalTravel < widget.tapSlop;
      if (isTap) {
        _setDragging(false);
        widget.onTap();
      }
    }

    _resetTilt();
    _setDragging(false);
    _pointer = null;
    _scrollMode = false;
    _downPosition = null;
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _settle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: widget.child,
    );
  }
}
