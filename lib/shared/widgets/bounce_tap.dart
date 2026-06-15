import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BounceTap extends StatefulWidget {
  const BounceTap({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.scaleFactor = 0.96,
    this.duration = const Duration(milliseconds: 120),
    this.hapticFeedback = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleFactor;
  final Duration duration;
  final bool hapticFeedback;

  @override
  State<BounceTap> createState() => _BounceTapState();
}

class _BounceTapState extends State<BounceTap> {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    setState(() => _isPressed = true);
  }

  void _onTapUp(TapUpDetails _) {
    if (!_isPressed) return;
    setState(() => _isPressed = false);
  }

  void _onTapCancel() {
    if (!_isPressed) return;
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap != null
          ? () {
              if (widget.hapticFeedback) {
                HapticFeedback.lightImpact();
              }
              widget.onTap!();
            }
          : null,
      onLongPress: widget.onLongPress != null
          ? () {
              if (widget.hapticFeedback) {
                HapticFeedback.mediumImpact();
              }
              widget.onLongPress!();
            }
          : null,
      child: AnimatedScale(
        scale: _isPressed ? widget.scaleFactor : 1.0,
        duration: widget.duration,
        curve: Curves.easeOutQuad,
        child: widget.child,
      ),
    );
  }
}
