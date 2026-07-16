import 'package:flutter/material.dart';

class AddFab extends StatefulWidget {
  const AddFab({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  State<AddFab> createState() => _AddFabState();
}

class _AddFabState extends State<AddFab> with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _rotateCtrl;
  late final Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _rotateAnim = CurvedAnimation(
      parent: _rotateCtrl,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: 'Add document',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          setState(() => _pressed = true);
          _rotateCtrl.forward();
        },
        onTapCancel: () {
          setState(() => _pressed = false);
          _rotateCtrl.reverse();
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
          _rotateCtrl.reverse();
        },
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          scale: _pressed ? 0.96 : 1.0,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF141416) : Colors.white,
              border: isDark
                  ? Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                      width: 0.5,
                    )
                  : Border.all(
                      color: Colors.black.withValues(alpha: 0.05),
                      width: 0.5,
                    ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: RotationTransition(
              turns: Tween<double>(begin: 0, end: 0.125).animate(_rotateAnim),
              child: Icon(
                Icons.add_rounded,
                size: 30,
                color: isDark ? Colors.white : const Color(0xFF1C1C1E),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
